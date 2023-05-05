#!/usr/bin/perl

use 5.014000;
use warnings;
use Test::More;

eval "use Test::DistManifest";
plan skip_all => "Test::DistManifest required for testing MANIFEST" if $@;
manifest_ok ();
done_testing;
