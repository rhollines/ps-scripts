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

diag("Preparing build and analysis for tests");

ok(
  system("rm -rf cvbuild*") == 0,
  "Clean up intermediate directory"
);

ok(
  system("cov-emit --dir cvbuild1 t/src/forward-null.c") == 0,
  "forward-null.c"
);

ok(
  system("cov-emit --dir cvbuild2 t/src/reverse-null.c") == 0,
  "reverse-null.c"
);

diag("Running analysis, this may take a few minutes.");
ok(
  system("cov-analyze --dir cvbuild1") == 0,
  "Analysis 1"
);

ok(
  system("cov-analyze --dir cvbuild2") == 0,
  "Analysis 2"
);


diag("Build and analysis ready for tests");
