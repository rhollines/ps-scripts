#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2011 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

diff-snapshots.pl


=head1 SYNOPSIS

diff-snapshots.pl [options] --config CONFIG_FILE --stream STREAM --snapshot1 SNAPSHOT1 --snapshot2 SNAPSHOT2


=head1 OPTIONS

=over 12

=item Required:

=item B<--config>

CONFIG_FILE e.g coverity_pse_config.xml

=item B<--stream>

STREAM containing snapshots

=item B<--snapshot1>

First snapshot to compare

=item B<--snapshot2>

Second snapshot to compare

=item Optional:

=item B<--host>

CIM server HOST

=item B<--port>

CIM server PORT

=item B<--username>

CIM server USERNAME with admin access

=item B<--password>

CIM server PASSWORD

=item B<--debug>

Print lots of debugging information.

=item B<--help>

Print documentation and exit

=back


=head1 DESCRIPTION

List defects introduced for given snapshot.  A PROJECT or STREAM must be
specified for context.  If you supply PROJECT then it will include a URL.


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

my $opt_stream;

my $opt_snapshot1;
my $opt_snapshot2;

my $opt_host;
my $opt_port;
my $opt_username;
my $opt_password;

my $opt_coverity_config;
my $coverityConfig;

my $opt_debug = 0;
my $opt_help = 0;

my $defectService;
my $configurationService;
my $administrationService;


##############################################################################
####### Subroutines ##########################################################

sub handle_command_line_options {
  GetOptions(
    # What to operate on
    'stream=s' => \$opt_stream,
    'snapshot1=s' => \$opt_snapshot1,
    'snapshot2=s' => \$opt_snapshot2,
    # Standard CIM options
    'host=s' => \$opt_host,
    'port=s' => \$opt_port,
    'username=s' => \$opt_username,
    'password=s' => \$opt_password,
    # Common script options
    'config=s' => \$opt_coverity_config,
    'debug|?' => \$opt_debug,
    'help|?' => \$opt_help
  ) or pod2usage(-verbose => 1);
  pod2usage(-verbose => 2) if $opt_help;
  pod2usage(-verbose => 1) if (!$opt_coverity_config);
  pod2usage(-verbose => 1) if (!$opt_stream);
  pod2usage(-verbose => 1) if (!$opt_snapshot1 || !$opt_snapshot2);

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
sub getMergedDefectsForStream {
  # inputs
  my $defectService = shift;
  my $streamName = shift;

  my @analysisStreamIds;  # array of { name => , type => } hashes

  push @analysisStreamIds, {
    name => $streamName,
    type => 'STATIC'
  };

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


# First, retrieve the snapshot information...

my @streamIds;

my @allStreams = $configurationService->getStreams();
foreach my $stream (@allStreams) {
  if ($stream->{'id'}->{'name'} eq $opt_stream && $stream->{'id'}->{'type'} eq 'STATIC') {
    push @streamIds, $stream->{'id'};
  }
}

my $snapshot1;
my $snapshot2;

foreach my $streamId (@streamIds) {
  my @snapshots = $configurationService->getSnapshotsForStream(
    streamId => $streamId
  );
  for my $s (@snapshots) {
    if ($s->{'snapshotId'}->{'id'} eq $opt_snapshot1) {
      $snapshot1 = $s;
    } elsif ($s->{'snapshotId'}->{'id'} eq $opt_snapshot2) {
      $snapshot2 = $s;
    }
  }
}

if (!$snapshot1 || !$snapshot2) {
  if (!$snapshot1) {
    print "ERROR - No such snapshot $opt_snapshot1 in stream $opt_stream\n";
  }
  if (!$snapshot2) {
    print "ERROR - No such snapshot $opt_snapshot2 in stream $opt_stream\n";
  }
  exit(1);
} elsif ($opt_debug) {
  print Dumper($snapshot1);
  print Dumper($snapshot2);
}


my @snapshot1_cids = $defectService->getMergedDefectIdsForSnapshot( snapshotId => { id => $opt_snapshot1 } );
my @snapshot2_cids = $defectService->getMergedDefectIdsForSnapshot( snapshotId => { id => $opt_snapshot2 } );

# Populate the hashes for quick inclusion lookup
# hash of CID (int) to constant 1
my %snapshot1_cids_hash = ();
my %snapshot2_cids_hash = ();

foreach my $cid (@snapshot1_cids) {
  $snapshot1_cids_hash{$cid} = 1;
}

foreach my $cid (@snapshot2_cids) {
  $snapshot2_cids_hash{$cid} = 1;
}


my @mergedDefects;
@mergedDefects = getMergedDefectsForStream($defectService, $opt_stream);


print "Snapshot1,Snapshot2,CID,Checker,Status,Classification,Severity,Component,ExtRef,LastDetected,LastFixed";
print "\n";

foreach my $defect (@mergedDefects) {
  if ($snapshot1_cids_hash{$defect->{cid}}) {
    print "$opt_snapshot1";
  } else {
    print " ";
  }
  print ",";

  if ($snapshot2_cids_hash{$defect->{cid}}) {
    print "$opt_snapshot2";
  } else {
    print " ";
  }
  print ",";

  print "$defect->{cid}," .
        "$defect->{checker}," .
        "$defect->{status}," .
        "$defect->{classification}," .
        "$defect->{severity}," .
        #"$defect->{filePathname}," .
        "$defect->{componentName}," .
        "$defect->{externalReference}," .
        "$defect->{lastDetected}," .
        "$defect->{lastFixed}";
  print "\n";
}

