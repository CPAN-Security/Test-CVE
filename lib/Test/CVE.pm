#!/usr/bin/perl

package Test::CVE;

=head1 NAME

Test::CVE - Test against known CVE's

=head1 SYNOPSIS

 use Test::CVE;

 my $cve = Test::CVE->new (
    verbose  => 0,
    deps     => 1,
    perl     => 1,
    core     => 1,
    minimum  => 0,
    cpansa   => "https://cpan-security.github.io/cpansa-feed/cpansa.json",
    cpanfile => "cpanfile",
    meta_jsn => "META.json",
    meta_yml => "META.yml",     # NYI
    make_pl  => "Makefile.PL",
    build_pl => "Build.PL",     # NYI
    want     => [],
    );

 $cve->want ("Foo::Bar", "4.321");
 $cve->want ("ExtUtils-MakeMaker");

 $cve->test;
 print $cve->report (width => $ENV{COLUMNS} || 80);
 my $csv = $cve->csv;

=cut

use 5.014000;
use warnings;

our $VERSION = "0.09";

use version;
use Carp;
use HTTP::Tiny;
use JSON::MaybeXS;
use Module::CoreList;
use Text::Wrap;
use YAML::PP ();
use List::Util qw( first );

# TODO:
# * NEW! https://fastapi.metacpan.org/cve/CPANSA-YAML-LibYAML-2012-1152
#        https://fastapi.metacpan.org/cve/release/YAML-1.20_001
# * Module::Install Makefile.PL's
#   use inc::Module::Install;
#   name            'Algorithm-Diff-XS';
#   license         'perl';
#   all_from        'lib/Algorithm/Diff/XS.pm';
# * Module::Build

sub new {
    my $class = shift;
    @_ % 2 and croak "Uneven number of arguments";
    my %self  = @_;
    $self{cpansa}   ||= "https://cpan-security.github.io/cpansa-feed/cpansa.json";
    $self{deps}     //= 1;
    $self{perl}     //= 1;
    $self{core}     //= 1;
    $self{minimum}  //= 0;
    $self{verbose}  //= 0;
    $self{width}    //= $ENV{COLUMNS} // 80;
    $self{want}     //= [];
    $self{cpanfile} ||= "cpanfile";
    $self{meta_jsn} ||= "META.json";
    $self{meta_yml} ||= "META.yml";
    $self{make_pl}  ||= "Makefile.PL";
    $self{build_pl} ||= "Build.PL";
    $self{CVE}        = {};
    bless \%self => $class;
    } # new

