#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2010 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

test-scm-plugin.pl


=head1 SYNOPSIS

test-scm-plugin.pl [options] --config CONFIG_FILE --project PROJECT (OR --stream STREAM) --filepath FILEPATH


=head1 OPTIONS

=over 12

=item Required:

=item B<--config>

CONFIG_FILE e.g coverity_pse_config.xml

=item B<--project>

Use PROJECT to determine SCM plugin OR

=item B<--stream>

Use STREAM to determine SCM plugin

=item B<--filepath>

Lookup owner of given FILEPATH

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

This script can be used to test the loading and execution of an SCM plugin
based on either a project or stream.  It uses the plugin to perform an owner
lookup based on the given filepath.

Once the plugin is working, assign-owners-to-unassigned-cids.pl can be called.


=head1 CONFIGURATION

This script uses a configuration file (usually coverity_pse_config.xml). There
must be a system of type "scm" defined and the appropriate project or stream
should be mapped to it.  The system contains a "strip-path" tag that can be
used to strip the correct prefix before the filepath is passed to the command
execution.


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
my $opt_stream;
my $opt_filepath;

my $opt_host;
my $opt_port;
my $opt_username;
my $opt_password;

my $opt_coverity_config;
my $coverityConfig;

my $opt_help = 0;

my $administrationService;


##############################################################################
####### Subroutines ##########################################################

sub handle_command_line_options {
  GetOptions(
    # What to operate on
    'project=s' => \$opt_project,
    'stream=s' => \$opt_stream,
    'filepath=s' => \$opt_filepath,
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
  pod2usage(-verbose => 1) if (!$opt_project && !$opt_stream);
  pod2usage(-verbose => 1) if (!$opt_filepath);

  if ($opt_project && $opt_stream) {
    $log->error("You can only specify a --project OR --stream.  Not both.");
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

$administrationService = new Coverity::WS::v2::AdministrationService(
  host => $opt_host,
  port => $opt_port,
  username => $opt_username,
  password => $opt_password
);

# Get valid users into a hash for easy lookup
my %valid_users;
foreach my $user (getAssignableUsers($administrationService)) {
  $valid_users{$user->{username}} = 1;
}

# find and load the correct scm plugin
my $scm;
my @systems;
if ($opt_project) {
  @systems = $coverityConfig->get_project_systems($opt_project);
} else {
  @systems = $coverityConfig->get_stream_systems($opt_stream);
}

foreach my $system (@systems) {
  # use the first matching scm system
  if ($system->{type} eq 'scm') {
    my $plugin = "Coverity::SCM::" . $system->{plugin};
    $log->info("loading plugin $plugin");
    eval "use $plugin";
    # The system hash has everything the plugin needs so pass it in
    $scm = $plugin->new( %{$system} );
    last;
  }
}

# Ask SCM who the last person to edit this file was.
#print Dumper($scm);
my $owner = $scm->get_owner($opt_filepath);

if ($owner) {
  if ($valid_users{$owner}) {
    $log->info("plugin returned owner: $owner");
  } else {
    $log->info("User $owner does not exist in CIM or is not assignable");
  }
} else {
  $log->info("SCM returned no owner for file $opt_filepath");
}
