#!/usr/bin/perl -w

=pod

=head1 COPYRIGHT

(c) 2010 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

set-defect-severity.pl


=head1 SYNOPSIS

set-defect-severity.pl [options] --mapping MAPPING_FILE --project PROJECT (OR --stream STREAM1 --stream STREAM2 ...)


=head1 OPTIONS

=over 8

=item Required:

=item B<--mapping>
MAPPING_FILE of checker to severity

=item B<--project>
Update defects in all streams belonging to a PROJECT OR

=item B<--stream>
Update defects in STREAM(s)


=item Optional:

=item B<--config>
CONFIG_FILE e.g coverity_pse_config.xml OR

=item B<--host>
CIM server HOST

=item B<--port>
CIM server PORT

=item B<--username>
CIM server USERNAME with admin access

=item B<--password>
CIM server PASSWORD

=item B<--default-severity>
Default severity if not specified in mapping file

=item B<--force>
Apply severity even if already set

=item B<--dry-run>
Test run, do not update defects

=item B<--help>
Print documentation and exit

=back


=head1 DESCRIPTION

This program will set the severity level of a stream's defects based on a
checker to severity mapping file.  By default, it will only set the severity of
defects with an 'Unspecified' severity level.

=head1 AUTHOR

 James Croall (jcroall@coverity.com)
 Sumio Kiyooka (skiyooka@coverity.com)

=cut

########################################################################
####### Initialization #################################################

use strict;

use Getopt::Long;
use Pod::Usage;
use File::Basename;
use FindBin qw($Bin $Script);
use Data::Dumper;

BEGIN {
  push(@INC, "$Bin/../lib");
  push(@INC, "$Bin/../lib-thirdparty");
  push(@INC, "$Bin/../Coverity-WS/lib");
  $Script =~ s/\.pl//g;
}

use Log::Log4perl qw(get_logger :levels);
use Coverity::WS::v2::DefectService qw(:checkerTypes);
use Coverity::WS::v2::ConfigurationService;
use Coverity::Config;

# Initialize logging
Log::Log4perl->init("$Bin/log.conf");
my $logger = get_logger($Script);


#######################################################################
####### Global data and configuration #################################

my $opt_mapping;
my $opt_project;
my @opt_streams;

my $opt_host;
my $opt_port;
my $opt_username;
my $opt_password;

my $opt_default_severity;

my $opt_coverity_config;
my $coverityConfig;

my $opt_force = 0;
my $opt_dry_run = 0;
my $opt_help = 0;

my $defectService;
my $configurationService;

my $checkerSeverities;
my $validSeverities = {};


########################################################################
####### Subroutines ####################################################

sub handle_command_line_options {
  GetOptions(
    'mapping=s' => \$opt_mapping,
    # What to operate on
    'project=s' => \$opt_project,
    'stream=s' => \@opt_streams,
    # Standard CIM options
    'host:s' => \$opt_host,
    'port:s' => \$opt_port,
    'username:s' => \$opt_username,
    'password:s' => \$opt_password,
    # Script options
    'default-severity:s' => \$opt_default_severity,
    # Common script options
    'config:s' => \$opt_coverity_config,
    'force!' => \$opt_force,
    'dry-run!' => \$opt_dry_run,
    'help|?' => \$opt_help
  ) or pod2usage(-verbose => 1);
  pod2usage(-verbose => 2) if $opt_help;
  pod2usage(-verbose => 1) if (!$opt_mapping);
  pod2usage(-verbose => 1) if (!$opt_project && @opt_streams == 0);

  if ($opt_project && @opt_streams > 0) {
    $logger->error("You can only specify a --project OR --stream(s).  Not both.");
    exit(1);
  }

  # the legacy --config is replaced by --mapping because --config will be used
  # to specify the actual script configuration file
  unless (-e $opt_mapping) {
    $logger->error("Unable to find mapping file at '$opt_mapping'\n");
    die "ERROR: could not find configuration file at '$opt_mapping'\n";
  }

  # Load configuration and set values from config file if specified
  if ($opt_coverity_config) {
    $coverityConfig = new Coverity::Config(filename => $opt_coverity_config);

    # Command-line options override values in config file.
    $opt_host = $opt_host ? $opt_host : $coverityConfig->get_cim_host();
    $opt_port = $opt_port ? $opt_port : $coverityConfig->get_cim_port();
    $opt_username = $opt_username ? $opt_username : $coverityConfig->get_cim_username();
    $opt_password = $opt_password ? $opt_password : $coverityConfig->get_cim_password();
  }

  if (!$opt_host or !$opt_port or !$opt_username or !$opt_password) {
    $logger->error("Must specify CIM server and authentication details on command line or configuration file");
    pod2usage(-verbose => 1);
  }
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

  my $PAGE_SIZE = 100;
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
      analysisStreamIds => {
        name => $streamName,
        type => $streamType
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


########################################################################
####### Main Script ####################################################

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
    $logger->error("stream '$streamName:$streamType' does not exist on server");
    die("ERROR: stream '$streamName:$streamType' does not exist on server");
  }
}

