#!/usr/bin/perl

use 5.014000;
use warnings;

use Test::More;

eval "use Test::Pod::Coverage tests => 1";
plan skip_all => "Test::Pod::Coverage required for testing POD Coverage" if $@;
pod_coverage_ok ("Test::CVE", "Test::CVE is covered");
