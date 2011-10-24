#!/usr/bin/perl -w

=pod

=head1 COPYRIGHT

(c) 2011 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

create-streams.pl


=head1 SYNOPSIS

create-streams.pl [options] --streams STREAMS_FILE --branch BRANCH


=head1 OPTIONS

=over 8

=item Required:

=item B<--streams>
STREAMS_FILE of rpm streams

=item B<--branch>
Create all streams with BRANCH appended


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

=item B<--force>
Apply severity even if already set

=item B<--dry-run>
Test run, do not update defects

=item B<--help>
Print documentation and exit

=back


=head1 DESCRIPTION

This program will create a bunch of streams for a given branch.
It will error out if the given stream already exists 

=head1 AUTHOR

 James Croall (jcroall@coverity.com)
 Sumio Kiyooka (skiyooka@coverity.com)
 Ronan Feely (rfeely@coverity.com)

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
  push(@INC, "$Bin/lib");
  push(@INC, "$Bin/lib-thirdparty");
  push(@INC, "$Bin/Coverity-WS/lib");
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

my $opt_streams;
my $opt_branch;

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
    'streams=s' => \$opt_streams,
    # What to operate on
    'branch=s' => \$opt_branch,
    # Standard CIM options
    'host:s' => \$opt_host,
    'port:s' => \$opt_port,
    'username:s' => \$opt_username,
    'password:s' => \$opt_password,
    # Common script options
    'config:s' => \$opt_coverity_config,
    'force!' => \$opt_force,
    'dry-run!' => \$opt_dry_run,
    'help|?' => \$opt_help
  ) or pod2usage(-verbose => 1);
  pod2usage(-verbose => 2) if $opt_help;
  pod2usage(-verbose => 1) if (!$opt_streams);
  pod2usage(-verbose => 1) if (!$opt_branch);

  # the legacy --config is replaced by --streams because --config will be used
  # to specify the actual script configuration file
  unless (-e $opt_streams) {
    $logger->error("Unable to find streams file at '$opt_streams'\n");
    die "ERROR: could not find configuration file at '$opt_streams'\n";
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

open (MAPPING, $opt_streams);
while (<MAPPING>) {
  # Skip comments.
  next if /^\s*#/;
  # Skip blank lines
  next if /^\s*$/;
  # Skip lone commas
  next if /^\s*,\s*$/;

  my @fields = $_;

  if (scalar(@fields) == 1) {
    my $newStream = $fields[0];
    $newStream =~ s/\r?\n$//;  # handle both Windows and Unix newlines

    unless (defined($newStream) and length($newStream)) {
      $logger->error("malformed stream, '$newStream' (empty stream not permitted).");
      die("ERROR: malformed stream, '$newStream' (empty stream not permitted).");
    }

    # TODO
    #if (exists($checkerSeverities->{$regexp})) {
    #  $logger->error("Duplicate configuration detected for checker regexp '$regexp'.\nEach checker regexp may only appear once.");
    #  die("ERROR: Duplicate configuration detected for checker regexp '$regexp'.\nEach checker regexp may only appear once.");
    #}
    #$checkerSeverities->{$regexp} = $severity;
    my $myStream;
    $myStream->{name} = "$newStream-$opt_branch";
    $myStream->{language} = CXX;
    $myStream->{type} = SOURCE;

    $configurationService->createStream(
      streamSpec => $myStream
    );

    $myStream->{type} = STATIC;
    $configurationService->createStream(
      streamSpec => $myStream
    );
  } else {
    if (scalar(@fields) > 1) {
      $logger->error("malformed stream line '$_' found in configuration file '$opt_streams', too many commas?");
      die("ERROR: malformed stream line '$_' found in configuration file '$opt_streams', too many commas?");
    } else {
      $logger->error("malformed stream line '$_' found in configuration, format is StreamName");
      die("ERROR: malformed stream line '$_' found in configuration, format is StreamName");
    }
  }
}


