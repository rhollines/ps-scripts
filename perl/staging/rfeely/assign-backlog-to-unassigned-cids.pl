#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2010 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

assign-owner-to-unassigned-cids.pl


=head1 SYNOPSIS

assign-owner-to-unassigned-cids.pl [options] --config CONFIG_FILE --project PROJECT (OR --stream STREAM1 --stream STREAM2 ...)


=head1 OPTIONS

=over 12

=item Required:

=item B<--config>

CONFIG_FILE e.g coverity_pse_config.xml

=item B<--project>

Assign ownership of defects in all streams belonging to a PROJECT OR

=item B<--stream>

Assign ownership of defects in STREAM(s)

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

This script assigns all CIDs of a project or stream(s) to owners based on the
Source Code Management (SCM) system used.  Several modules for different SCM
systems are provided by Coverity inside the lib/Coverity/SCM directory.
Additional plugins can be written and placed within this directory.


=head1 CONFIGURATION

This script uses a configuration file (usually coverity_pse_config.xml).  There
must be a system of type "scm" defined and the appropriate project or stream(s)
should be mapped to it.


=head1 AUTHOR

 Vince Hopson (vhopson@coverity.com)
 James Croall (jcroall@coverity.com)
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
  push(@INC, "$Bin/lib");
  push(@INC, "$Bin/lib-thirdparty"); 
  push(@INC, "$Bin/Coverity-WS/lib");
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
# a list users.  This is because of all the required paging.
sub getAssignableUsers {
  # input
  my $administrationService = shift;

  # output: an array of hashes - one for each user
  my @users = ();

  my $PAGE_SIZE = 100;  # cannot exceed 100
  my $pageSpec = {
    pageSize => $PAGE_SIZE,
    sortAscending => 'true',
    startIndex => 0
  };

  my $i = 0;
  my $usersPage;

  do {
    $pageSpec->{startIndex} = $i;
    $usersPage = $administrationService->getAssignableUsers(
      pageSpec => $pageSpec
    );
    $i += $PAGE_SIZE;
    if ($usersPage->{totalNumberOfRecords} > 0) {
      push(@users, @{$usersPage->{users}});
    }
  } while ($i < $usersPage->{totalNumberOfRecords});

  return @users;
}


# This is in a subroutine because it verbose considering we're only retrieving
# a list of merged defects.  This is because of all the required paging.
sub getMergedDefects {
  # inputs
  my $defectService = shift;
  my $streamName = shift;
  my $streamType = shift;

  # output: an array of hashes - one for each defect
  my @defects = ();

  my $PAGE_SIZE = 2000;
  my $pageSpec = {
    pageSize => $PAGE_SIZE,
    sortAscending => 'true',
    startIndex => 0
  };

  my $i = 0;
  my $defectsPage;

  # Uncommenting this and passing in the filterSpec to the API will speed up
  # the query greatly but it will also cause the --force option to not work
  # as advertised.
  #my $filterSpec = {
  #  ownerNameList = 'Unassigned',
  #};

  do {
    $pageSpec->{startIndex} = $i;
    $defectsPage = $defectService->getMergedDefectsForStreams(
      analysisStreamIds => {
        name => $streamName,
        type => $streamType
      },
      # filterSpec => $filterSpec,
      pageSpec => $pageSpec
    );
    $i += $PAGE_SIZE;
    if ($defectsPage->{totalNumberOfRecords} > 0) {
      push(@defects, @{$defectsPage->{mergedDefects}});
    }
  } while ($i < $defectsPage->{totalNumberOfRecords});

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

# A single merged defect e.g. CID 500 may have defects in multiple streams.
# This script will only update certain defects in particular streams.  If
# invoked with one or more --stream parameters, only update defects in the
# indicated streams.  If invoked with --project then only update defects in
# the streams that belong to the given project.

# if --project is given then determine what streams belong to that project and
# operate on those.
if ($opt_project) {
  my @projects;
  @projects = $configurationService->getProjects( filterSpec => { namePattern => $opt_project } );
  foreach my $project (@projects) {
    foreach my $stream (@{$project->{streams}}) {
      my $streamName = $stream->{id}->{name};
      my $streamType = $stream->{id}->{type};
      # you can't triage defects in a SOURCE stream
      if ($streamType eq STATIC or $streamType eq DYNAMIC) {
        push @opt_streams, "$streamName:$streamType";
      }
    }
  }
}

# Verify that all streams exist
my @streamsOnServer = $configurationService->getStreams();
foreach my $stream (@opt_streams) {
  my ($streamName, $streamType) = split(':', $stream);
  $streamType = $streamType ? $streamType : STATIC;

  my $seen = 0;
  foreach my $streamOnServer (@streamsOnServer) {
    if ($streamOnServer->{id}->{name} eq $streamName and $streamOnServer->{id}->{type} eq $streamType) {
      $seen = 1;
      last;
    }
  }
  if (!$seen) {
    $log->error("stream '$streamName:$streamType' does not exist on server");
    die("ERROR: stream '$streamName:$streamType' does not exist on server");
  }
}

# Get valid users into a hash for easy lookup
my %valid_users;
foreach my $user (getAssignableUsers($administrationService)) {
  $valid_users{$user->{username}} = 1;
}

foreach my $stream (@opt_streams) {
  # find and load the correct scm plugin
  my $scm;
  my @systems;
  if ($opt_project) {
    @systems = $coverityConfig->get_project_systems($opt_project);
  } else {
    @systems = $coverityConfig->get_stream_systems($stream);
  }

  foreach my $system (@systems) {
    # use the first matching scm system
    if ($system->{type} eq 'scm') {
      my $plugin = "Coverity::SCM::" . $system->{plugin};
      eval "use $plugin";
      # The system hash has everything the plugin needs so pass it in
      $scm = $plugin->new( %{$system} );
    }
  }

  # Extract stream name and type, if type is not specified default to
  # STATIC analysis results
  my ($streamName, $streamType) = split(':', $stream);
  $streamType = $streamType ? $streamType : STATIC;

  my @defects = getMergedDefects($defectService, $streamName, $streamType);
  foreach my $defect (@defects) {
    if (!$opt_force and $defect->{owner} ne "Unassigned") {
      next;
    }

    my $cid = $defect->{cid};

    # Ask SCM who the last person to edit this file was.
    # my $owner = $scm->get_owner($defect->{filePathname});
    # Assign owner 
    my $owner = 'backlog'; 

    if ($owner) {
      if ($valid_users{$owner}) {
        if (!$opt_dry_run) {
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
        } else {
          $log->info("[DRY-RUN] Updated ($streamName:$streamType) CID $cid: $defect->{owner} -> $owner");
        }
      } else {
        $log->info("CID $cid: User $owner does not exist in CIM or is not assignable");
      }
    } else {
      $log->info("CID $cid: SCM returned no owner for file $defect->{filePathname}");
    }
  }
}
