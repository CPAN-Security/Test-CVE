#!/pro/bin/perl

use 5.014002;
use warnings;

our $VERSION = "0.05 - 20230501";
our $CMD = $0 =~ s{.*/}{}r;

sub usage {
    my $err = shift and select STDERR;
    say "usage: $CMD [options] [module | dir]";
    say "    -d    --deps         Report on current deps too";
    say "    -m    --minimum      Report besed on minimum (default recommended)";
    say "    -j F  --json=F       Use downloaded JSON instead of fetching";
    say "    -v[#] --verbose[=#]  Set verbosity level";
    say "";
    say "For CVE's in the perl core, please use CPAN::Audit";
    say "Documentation should still be written";
    exit $err;
    } # usage

use Test::CVE;
use Getopt::Long qw(:config bundling);
GetOptions (
    "help|?"		=> sub { usage (0); },
    "V|version"		=> sub { say "$CMD [$VERSION]"; exit 0; },

    "d|deps!"		=> \ my $opt_d,
    "m|minimum!"	=> \ my $opt_m,
    "j|json=s"		=> \ my $opt_j,

    "v|verbose:1"	=> \(my $opt_v = 0),
    ) or usage (1);

my $cve = Test::CVE->new (
    deps    => $opt_d,
    minimum => $opt_m,
    cpansa  => $opt_j,
    );

# NEW! https://fastapi.metacpan.org/cve/CPANSA-YAML-LibYAML-2012-1152
#      https://fastapi.metacpan.org/cve/release/YAML-1.20_001

my $module = shift || ".";
chdir $module;

$cve->test->report;
