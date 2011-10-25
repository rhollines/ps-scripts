#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2010 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

get-snapshot-for-first-detected.pl


=head1 SYNOPSIS

get-snapshot-for-first-detected.pl [options] --config CONFIG_FILE --project PROJECT (OR --stream STREAM1 --stream STREAM2 ...)


=head1 OPTIONS

=over 12

=item Required:

=item B<--config>

CONFIG_FILE e.g coverity_pse_config.xml

=item B<--project>

Lookup snapshot when defect first detected in all streams belonging to a PROJECT OR

=item B<--stream>

Lookup snapshot when defect first detected in STREAM(s)

=item Optional:

=item B<--host>

CIM server HOST

=item B<--port>

CIM server PORT

=item B<--username>

CIM server USERNAME with admin access

=item B<--password>

CIM server PASSWORD

=item B<--force>

Set owner even if already set

=item B<--dry-run>

Test run, do not update defects

=item B<--help>

Print documentation and exit

=back


=head1 DESCRIPTION

Lookup snapshot when defect is first detected.  Retrieve the snapshot target,
version, and description labels and add them as a triage comment.


=head1 CONFIGURATION

This script uses a configuration file (usually coverity_pse_config.xml) for
CIM connection information.


=head1 AUTHOR

 Sumio Kiyooka (skiyooka@coverity.com)

=cut

##############################################################################
####### Initialization #######################################################

use strict;

use Getopt::Long;
use Pod::Usage;
use File::Basename;
use FindBin qw($Bin $Script);
use Data::Dumper;

BEGIN {
  push(@INC, "$Bin/../lib");
  push(@INC, "$Bin/../Coverity-WS/lib");
  $Script =~ s/\.pl//g;
};

use Log::Log4perl qw(get_logger :levels);
use Coverity::WS::v2::DefectService qw(:checkerTypes);
use Coverity::WS::v2::ConfigurationService;
use Coverity::WS::v2::AdministrationService;
use Coverity::Config;

# Initialize logging
Log::Log4perl->init("$Bin/log.conf");
my $log = get_logger($Script);


##############################################################################
####### Global data and configuration ########################################

my $opt_project;
my @opt_streams;

my $opt_host;
my $opt_port;
my $opt_username;
my $opt_password;

my $opt_coverity_config;
my $coverityConfig;

my $opt_force = 0;
my $opt_dry_run = 0;
my $opt_help = 0;

my $defectService;
my $configurationService;
my $administrationService;


##############################################################################
####### Subroutines ##########################################################

sub handle_command_line_options {
  GetOptions(
    # What to operate on
    'project=s' => \$opt_project,
    'stream=s' => \@opt_streams,
    # Standard CIM options
    'host=s' => \$opt_host,
    'port=s' => \$opt_port,
    'username=s' => \$opt_username,
    'password=s' => \$opt_password,
    # Common script options
    'config=s' => \$opt_coverity_config,
    'force!' => \$opt_force,
    'dry-run!' => \$opt_dry_run,
    'help|?' => \$opt_help
  ) or pod2usage(-verbose => 1);
  pod2usage(-verbose => 2) if $opt_help;
  pod2usage(-verbose => 1) if (!$opt_coverity_config);
  pod2usage(-verbose => 1) if (!$opt_project && @opt_streams == 0);

  if ($opt_project && @opt_streams > 0) {
    $log->error("You can only specify a --project OR --stream(s).  Not both.");
    exit(1);
  }

  $coverityConfig = new Coverity::Config(filename => $opt_coverity_config);

  # Command-line options override values in config file.
  $opt_host = $opt_host ? $opt_host : $coverityConfig->get_cim_host();
  $opt_port = $opt_port ? $opt_port : $coverityConfig->get_cim_port();
  $opt_username = $opt_username ? $opt_username : $coverityConfig->get_cim_username();
  $opt_password = $opt_password ? $opt_password : $coverityConfig->get_cim_password();

  if (!$opt_host or !$opt_port or !$opt_username or !$opt_password) {
    $log->error("Must specify CIM server and authentication details on command line or configuration file");
    pod2usage(-verbose => 1);
  }
}


# This is in a subroutine because it verbose considering we're only retrieving
# a list of merged defects.  This is because of all the required paging.
sub getMergedDefectsForProject {
  # inputs
  my $defectService = shift;
  my $projectName = shift;

  # output: an array of hashes - one for each defect
  my @defects = ();

  my $PAGE_SIZE = 1000;  # this cannot exceed 2500
  my $pageSpec = {
    pageSize => $PAGE_SIZE,
    sortAscending => 'true',
    startIndex => 0
  };

  my $i = 0;
  my $defectsPage;

  do {
    $pageSpec->{startIndex} = $i;
    $defectsPage = $defectService->getMergedDefectsForProject(
      projectId => {
        name => $projectName
      },
      pageSpec => $pageSpec
    );
    $i += $PAGE_SIZE;
    if ($defectsPage->{totalNumberOfRecords} > 0) {
      push(@defects, @{$defectsPage->{mergedDefects}});
    }
  } while ($i < $defectsPage->{totalNumberOfRecords});

  return @defects;
}


