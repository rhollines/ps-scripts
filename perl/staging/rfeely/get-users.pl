#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2011 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

get-users.pl


=head1 SYNOPSIS

get-users.pl [options] --config CONFIG_FILE


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

This script retrieves all the users in the system.


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
  push(@INC, "$Bin/../lib");
  push(@INC, "$Bin/../Coverity-WS/lib");
  $Script =~ s/\.pl//g;
};

use Log::Log4perl qw(get_logger :levels);
use Coverity::WS::v2::DefectService qw(:checkerTypes);
use Coverity::WS::v2::ConfigurationService;
use Coverity::WS::v2::AdministrationService;
use Coverity::Config;

use SOAP::Lite +trace => 'debug';

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
#  pod2usage(-verbose => 1) if (!$opt_project && @opt_streams == 0);

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

# Get valid users into a hash for easy lookup
my %valid_users;
foreach my $user (getAssignableUsers($administrationService)) {
  print "Username: $user->{username}\n";
  $valid_users{$user->{username}} = 1;
}


