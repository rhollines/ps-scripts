#!/usr/bin/perl -w

=pod

=head1 COPYRIGHT

(c) 2011 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

create-components.pl


=head1 SYNOPSIS

create-components.pl [options] --components COMPONENTS_FILE --map MAP_NAME


=head1 OPTIONS

=over 8

=item Required:

=item B<--components>
COMPONENTS_FILE of component regexes

=item B<--map>
Create map MAP_NAME 


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
use Coverity::WS::v2::AdministrationService;
use Coverity::Config;

# Initialize logging
Log::Log4perl->init("$Bin/log.conf");
my $logger = get_logger($Script);


#######################################################################
####### Global data and configuration #################################

my $opt_components;
my $opt_map;

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
my $administrationService;

my $componentDefs;
my $validSeverities = {};


########################################################################
####### Subroutines ####################################################

sub handle_command_line_options {
  GetOptions(
    'components=s' => \$opt_components,
    # Map to create 
    'map=s' => \$opt_map,
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
  pod2usage(-verbose => 1) if (!$opt_components);
  pod2usage(-verbose => 1) if (!$opt_map);
  
  # the legacy --config is replaced by --streams because --config will be used
  # to specify the actual script configuration file
  unless (-e $opt_components) {
    $logger->error("Unable to find components file at '$opt_components'\n");
    die "ERROR: could not find configuration file at '$opt_components'\n";
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

my @componentPathRules = ();
my @defectRules = ();
my @comps = ();

open (MAPPING, $opt_components);
while (<MAPPING>) {
  # Skip comments.
  next if /^\s*#/;
  # Skip blank lines
  next if /^\s*$/;
  # Skip lone commas
  next if /^\s*,\s*$/;

  my @fields = (split(/,/,$_));

  if (scalar(@fields) == 3) {
    my $component = $fields[0];
    my $pathRegex = $fields[1];
    my $user = $fields[2];
    $user =~ s/\r?\n$//;  # handle both Windows and Unix newlines

    unless (defined($component) and length($component)) {
      $logger->error("malformed component, '$component' (empty component not permitted).");
      die("ERROR: malformed component, '$component' (empty component not permitted).");
    }

    unless (defined($pathRegex) and length($pathRegex)) {
      $logger->error("malformed regex, '$pathRegex' (empty regex not permitted).");
      die("ERROR: malformed regex, '$pathRegex' (empty regex not permitted).");
    }

    if (exists($componentDefs->{$component})) {
      $logger->error("Duplicate configuration detected for component '$component'.\nEach component may only appear once.");
      die("ERROR: Duplicate configuration detected for component '$component'.\nEach component may only appear once.");
    }
    $componentDefs->{$component} = $pathRegex;

    my $compObj = {};
    $compObj->{componentId}->{name} = $opt_map . "." . $component;
    $compObj->{excludeComponent} = 'false';
    $compObj->{groupPermissions}->{accessAllowed} = 'true';
    $compObj->{groupPermissions}->{groupId}->{name} = 'Users';

    my $pathRuleObj = {};
    $pathRuleObj->{componentId}->{name} = $opt_map . "." . $component;
    $pathRuleObj->{pathPattern} = lc $pathRegex;

    my $defectRuleObj = {};
    if ($user) {
      if ($valid_users{$user}) {
	 $defectRuleObj->{componentId}->{name} = $opt_map . "." . $component;
         $defectRuleObj->{defaultOwner} = $user;
         push(@defectRules, $defectRuleObj);
      } else {
        $logger->info("User $user does not exist in CIM or is not assignable");
      }
    } else {
      $logger->info("No owner for component $component");
    }

    push(@comps, $compObj);
    push(@componentPathRules, $pathRuleObj);

  } else {
    if (scalar(@fields) > 3) {
      $logger->error("malformed component line '$_' found in configuration file '$opt_components', too many commas?");
      die("ERROR: malformed component line '$_' found in configuration file '$opt_components', too many commas?");
    } else {
      $logger->error("malformed component line '$_' found in configuration, format is Component,RegEx");
      die("ERROR: malformed component line '$_' found in configuration, format is Component,RegEx");
    }
  }
}

my $componentMapObj = {};
$componentMapObj->{componentMapName} = $opt_map;
$componentMapObj->{description} = "Automatically adding $opt_map components";
$componentMapObj->{componentPathRules} = \@componentPathRules;
$componentMapObj->{components} = \@comps;
if(@defectRules) {
  $componentMapObj->{defectRules} = \@defectRules;
}
$configurationService->createComponentMap( componentMapSpec => $componentMapObj );

