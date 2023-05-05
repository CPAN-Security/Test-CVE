#!/usr/bin/perl

use 5.014000;
use warnings;

use Test::More;

eval "use Test::Pod::Links";
plan skip_all => "Test::Pod::Links required for testing POD Links" if $@;
Test::Pod::Links->new->pod_file_ok ("lib/Test/CVE.pm");

done_testing;