sub _read_cpansa {
    my $self = shift;
    my $src  = $self->{cpansa} or croak "No source for CVE database";
    $self->{verbose} and warn "Reading $src ...\n";

    # 'Compress-LZ4'   => [
    #   { affected_versions => [
    #       '<0.20'
    #       ],
    #     cpansa_id         => 'CPANSA-Compress-LZ4-2014-01',
    #     cves              => [],
    #     description       => 'Outdated LZ4 source code with security issue on 32bit systems.
    #
    #     references        => [
    #       'https://metacpan.org/changes/distribution/Compress-LZ4',
    #       'https://github.com/gray/compress-lz4/commit/fc503812b4cbba16429658e1dfe20ad8bbfd77a0'
    #       ],
    #     reported          => '2014-07-07',
    #     severity          => undef
    #     }
    #   ],

    if (-s $src) {
	open my $fh, "<", $src or croak "$src: $!\n";
	local $/;
	$self->{j}{db} = decode_json (<$fh>);
	close $fh;
	}
    else {
	my $r = HTTP::Tiny->new (verify_SSL => 1)->get ($src);
	$r->{success} or die "$src: $@\n";

	$self->{verbose} > 1 and warn "Got it. Decoding\n";
	if (my $c = $r->{content}) {
	    # Skip warning part
	    # CPANSA-perl-2023-47038 has more than 1 range bundled together in '>=5.30.0,<5.34.3,>=5.36.0,<5.36.3,>=5.38.0,<5.38.2'
	    # {"Alien-PCRE2":[{"affected_versions":["<0.016000"],"cpansa_id":"CPANSA-Alien-PCRE2-2019-20454","cves":["CVE-2019-20454"],"description":"An out-
	    $c =~ s/^\s*([^{]+?)[\s\r\n]*\{/{/s and warn "$1\n";
	    $self->{j}{db} = decode_json ($c);
	    }
	else {
	    $self->{j}{db} = undef;
	    }
	}
    $self->{j}{mod} = [ sort keys %{$self->{j}{db} // {}} ];
    $self;
    } # _read_cpansa

sub _read_MakefilePL {
    my ($self, $mf) = @_;
    $mf ||= $self->{make_pl};

    $self->{verbose} and warn "Reading $mf ...\n";
    open my $fh, "<", $mf or return $self;
    my $mfc = do { local $/; <$fh> };
    close $fh;

    $mfc or return $self;

    my ($pv, $release, $nm, $v, $vf) = ("");
    foreach my $mfx (grep { m/=>/ }
		     map  { split m/\s*[;(){}]\s*/ }
		     map  { split m/\s*,(?!\s*=>)/ }
			    split m/[,;]\s*(?:#.*)?\r*\n/ => $mfc) {
	$mfx =~ s/[\s\r\n]+/ /g;
	$mfx =~ s/^\s+//;
	$mfx =~ s/^(['"])(.*?)\1/$2/;	# Unquote key
	my $a = qr{\s* (?:,\s*)? => \s* (?|"([^""]*)"|'([^'']*)'|([-\w.]+))}x;
	$mfx =~ m/^ VERSION          $a /ix and $v       //= $1;
	$mfx =~ m/^ VERSION_FROM     $a /ix and $vf      //= $1;
	$mfx =~ m/^     NAME         $a /ix and $nm      //= $1;
	$mfx =~ m/^ DISTNAME         $a /ix and $release //= $1;
	$mfx =~ m/^ MIN_PERL_VERSION $a /ix and $pv      ||= $1;
	}

    unless ($release || $nm) {
	carp "Cannot get either NAME or DISTNAME, so cowardly giving up\n";
	return $self;
	}
    unless ($pv) {
	$mfc =~ m/^\s*(?:use|require)\s+v?(5[.0-9]+)/m and $pv = $1;
	}
    $pv =~ m/^5\.(\d+)\.(\d+)$/ and $pv = sprintf "5.%03d%03d", $1, $2;
    $pv =~ m/^5\.(\d{1,3})$/    and $pv = sprintf "5.%03d000",  $1;

    $release //= $nm =~ s{-}{::}gr;
    $release eq "." && $nm and $release = $nm =~ s{::}{-}gr;
    if (!$v && $vf and open $fh, "<", $vf) {
	warn "Trying to fetch VERSION from $vf ...\n" if $self->{verbose};
	while (<$fh>) {
	    m/\b VERSION \s* = \s* ["']? ([^;'"\s]+) /x or next;
	    $v = $1;
	    last;
	    }
	close $fh;
	}
    unless ($v) {
	$mfc =~ m/\$\s*VERSION\s*=\s*["']?(\S+?)['"]?\s*;/ and $v = $1;
	}
    unless ($v) {
	carp "Could not derive a VERSION from Makefile.PL\n";
	carp "Please tell me where I did wrong\n";
	carp "(ideally this should be done by a CORE module)\n";
	}
    $self->{mf} = { name => $nm, version => $v, release => $release, mpv => $pv };
    $self->{verbose} and warn "Analysing for $release-", $v // "?", $pv ? " for minimum perl $pv\n" : "\n";
    $self->{prereq}{$release}{v}{$v // "-"} = "current";
    $self;
    } # _read_MakefilePL

sub _read_cpanfile {
    my ($self, $cpf) = @_;
    $cpf ||= $self->{cpanfile};

    -s $cpf or return; # warn "No cpanfile. Scan something else (Makefile.PL, META.json, ...\n";
    $self->{verbose} and warn "Reading $cpf ...\n";
    open my $fh, "<", $cpf or croak "$cpf: $!\n";
    while (<$fh>) {
	my ($t, $m, $v) = m{ \b
	  ( requires | recommends | suggest ) \s+
	  ["'] (\S+) ['"]
	  (?: \s*(?:=>|,)\s* ["'] (\S+) ['"])?
	  }x or next;
	$m =~ s/::/-/g;
	$self->{prereq}{$m}{v}{$v // ""} = $t;
	$self->{prereq}{$m}{$t}          = $v;

	# Ingnore syntax in cpanfile:
	# require File::Temp, # ignore=CPANSA-File-Temp-2011-4116
	# require File::Temp, # ignore : CVE-2011-4116
	if (m/#.*\bignore\s*[=:]?\s*(\S+)/i) {
	    my $i = $1;
	    $self->{prereq}{$m}{i}{$i =~ s{["''"]+}{}gr}++;
	    }
	}
    push @{$self->{want}} => sort grep { $self->{j}{db}{$_} } keys %{$self->{prereq}};
    $self;
    } # _read_cpanfile

sub _read_META {
    my ($self, $mmf) = @_;
    $mmf ||= first { length && -s }
	$self->{meta_jsn}, "META.json",
	$self->{meta_yml}, "META.yml",
	"MYMETA.json", "MYMETA.yml";

    $mmf && -s $mmf or return;
    $self->{verbose} and warn "Reading $mmf ...\n";
    open my $fh, "<", $mmf or croak "$mmf: $!\n";
    local $/;
    my $j;
    if ($mmf =~ m/\.yml$/) {
	$self->{meta_yml} = $mmf;
	$j = YAML::PP::Load (<$fh>);
	$j->{prereqs} //= {
	    configure => {
		requires   => $j->{configure_requires},
		recommends => $j->{configure_recommends},
		suggests   => $j->{configure_suggests},
		},
	    build     => {
		requires   => $j->{build_requires},
		recommends => $j->{build_recommends},
		suggests   => $j->{build_suggests},
		},
	    test      => {
		requires   => $j->{test_requires},
		recommends => $j->{test_recommends},
		suggests   => $j->{test_suggests},
		},
	    runtime   => {
		requires   => $j->{requires},
		recommends => $j->{recommends},
		suggests   => $j->{suggests},
		},
	    };
	}
    else {
	$self->{meta_jsn} = $mmf;
	$j = decode_json (<$fh>);
	}
    close $fh;

    unless ($self->{mf}) {
	my $rls = $self->{mf}{release} = $j->{name} =~ s{::}{-}gr;
	my $vsn = $self->{mf}{version} = $j->{version};
	my $nm  = $self->{mf}{name}    = $j->{name} =~ s{-}{::}gr;
	$self->{prereq}{$rls}{v}{$vsn // "-"} = "current";
	}
    $self->{mf}{mpv} ||= $j->{prereqs}{runtime}{requires}{perl};

    my $pr = $j->{prereqs} or return $self;
    foreach my $p (qw( configure build test runtime )) {
	foreach my $t (qw( requires recommends suggests )) {
	    my $x = $pr->{$p}{$t} or next;
	    foreach my $m (keys %$x) {
		my $v = $x->{$m};
		$m =~ s/::/-/g;
		$self->{prereq}{$m}{v}{$v // ""} = $t;
		$self->{prereq}{$m}{$t}          = $v;
		}
	    }
	}
    push @{$self->{want}} => sort grep { $self->{j}{db}{$_} } keys %{$self->{prereq}};
    $self;
    } # _read_META

sub set_meta {
    my ($self, $m, $v) = @_;
    $self->{mf} = {
	name    => $m,
	release => $m =~ s{::}{-}gr,
	version => $v // "-",
	};
    $self;
    } # set_meta

sub want {
    my ($t, $self, $m, $v) = ("requires", @_);
    $m =~ s/::/-/g;
    unless (first { $_ eq $m } @{$self->{want}}) {
	$self->{prereq}{$m}{v}{$v // ""} = $t;
	$self->{prereq}{$m}{$t}          = $v;
	$self->{j}         or $self->_read_cpansa;
	$self->{j}{db}{$m} and push @{$self->{want}} => $m;
	}
    $self;
    } # want

sub test {
    my $self = shift;
    my $meta = 0;

    $self->{mf}      or $self->_read_MakefilePL;
    $self->{mf}      or $self->_read_META && $meta++;
    my $rel  = $self->{mf}{release} or return $self;
    $self->{verbose} and warn "Processing for $self->{mf}{release} ...\n";

    $self->{j}{mod}  or $self->_read_cpansa;
    @{$self->{want}} or $self->_read_cpanfile           if $self->{deps};
    @{$self->{want}} or $self->_read_META               if $self->{deps} && !$meta;
    @{$self->{want}} or $self->_read_META ("META.json") if $self->{deps};

    $self->{j}{db}{$rel} and unshift @{$self->{want}} => $rel;

    my @w = @{$self->{want}} or return $self; # Nothing to report

    foreach my $m (@w) {
	$m eq "perl" && !$self->{perl} and next;

	my @mv = sort map { $_ || 0 } keys %{$self->{prereq}{$m}{v} || {}};
	if ($self->{core} and my $pv = $self->{mf}{mpv}
			  and "@mv" !~ m/[1-9]/) {
	    my $pmv = $Module::CoreList::version{$pv}{$m =~ s/-/::/gr} // "";
	    $pmv and @mv = ($pmv =~ s/\d\K_.*//r);
	    }
	$self->{verbose} and warn "$m: ", join (" / " => grep { $_ } @mv), "\n";
	my $cv = ($self->{minimum} ? $mv[0] : $mv[-1]) || 0; # Minimum or recommended
	$self->{CVE}{$m} = {
	    mod => $m,
	    vsn => $self->{prereq}{$m}{t},
	    min => $cv,
	    cve => [],
	    };

	#DDumper $self->{j}{db}{$m};
	foreach my $c (@{$self->{j}{db}{$m}}) {
	    # Ignored: references
	    my $cid = $c->{cpansa_id};
	    my @cve = @{$c->{cves} || []};
	    my $dte = $c->{reported};
	    my $sev = $c->{severity};
	    my $dsc = $c->{description};
	    my @vsn = @{$c->{affected_versions} || []};
	    if (my $i = $self->{prereq}{$m}{i}) {
		my $p = join "|" => reverse sort keys %$i;
		my $m = join "#" => sort @cve, $cid;
		"#$m#" =~ m/$p/ and next;
		}
	    if (@vsn) {
		$self->{verbose} > 2 and warn "CMP<: $m-$cv\n";
		$self->{verbose} > 4 and warn "VSN : (@vsn)\n";
		# >=5.30.0,<5.34.3,>=5.36.0,<5.36.3,>=5.38.0,<5.38.2
		my $cmp = join " or " =>
		    map { s/\s*,\s*/") && XV /gr
		       =~ s/^/XV /r
		       =~ s/\s+=(?=[^=<>])\s*/ == /r	# = => ==
		       =~ s/\s*([=<>]+)\s*/$1 version->parse ("/gr
		       =~ s/$/")/r
		       =~ s/\bXV\b/version->parse ("$cv")/gr
		       =~ s/\)\K(?=\S)/ /gr
		       } @vsn;
		$self->{verbose} > 2 and warn "CMP>: $cmp\n";
		eval "$cmp ? 0 : 1" and next;
		$self->{verbose} > 3 and warn "TAKE!\n";
		}
	    else {
		warn "WTF: Geen V of CVE?\n";
		}
	    push @{$self->{CVE}{$m}{cve}} => {
		cid => $cid,
		dte => $dte,
		cve => [ @cve ],
		sev => $sev,
		av  => [ @vsn ],
		dsc => $dsc,
		};
	    #die DDumper { c => $c, cv => $cv, cve => $self->{CVE}{$m}, vsn => \@vsn };
	    }
	}
    $self;
    } # test

sub report {
    my $self = shift;

    $self->{j} or return;

    @_ % 2 and croak "Uneven number of arguments";
    my %args = @_;

    local $Text::Wrap::columns = ($args{width} || $self->{width}) - 4;

    my $n;
    foreach my $m (@{$self->{want}}) {
	my $C = $self->{CVE}{$m} or next;
	my @c = @{$C->{cve}}     or next;
	say "$m: ", $C->{min} // "-";
	foreach my $c (@c) {
	    my $cve = "@{$c->{cve}}" || $c->{cid};
	    printf "  %-10s %-12s %-12s %s\n",
		$c->{dte}, "@{$c->{av}}", $c->{sev} // "-", $cve;
	    print s/^/       /gmr for wrap ("", "", $c->{dsc});
	    $n++;
	    }
	}
    $n or say "There heve been no CVE detections in this process";
    } # report

sub cve {
    my $self = shift;

    $self->{j} or return;

    @_ % 2 and croak "Uneven number of arguments";
    my %args = @_;

    local $Text::Wrap::columns = $args{width} || $self->{width};

    my @cve;
    foreach my $m (@{$self->{want}}) {
	my $C = $self->{CVE}{$m} or next;
	my @c = @{$C->{cve}}     or next;
	push @cve => { release => $m, vsn => $C->{min}, cve => [ @c ] };
	}
    @cve;
    } # cve

1;

__END__

=head1 INCENTIVE

On the Perl Toolchain Summit 2023, the CPAN Security Working Group (CPAN-SEC)
was established to receive and handle reports of undisclosed vulnerabilities
for CPAN releases and to assist the community in dealing with those.

The resources available enabled passive checks to existing releases and single
files against the database with known vulnerabilities.

The goal of this module is to be able to check if known vulnerabilities exist
before the release would be uploaded to CPAN.

The analysis is based on declarations and/or actual use and supports three
levels: C<requires>, C<recommends>, and C<suggests>. C<suggests> is unused in
giving advice.

The functionality explicitly limits to passive analysis: the is no active
scanning of source code to find security vulnerabilities.

=head1 DESCRIPTION

Test::CVE provides functionality to test a (CPAN)release or a single (perl)
script against known CVE's

It enables checking the current release only or include its prereqs too.

=head2 Functions and methods

=head3 new

 my $cve = Test::CVE->new (
    verbose  => 0,
    deps     => 1,
    minimum  => 0,
    cpansa   => "https://cpan-security.github.io/cpansa-feed/cpansa.json",
    make_pl  => "Makefile.PL",
    cpanfile => "cpanfile",
    want     => [],
    );

=head4 verbose

Set verbosity level. This will report what files are opened and read and what
modules are taken into account. Higher verbose will show more. Default = C<0>.

=head4 deps

Select if CVE's are also checked for direct dependencies. Default is true. If
false, just check the module or release itself.

=head4 perl

Select if CVE's on perl itself are included in the report. Default is true.

=head4 core

Replace unspecified versions of CORE modules with the version as shipped by
the required perl if known.

 require "ExtUtils::MakeMaker"; # no version specified

will set the required version to "6.66" when minimum perl is 5.18.1.

=head4 minimum

Report all CVE's regardless of what version is recommended in C<cpanfile> or
C<MYMETA.json>. By default only CVE's newer than the recommended version per
dependency are reported.

=head4 cpansa

Pass the URL of the CPANSA database. The alternative is to pass the filename
of a stored version of that database.

=head4 make_pl

Pass an alternative location of C<Makefile.PL>. Default is the one in the
current directory.

In version C<0.01> C<Build.PL> is not yet supported.

=head4 cpanfile

Pass an alternative location for C<cpanfile>. Very useful when testing.

=head4 want

A list of extra prereqs. When you know in advance, pass the list in this
attribute. You can also add them to the object with the method later. This
attribute does not support versions, the method does.

=head3 require

 my $cve = Test::CVE->new ();
 $cve->require ("Foo::Bar");
 $cve->require ("Baz-Fumble", "4.321");

Add a dependency to the list. Only adds the dependency if known CVE's exist.

=head3 set_meta

 $cve->set_meta ("Fooble.pl");
 $cve->set_meta ("script.pl", "0.01");

Force set distribution information, preventing reading C<Makefile.PL> and/or
C<cpanfile>.

=head3 test

Execute the test. Files are read as needed.

=head3 report

Report the test-results in plain text. This method prints the CVE's. If you
want the results for further analysis, use C<cve>.

=head3 cve

Return a list of found CVE's per release. The format will be somewhat like

 [ { release => "Some-Module",
     vsn     => "0.45",
     cve     => [
       { av  => [ "<1.23" ],
         cid => "CPANSA-Some-Module-2023-01",
         cve => [ "CVE-2023-1234" ],
         dsc => "Removes all files in /tmp",
         dte => "2023-01-02",
         sev => "critical",
         },
       ...
       ],
     },
   ...
   ]

=head4 release

The name of the release

=head4 vsn

The version that was checked

=head4 cve

The list of found CVE's for this release that match the criteria

=over 2

=item av

All affected versions of the release

=item cid

The ID from the CPANSA database

=item cve

The list of CVE tags for this item. This list can be empty.

=item dsc

Description of the vulnerability

=item dte

Date for this CVE

=item sev

Severity. Most entries doe not have a severity

=back

=head1 TODO and IDEAS

=over 2

=item

Support L<SLSA|https://slsa.dev/spec/v0.1/> documents

=back

=head1 AUTHOR

H.Merijn Brand F<E<lt>hmbrand@cpan.orgE<gt>>

=head1 SEE ALSO

L<Net::CVE>, L<Net::NVD>, L<Net::OSV>

=head1 COPYRIGHT AND LICENSE

 Copyright (C) 2023-2025 H.Merijn Brand.  All rights reserved.

This library is free software;  you can redistribute and/or modify it under
the same terms as Perl itself.

=cut

=for elvis
:ex:se gw=75|color guide #ff0000:

=cut
