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

BEGIN { use_ok('Coverity::WS::v1::ConfigurationService') }

# Create service context
my $configurationService = new Coverity::WS::v1::ConfigurationService(
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

push(@projectComponents, {
    filePattern => "/home/",
    name => "Home dir"
  });
push(@projectComponents, {
    filePattern => "include",
    name => "Includes"
  });
push(@projectComponents, {
    filePattern => "/home/",
    name => "Home dir"
  });

#
# Actions
#

my @actions;
lives_ok {
  @actions = $configurationService->getActions();
} "ConfigurationService::getActions";

ok(scalar(@actions) > 0, "More than one action present");

my @newActions = @actions;
my $newAction = "Test Action $$";
push(@newActions, $newAction);

lives_ok {
  $configurationService->updateActions(
    actions => \@newActions
  );
} "ConfigurationService::updateActions";

@newActions = $configurationService->getActions();
my $actionFound = 0;
foreach my $action (@newActions) {
  if ($action eq $newAction) {
    $actionFound = 1;
  }
}

ok($actionFound, "Found added action");

$configurationService->updateActions(
  actions => \@actions
);

#
# Severities
#

my @severities;
lives_ok {
  @severities = $configurationService->getSeverities();
} "ConfigurationService::getSeverities";

ok(scalar(@severities) > 0, "More than one severity present");

my @newSeverities = @severities;
my $newSeverity = "Test Severity $$";
push(@newSeverities, $newSeverity);

lives_ok {
  $configurationService->updateSeverities(
    severities => \@newSeverities
  );
} "ConfigurationService::updateSeverities";

@newSeverities = $configurationService->getSeverities();
my $severityFound = 0;
foreach my $severity (@newSeverities) {
  if ($severity eq $newSeverity) {
    $severityFound = 1;
  }
}

ok($severityFound, "Found added severity");

$configurationService->updateSeverities(
  severities => \@severities
);

#
# Classifications
#

my @classifications;
lives_ok {
  @classifications = $configurationService->getClassifications();
} "ConfigurationService::getClassifications";

ok($classifications[0] eq "Unclassified", "Classifications look reasonable");

#
# Classifications
#

my @defectStatuses;
lives_ok {
  @defectStatuses = $configurationService->getDefectStatuses();
} "ConfigurationService::getDefectStatuses";

ok($defectStatuses[0] eq "New", "Defect Statuses look reasonable");

#
# Projects and Streams
#

lives_ok {
  foreach my $stream (@projectStreams) {
    $configurationService->createStream(
      streamSpec => $stream
    );
  }
} "ConfigurationService::createStream";

lives_ok {
  $configurationService->createProject(
    projectSpec => {
      streams => \@projectStreams,
# XXX TODO Can't set components?
#      components => \@projectComponents,
#      defaultTriageScope => "$projectName/*",
      description => "Test project $$",
      id => {
        name => $projectName
      }
    }
  );
} "ConfigurationService::createProject";

my @projects;
lives_ok {
  @projects = $configurationService->getProjects(
    filterSpec => {
      namePattern => $projectName
    }
  );
} "ConfigurationService::getProjects";

ok(scalar(@{$projects[0]->{streams}}) == scalar(@projectStreams), "$projectName has correct number of streams");

my @streams;
lives_ok {
  @streams = $configurationService->getStreams(
    filterSpec => {
      languageList => [ "CXX", "JAVA" ],
      typeList => [ "SOURCE" ],
      namePattern => "teststream*"
    }
  );
} "ConfigurationService::getStreams";

ok(scalar(@streams) >= 2, "Enough streams found");

my $updatedStream = $projectStreams[0];
$updatedStream->{description} = "$updatedStream->{description} UPDATED";

lives_ok {
  $configurationService->updateStream(
    streamId => {
      name => $updatedStream->{id}->{name},
      type => $updatedStream->{id}->{type}
    },
    streamSpec => $updatedStream
  );
} "ConfigurationService::updateStream";

lives_ok {
  $configurationService->updateProject(
    projectId => {
      name => $projectName
    },
    projectSpec => {
      streams => \@projectStreams,
# XXX TODO Can't set components?
#      components => \@projectComponents,
#      defaultTriageScope => "$projectName/*",
      description => "Test project $$ UPDATED",
      id => {
        name => $projectName
      }
    }
  );
} "ConfigurationService::updateProject";

#
# Clean up
#

lives_ok {
  $configurationService->deleteProject(
    projectId => {
      name => $projectName
    }
  );
} "ConfigurationService::deleteProject";

lives_ok {
  foreach my $stream (@projectStreams) {
    $configurationService->deleteStream(
      streamId => {
        name => $stream->{id}->{name},
        type => $stream->{id}->{type}
      }
    );
  }
} "ConfigurationService::deleteStream";

diag("End of tests");
