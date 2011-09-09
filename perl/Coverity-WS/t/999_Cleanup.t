# (c) 2010 Coverity, Inc.  All rights reserved worldwide.
# 
# $Id: 001_AttributeService.t,v 1.1 2010/04/04 22:20:51 jcroall Exp $

use Test::More qw(no_plan);
use FindBin qw($Bin);
use File::Spec;
use Storable;
use Data::Dumper;
use Getopt::Long;
use File::Temp;
use File::Basename qw(basename);

use strict;

BEGIN {
  push(@INC, "$Bin/../../lib");
}

use Test::Exception;

diag("Cleaning up tests.");

ok(
  system("rm -rf cvbuild*") == 0,
  "Clean up intermediate directory"
);