# This is in a subroutine because it verbose considering we're only retrieving
# a list of merged defects.  This is because of all the required paging.
sub getMergedDefectsForStreams {
  # inputs
  my $defectService = shift;
  my $streams_array_ref = shift;
  my @streams = @$streams_array_ref;

  my @analysisStreamIds;  # array of { name => , type => } hashes

  foreach my $stream (@streams) {
    my ($streamName, $streamType) = split(':', $stream);
    $streamType = $streamType ? $streamType : STATIC;

    push @analysisStreamIds, {
      name => $streamName,
      type => $streamType
    }
  }

  # output: an array of hashes - one for each defect
  my @defects = ();

  my $PAGE_SIZE = 1000;  # this cannot exceed 2500
  my $pageSpec = {
    pageSize => $PAGE_SIZE,
    sortAscending => 'true',
    startIndex => 0
  };

  my $i = 0;
  my $defectsPage;

  do {
    $pageSpec->{startIndex} = $i;
    $defectsPage = $defectService->getMergedDefectsForStreams(
      analysisStreamIds => \@analysisStreamIds,
      pageSpec => $pageSpec
    );
    $i += $PAGE_SIZE;
    if ($defectsPage->{totalNumberOfRecords} > 0) {
      push(@defects, @{$defectsPage->{mergedDefects}});
    }
  } while ($i < $defectsPage->{totalNumberOfRecords});

  return @defects;
}


sub getStreamDefects {
  # inputs
  my $defectService = shift;
  my $cid = shift;

  # output: an array of hashes - one for each defect
  my @defects = ();

  @defects = $defectService->getStreamDefects(
    cid => $cid,
    includeDetails => 1,
    # get all stream defects to determine when it was first detected
    scopePattern => "*/*"
  );

  return @defects;
}


# This is in a subroutine because it is verbose considering we're updating a
# single defect identified by CID.  This is because we must fetch all the
# stream defects and update the correct one.
sub updateDefect {
  # inputs
  my $defectService = shift;
  my $cid = shift;
  my $streamName = shift;
  my $defectStateSpec = shift;  # map of optional elements to update

  # updateMergedDefect was removed with the introduction of v1 and so we need
  # to query for all stream defects and then update those
  my @streamDefects = $defectService->getStreamDefects(
    cid => $cid,
    includeDetails => 'false',
    scopePattern => "*/$streamName"
  );

  # As of the Web API v1 the streamDefectDataIdObject looks like:
  #   <xs:complexType name="streamDefectIdDataObj">
  #     <xs:sequence>
  #       <xs:element name="id" type="xs:long" />
  #       <xs:element name="verNum" type="xs:int" />
  #     </xs:sequence>
  #   </xs:complexType>
  #
  # and is located in the streamDefectDataObj->{id}
  my @streamDefectIds = ();
  foreach my $streamDefect (@streamDefects) {
    push(@streamDefectIds, $streamDefect->{id});
  }

  $defectService->updateStreamDefects(
    streamDefectIds => \@streamDefectIds,
    defectStateSpec => $defectStateSpec
  );
}


##############################################################################
######## Main Script #########################################################

handle_command_line_options();

$defectService = new Coverity::WS::v2::DefectService(
  host => $opt_host,
  port => $opt_port,
  username => $opt_username,
  password => $opt_password
);

$configurationService = new Coverity::WS::v2::ConfigurationService(
  host => $opt_host,
  port => $opt_port,
  username => $opt_username,
  password => $opt_password
);

$administrationService = new Coverity::WS::v2::AdministrationService(
  host => $opt_host,
  port => $opt_port,
  username => $opt_username,
  password => $opt_password
);


my @mergedDefects;

if ($opt_project) {
  @mergedDefects = getMergedDefectsForProject($defectService, $opt_project);
} else {
  @mergedDefects = getMergedDefectsForStreams($defectService, \@opt_streams);
}


foreach my $defect (@mergedDefects) {
  print "MERGED_DEFECT: CID $defect->{cid}  $defect->{checker}\n";
  print "  firstDetected: $defect->{firstDetected}\n";

  #print Dumper($defect);

  # We have the firstDetected timestamp in the mergedDefect
  # We have the streams in the streamDefects
  # then get the snapshots for each stream

  # then look for a match on timestamp... if there is only one we're done
  # would be nice to do some sanity checking though...


  # determine what streams this defect appears in...
  my @streamIds;

  my @streamDefects = $defectService->getStreamDefects(
    cid => $defect->{'cid'},
    includeDetails => 'false',
    scopePattern => '*/*'
  );

  print "  streams:";
  foreach my $sd (@streamDefects) {
    #print "  streamDefect\n";
    #print Dumper($sd);
    push @streamIds, $sd->{'streamId'};
    print "  " . $sd->{'streamId'}->{'name'};
    #print "  streamId.name: $sd->{streamId}->{name}\n";
  }
  print "\n";

  print "  snapshots:\n";
  foreach my $streamId (@streamIds) {
    print "    stream $streamId->{'name'}\n";
    my @snapshots = $configurationService->getSnapshotsForStream(
      streamId => $streamId
    );
    for my $snapshot (@snapshots) {
      #print Dumper($snapshot);
      print "      $snapshot->{'snapshotId'}->{'id'}  $snapshot->{'target'}  $snapshot->{'version'}  $snapshot->{'description'}  $snapshot->{'dateCreated'}";
      if ($defect->{'firstDetected'} eq $snapshot->{'dateCreated'}) {
        print "  MATCH!!!";
      }
      print "\n";
    }
  }
}



exit(0);


=pod
  eval {
    updateDefect($defectService, $cid, $streamName, {
      owner => $owner,
      comment => 'Assigning owner via SCM history'
    });
  };

  if ($@) {
    $log->warn("Error updating defect $cid: $@");
  } else {
    $log->info("Updated ($streamName:$streamType) CID $cid: $defect->{owner} -> $owner");
  }
=cut

