#!/usr/bin/perl

use 5.014000;
use warnings;

eval "use Test::PAUSE::Permissions";
 
if ($@ || $] < 5.018) {
    print "1..0 # No perl permission check for old releases\n";
    exit 0;
    }

BEGIN { $ENV{RELEASE_TESTING} = 1; }

all_permissions_ok ("HMBRAND");