# Get list of valid severities
my @all_severities = $configurationService->getSeverities();
foreach my $severity (@all_severities) {
  $validSeverities->{$severity} = 1;
}

open (MAPPING, $opt_mapping);
while (<MAPPING>) {
  # Skip comments.
  next if /^\s*#/;
  # Skip blank lines
  next if /^\s*$/;
  # Skip lone commas
  next if /^\s*,\s*$/;

  my @fields = (split(/,/,$_));

  if (scalar(@fields) == 2) {
    my $regexp = $fields[0];
    my $severity = $fields[1];
    $severity =~ s/\r?\n$//;  # handle both Windows and Unix newlines

    unless (defined($regexp) and length($regexp)) {
      $logger->error("malformed regexp expression, '$regexp' (empty regexp not permitted).");
      die("ERROR: malformed regexp expression, '$regexp' (empty regexp not permitted).");
    }

    unless (defined($severity) and length($severity)) {
      $logger->error("malformed severity, '$severity' (empty severity not permitted).");
      die("ERROR: malformed severity, '$severity' (empty severity not permitted).");
    }

    unless (exists($validSeverities->{$severity})) {
      $logger->error("invalid severity '$severity'.  The valid severities are:", Dumper(sort(keys(%$validSeverities))));
      die("ERROR: invalid severity '$severity'.  The valid severities are:", Dumper(sort(keys(%$validSeverities))));
    }

    if (exists($checkerSeverities->{$regexp})) {
      $logger->error("Duplicate configuration detected for checker regexp '$regexp'.\nEach checker regexp may only appear once.");
      die("ERROR: Duplicate configuration detected for checker regexp '$regexp'.\nEach checker regexp may only appear once.");
    }
    $checkerSeverities->{$regexp} = $severity;
  } else {
    if (scalar(@fields) > 2) {
      $logger->error("malformed configuration line '$_' found in configuration file '$opt_mapping', too many commas?");
      die("ERROR: malformed configuration line '$_' found in configuration file '$opt_mapping', too many commas?");
    } else {
      $logger->error("malformed configuration line '$_' found in configuration, format is CHECKER_REGEXP,Severity");
      die("ERROR: malformed configuration line '$_' found in configuration, format is CHECKER_REGEXP,Severity");
    }
  }
}


foreach my $stream (@opt_streams) {
  # Extract stream name and type, if type is not specified default to
  # STATIC analysis results
  my ($streamName, $streamType) = split(':', $stream);
  $streamType = $streamType ? $streamType : STATIC;

  my @defects = getMergedDefects($defectService, $streamName, $streamType);
  foreach my $defect (@defects) {
    if (!$opt_force and $defect->{severity} ne "Unspecified") {
      next;
    }

    my $checker = $defect->{checker};
    my $severity = $opt_default_severity ? $opt_default_severity : $defect->{severity};

    foreach my $checkerRegex (sort(keys(%{$checkerSeverities}))) {
      if ($checker =~ /$checkerRegex/) {
        $severity = $checkerSeverities->{$checkerRegex};
        last;
      }
    }

    if ($severity ne $defect->{severity} or $opt_force) {
      if (!$opt_dry_run) {
        eval {
          updateDefect($defectService, $defect->{cid}, $streamName, {
            severity => $severity,
            comment => 'Setting severity from mapping file'
          });
        };

        if ($@) {
          $logger->warn("Error updating defect $defect->{cid}: $@");
        } else {
          $logger->info("Updated ($streamName:$streamType) CID $defect->{cid}: $defect->{severity} -> $severity");
        }
      } else {
        $logger->info("[DRY-RUN] Updated ($streamName:$streamType) CID $defect->{cid}: $defect->{severity} -> $severity");
      }
    }
    # TODO-SK: I should print out a message for CHECKERS that aren't in the mapping list...
  }
}

