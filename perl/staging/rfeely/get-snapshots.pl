#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2011 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

get-snapshots.pl


=head1 SYNOPSIS

get-snapshots.pl [options] --config CONFIG_FILE --project PROJECT (OR --stream STREAM1 --stream STREAM2 ...)


=head1 OPTIONS

=over 12

=item Required:

=item B<--config>

CONFIG_FILE e.g coverity_pse_config.xml

=item B<--project>

List all snapshots in all streams belonging to a PROJECT OR

=item B<--stream>

List all snapshots in STREAM(s)

=item Optional:

=item B<--host>

CIM server HOST

=item B<--port>

CIM server PORT

=item B<--username>

CIM server USERNAME with admin access

=item B<--password>

CIM server PASSWORD

=item B<--help>

Print documentation and exit

=back


=head1 DESCRIPTION

List all snapshots in a given project or stream(s).  Retrieve the snapshot
target, version, and description labels.  Also show the date created.


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

my $opt_project;
my @opt_streams;

my $opt_host;
my $opt_port;
my $opt_username;
my $opt_password;

my $opt_coverity_config;
my $coverityConfig;

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

my @streamIds;

if ($opt_project) {
  my @projects = $configurationService->getProjects();
  foreach my $project (@projects) {
    if ($opt_project eq $project->{'id'}->{'name'}) {
      foreach my $stream (@{$project->{'streams'}}) {
        if ($stream->{'id'}->{'type'} eq 'STATIC') {
          push @streamIds, $stream->{'id'};
        }
      }
    }
  }
} else {
  my @allStreams = $configurationService->getStreams();
  foreach my $stream (@allStreams) {
    foreach my $s (@opt_streams) {
        if ($stream->{'id'}->{'name'} eq $s && $stream->{'id'}->{'type'} eq 'STATIC') {
          push @streamIds, $stream->{'id'};
        }
    }
  }
}

print "snapshot:  target, sourceVersion, description, dateCreated\n\n";
foreach my $streamId (@streamIds) {
  print "stream $streamId->{'name'}\n";

  my @snapshots = $configurationService->getSnapshotsForStream(
    streamId => $streamId
  );

  my @sorted = sort { $b->{'dateCreated'} cmp $a->{'dateCreated'} } @snapshots;
  for my $snapshot (@sorted) {
    #print Dumper($snapshot);
    printf("  %5d:  ", $snapshot->{'snapshotId'}->{'id'});
    print "$snapshot->{'target'}, $snapshot->{'sourceVersion'}, $snapshot->{'description'}, $snapshot->{'dateCreated'}";
    print "\n";
  }
  print "\n";
}

