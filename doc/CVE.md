# NAME

    Test::CVE - Test against known CVE's

# SYNOPSIS

    use Test::CVE;

    my $cve = Test::CVE->new (
       verbose  => 0,
       deps     => 1,
       perl     => 1,
       minimum  => 0,
       cpansa   => "https://cpan-security.github.io/cpansa-feed/cpansa.json",
       make_pl  => "Makefile.PL",
       cpanfile => "cpanfile",
       want     => [],
       );

    $cve->want ("Foo::Bar", "4.321");
    $cve->want ("ExtUtils-MakeMaker");

    $cve->test;
    print $cve->report (width => $ENV{COLUMNS} || 80);
    my $csv = $cve->csv;

# INCENTIVE

On the Perl Toolchain Summit 2023, the CPAN Security Working Group (CPAN-SEC)
was established to receive and handle reports of undisclosed vulnerabilities
for CPAN releases and to assist the community in dealing with those.

The resources available enabled passive checks to existing releases and single
files against the database with known vulnerabilities.

The goal of this module is to be able to check if known vulnerabilities exist
before the release would be uploaded to CPAN.

The analysis is based on declarations and/or actual use and supports three
levels: `requires`, `recommends`, and `suggests`. `suggests` is unused in
giving advice.

The functionality explicitly limits to passive analysis: the is no active
scanning of source code to find security vulnerabilities.

# DESCRIPTION

Test::CVE provides functionality to test a (CPAN)release or a single (perl)
script against known CVE's

It enables checking the current release only or include its prereqs too.

## Functions and methods

### new

    my $cve = Test::CVE->new (
       verbose  => 0,
       deps     => 1,
       minimum  => 0,
       cpansa   => "https://perl-toolchain-gang.github.io/cpansa-feed/cpansa.json",
       make_pl  => "Makefile.PL",
       cpanfile => "cpanfile",
       want     => [],
       );

#### verbose

Set verbosity level. This will report what files are opened and read and what
modules are taken into account. Higher verbose will show more. Default = `0`.

#### deps

Select if CVE's are also checked for direct dependencies. Default is true. If
false, just check the module or release itself.

#### perl

Select if CVE's on perl itself are included in the report. Default is true.

#### minimum

Report all CVE's regardless of what version is recommended in `cpanfile` or
`MYMETA.json`. By default only CVE's newer than the recommended version per
dependency are reported.

#### cpansa

Pass the URL of the CPANSA database. The alternative is to pass the filename
of a stored version of that database.

#### make\_pl

Pass an alternative location of `Makefile.PL`. Default is the one in the
current directory.

In version `0.01` `Build.PL` is not yet supported.

#### cpanfile

Pass an alternative location for `cpanfile`. Very useful when testing.

#### want

A list of extra prereqs. When you know in advance, pass the list in this
attribute. You can also add them to the object with the method later. This
attribute does not support versions, the method does.

### require

    my $cve = Test::CVE->new ();
    $cve->require ("Foo::Bar");
    $cve->require ("Baz-Fumble", "4.321");

Add a dependency to the list. Only adds the dependency if known CVE's exist.

### set\_meta

    $cve->set_meta ("Fooble.pl");
    $cve->set_meta ("script.pl", "0.01");

Force set distribution information, preventing reading `Makefile.PL` and/or
`cpanfile`.

### test

Execute the test. Files are read as needed.

### report

Report the test-results in plain text. This method prints the CVE's. If you
want the results for further analysis, use `cve`.

### cve

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

#### release

The name of the release

#### vsn

The version that was checked

#### cve

The list of found CVE's for this release that match the criteria

- av

    All affected versions of the release

- cid

    The ID from the CPANSA database

- cve

    The list of CVE tags for this item. This list can be empty.

- dsc

    Description of the vulnerability

- dte

    Date for this CVE

- sev

    Severity. Most entries doe not have a severity

# AUTHOR

H.Merijn Brand `<hmbrand@cpan.org>`

# SEE ALSO

[Net::CVE](https://metacpan.org/pod/Net%3A%3ACVE), [Net::NVD](https://metacpan.org/pod/Net%3A%3ANVD), [Net::OSV](https://metacpan.org/pod/Net%3A%3AOSV)

# COPYRIGHT AND LICENSE

    Copyright (C) 2023-2024 H.Merijn Brand.  All rights reserved.

This library is free software;  you can redistribute and/or modify it under
the same terms as Perl itself.
