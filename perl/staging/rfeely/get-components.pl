#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2011 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

get-components.pl


=head1 SYNOPSIS

get-components.pl [options] --config CONFIG_FILE --project PROJECT (OR --stream STREAM1 --stream STREAM2 ...)


=head1 OPTIONS

=over 12

=item Required:

=item B<--config>

CONFIG_FILE e.g coverity_pse_config.xml

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

This script retrieves all the component maps defined in CIM


=head1 CONFIGURATION

This script uses a configuration file (usually coverity_pse_config.xml).  There
must be a system of type "scm" defined and the appropriate project or stream(s)
should be mapped to it.


=head1 AUTHOR

 Ronan Feely (rfeely@coverity.com)

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

my $filter;
my @compMaps;

#@compMaps = $configurationService->getComponentMaps( componentMapId => { namePattern => "M1" });
#foreach my $map (@compMaps) {
#  foreach my $rule ($map->{componentPathRules}) {
#    my @temp = $rule;
#    print length($temp[0]);
#print Dumper($temp[0][0]);
##print "$q->{pathPattern} \n";
#    print "\n";
# } 
#}


@compMaps = $configurationService->getComponentMaps( componentMapId => { namePattern => "*" });
foreach my $map (@compMaps) {
                  foreach my $rule ($map->{componentPathRules}) {
                                  foreach my $realrule (@{$rule}) {
                                                  print "$realrule->{componentId}->{name},";
                                                  print "$realrule->{pathPattern}\n";
                                  }
    }
}

