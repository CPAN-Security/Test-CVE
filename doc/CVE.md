# NAME

    Test::CVE - Test against known CVE's

# SYNOPSIS

    use Test::CVE;

    my $cve = Test::CVE->new (
       verbose  => 0,
       deps     => 1,
       minimum  => 0,
       cpansa   => "https://hackeriet.github.io/cpansa-feed/cpansa.json",
       make_pl  => "Makefile.PL",
       cpanfile => "cpanfile",
       want     => [],
       );

    $cve->test;
    print $cve->report (width => $ENV{COLUMNS} || 80);
    my $csv = $cve->csv;

# DESCRIPTION

Test::CVE provides functionality to test a release against known CVE's

It enables checking the current release only or include its prereqs too.

## Functions and methods

### new

    my $cve = Test::CVE->new (
       verbose  => 0,
       deps     => 1,
       minimum  => 0,
       cpansa   => "https://hackeriet.github.io/cpansa-feed/cpansa.json",
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

A list of extra prereqs.

### test

Execute the test. Files are read as needed.

### report

Report the test-results in plain text. This method prints the CVE's. If you
want the results for further analysis, use `cve`.

### cve

Return a list of found CVE's per release. The format will be somewhat like

    [ { release => "Some-Module",
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

# COPYRIGHT AND LICENSE

    Copyright (C) 2023-2023 H.Merijn Brand.  All rights reserved.

This library is free software;  you can redistribute and/or modify it under
the same terms as Perl itself.
