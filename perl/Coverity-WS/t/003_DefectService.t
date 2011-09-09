#
# (c) 2010 Coverity, Inc.  All rights reserved worldwide.
# 

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
  push(@INC, "$Bin/../lib");
  push(@INC, "$Bin");
}

use Test::Exception;

diag("Begin testing ConfigurationService");

use TestConfig;

BEGIN {
  use_ok('Coverity::WS::v1::ConfigurationService');
  use_ok('Coverity::WS::v1::DefectService');
}

# Create service context
my $configurationService = new Coverity::WS::v1::ConfigurationService(
  remote => $remote,
  port => $port,
  username => $username,
  password => $password,
  ssl => $ssl
);

my $defectService = new Coverity::WS::v1::DefectService(
  remote => $remote,
  port => $port,
  username => $username,
  password => $password,
  ssl => $ssl
);

# 1. Create some streams and a project to test with
my $projectName = "testproject$$";
my $stream1Name = "teststreamx86$$";
my $stream2Name = "teststreamppc2$$";

my @projectStreams;
my @projectComponents;

push(@projectStreams, {
    description => "Test stream for x86",
    id => {
      name => $stream1Name,
      type => "STATIC"
    },
    language => "CXX"
  });
push(@projectStreams, {
    description => "Test stream for x86",
    id => {
      name => $stream1Name,
      type => "SOURCE"
    },
    language => "CXX"
  });
push(@projectStreams, {
    description => "Test stream for PPC",
    id => {
      name => $stream2Name,
      type => "STATIC"
    },
    language => "CXX"
  });
push(@projectStreams, {
    description => "Test stream for PPC",
    id => {
      name => $stream2Name,
      type => "SOURCE"
    },
    language => "CXX"
  });

#
# Create some test Projects and Streams
#

foreach my $stream (@projectStreams) {
  $configurationService->createStream(
    streamSpec => $stream
  );
}

$configurationService->createProject(
  projectSpec => {
    streams => \@projectStreams,
    description => "Test project $$",
    id => {
      name => $projectName
    }
  }
);

# Commit some results

system("cov-commit-defects --host $remote --port $port --user $username --password $password --dir cvbuild1 --stream $stream1Name");
system("cov-commit-defects --host $remote --port $port --user $username --password $password --dir cvbuild2 --stream $stream2Name");

#
# Test the DefectService
#

# XXX TODO Test snapshots
#my @snapshots;
#lives_ok {
#  @snapshots = $defectService->getSnapshotsForProject(
#    projectId => {
#      name => $projectName
#    }
#  );
#} "DefectService::getSnapshotsForProject";
#
#print "snapshots=" . Dumper(@snapshots);

#
# getMergedDefectsForProject
#

my $i;
my $pageSpec = {
  pageSize => 1,
  sortAscending => "true",
  startIndex => 0
};

my $defectsPage;
my @defects;

$i = 0;
do {
  $pageSpec->{startIndex} = $i;
  $defectsPage = $defectService->getMergedDefectsForProject(
    projectId => {
      name => $projectName
    },
    filterSpec => {
      checkerFilterSpecList => [
        {
          name => "FORWARD_NULL"
        },
        {
          name => "REVERSE_INULL"
        }
      ]
    },
    pageSpec => $pageSpec
  );
  $i += 1;
  push(@defects, @{$defectsPage->{mergedDefects}});
} while ($i < $defectsPage->{totalNumberOfRecords});

ok(scalar(@defects) == 3, "DefectService::getMergedDefectsForProject Correct number of merged defects");

#
# getMergedDefectsForStreams
#

$i = 0;
@defects = ();
do {
  $pageSpec->{startIndex} = $i;
  $defectsPage = $defectService->getMergedDefectsForStreams(
    analysisStreamIds => [
      {
        name => $stream1Name,
        type => "STATIC"
      }
    ],
    filterSpec => {
      checkerFilterSpecList => [
        {
          name => "FORWARD_NULL"
        },
        {
          name => "REVERSE_INULL"
        }
      ]
    },
    pageSpec => $pageSpec
  );
  $i += 1;
  push(@defects, @{$defectsPage->{mergedDefects}});
} while ($i < $defectsPage->{totalNumberOfRecords});

ok(scalar(@defects) == 2, "DefectService::getMergedDefectsForStreams Correct number of merged defects");

#
# getStreamDefects
#

my $defect = $defects[0];
my @streamDefects;

lives_ok {
  @streamDefects = $defectService->getStreamDefects(
    cid => $defect->{cid},
    includeDetails => "true",
    scopePattern => "$projectName/*"
  );
}  "DefectService::getStreamDefects";

ok(scalar(@streamDefects) == 1, "DefectService::getStreamDefects Correct number of stream defects");

#
# updateStreamDefects
#

my $streamDefect = $streamDefects[0];

lives_ok {
  $defectService->updateStreamDefects(
    streamDefectIds => {
      id => $streamDefect->{id}->{id}
    },
    defectStateSpec => {
      classification => "Bug"
    }
  );
}  "DefectService::getStreamDefects";

#
# getMergedDefectHistory
#

my @defectHistory;
lives_ok {
  @defectHistory = $defectService->getMergedDefectHistory(
    cid => $defect->{cid},
    scopePattern => "$projectName/*"
  );
} "DefectService::getMergedDefectHistory";

ok(scalar(@defectHistory) == 2, "DefectService::getMergedDefectHistory Correct number of entries");

ok($defectHistory[1]->{classificationChange}->{newValue} eq "Bug", "DefectService::getMergedDefectHistory correct state change");

#my $groupFound = 0;
#foreach my $group (@groups) {
#  if ($group->{name}->{name} eq $groupName) {
#    $groupFound = 1;
#  }
#}
#ok($groupFound, "Group $groupName found");
#
#my $group;
#
#lives_ok {
#  $group = $administrationService->getGroup(
#    groupId => {
#      name => $groupName
#    }
#  );
#} "AdministrationService::getGroup";


#
# Clean up
#

$configurationService->deleteProject(
  projectId => {
    name => $projectName
  }
);

# XXX Ok we really can't clean this up because the streams have data...

#foreach my $stream (@projectStreams) {
#  $configurationService->deleteStream(
#    streamId => {
#      name => $stream->{id}->{name},
#      type => $stream->{id}->{type}
#    }
#  );
#}

diag("End of tests");
