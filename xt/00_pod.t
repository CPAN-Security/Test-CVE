#!/usr/bin/perl

use 5.014000;
use warnings;

use Test::More;

eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok ();

done_testing;
