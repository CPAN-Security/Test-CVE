#!/usr/bin/env perl

use 5.014000;
use warnings;

use Getopt::Long qw(:config bundling nopermute);
GetOptions (
    "c|check"		=> \ my $check,
    "u|update!"		=> \ my $update,
    "v|verbose:1"	=> \(my $opt_v = 0),
    ) or die "usage: $0 [--check]\n";

use lib "sandbox";
use genMETA;
my $meta = genMETA->new (
    from    => "lib/Test/CVE.pm",
    verbose => $opt_v,
    );

$meta->from_data (<DATA>);
$meta->security_md ($update);
$meta->gen_cpanfile ();

if ($check) {
    $meta->check_encoding ();
    $meta->check_required ();
    $meta->check_minimum ("5.14", $_) for sort glob "*/[se][cx]*/*";
    $meta->done_testing ();
    }
elsif ($opt_v) {
    $meta->print_yaml ();
    }
else {
    $meta->fix_meta ();
    }

__END__
--- #YAML:1.0
name:                      Test-CVE
version:                   VERSION
abstract:                  Test current release against CVE's
license:                   perl
author:
    - H.Merijn Brand <hmbrand@cpan.org>
generated_by:              Author
distribution_type:         module
provides:
    Test::CVE:
        file:              lib/Test/CVE.pm
        version:           VERSION
requires:
    perl:                  5.014000
    version:               0
    HTTP::Tiny:            0
    IO::Socket::SSL:       0
    JSON::MaybeXS:         0
    Module::CoreList:      0
    Text::Wrap:            0
    YAML::PP:              0
    Test::Builder::Module: 0
recommends:
    HTTP::Tiny:            0.083
    IO::Socket::SSL:       1.36
suggests:
    version:               0.9929
    HTTP::Tiny:            0.089
    IO::Socket::SSL:       2.089
    JSON::MaybeXS:         1.004008
    Module::CoreList:      5.20241220
    YAML::PP:              0.38.0
configure_requires:
    ExtUtils::MakeMaker:   0
configure_recommends:
    ExtUtils::MakeMaker:   7.22
configure_suggests:
    ExtUtils::MakeMaker:   7.72
test_requires:
    Test::More:            0
test_suggests:
    Test::More:            1.302209
resources:
    license:               http://dev.perl.org/licenses/
    repository:            https://github.com/CPAN-Security/Test-CVE
    homepage:              https://metacpan.org/pod/Test::CVE
    bugtracker:            https://github.com/CPAN-Security/Test-CVE/issues
    IRC:                   irc://irc.perl.org/#cpan-security
meta-spec:
    version:               1.4
    url:                   http://module-build.sourceforge.net/META-spec-v1.4.html
