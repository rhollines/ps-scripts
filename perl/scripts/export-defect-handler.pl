#!/usr/bin/perl -w

=pod

=head1 COPYRIGHT

(c) 2010 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

export-defect-handler.pl


=head1 SYNOPSIS

export-defect-handler.pl [options] --config CONFIG_FILE XML_FILE


=head1 OPTIONS

=over 8

=item Required:

=item B<--config>
CONFIG_FILE e.g coverity_pse_config.xml

=item B<XML_FILE>
cid.xml exported from CIM

=item

=item B<--host>
CIM server HOST

=item B<--port>
CIM server PORT

=item B<--username>
CIM server USERNAME with admin access

=item B<--password>
CIM server PASSWORD

=item B<--force>
Apply external reference even if already set

=item B<--help>
Print documentation and exit

=back


=head1 DESCRIPTION

Exports a defect to an issue tracking system.  Several modules for different
issue tracking systems are provided by the Coverity library inside the
IssueTracking directory.


=head1 CONFIGURATION

CIM configuration, issue tracking system parameters, and stream/project
mappings are described in an xml file.  See coverity_pse_config.xml for an
example.


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
  push(@INC, "$Bin/../Coverity-WS/lib");
  $Script =~ s/\.pl//g;
};

use Log::Log4perl qw(get_logger :levels);
use Coverity::WS::v2::DefectService qw(:checkerTypes);
use Coverity::WS::v2::ConfigurationService;
use Coverity::WS::v2::AdministrationService;
use Coverity::Config;
use XML::Simple;

# Initialize logging
Log::Log4perl->init("$Bin/log.conf");
my $log = get_logger($Script);


use SOAP::Lite; # +trace => [ transport =>
#sub {
#    print Dumper(@_);
#  }
#];

#######################################################################
####### Global data and configuration #################################

my $opt_host = "";
my $opt_port = "";
my $opt_username = "";
my $opt_password = "";

my $opt_coverity_config;
my $coverityConfig;

my $opt_force = 0;
my $opt_help = 0;

my $defectService;
my $configurationService;
my $administrationService;

my $exportedDefectFile = "";
my $projectName;
my $cid;


##############################################################################
####### Subroutines ##########################################################

sub handle_command_line_options {
  GetOptions(
    # Standard CIM options
    'host=s' => \$opt_host,
    'port=s' => \$opt_port,
    'username=s' => \$opt_username,
    'password=s' => \$opt_password,
    # Common script options
    'config=s' => \$opt_coverity_config,
    'force!' => \$opt_force,
    'help|?' => \$opt_help
  ) or pod2usage(-verbose => 1);
  pod2usage(-verbose => 2) if $opt_help;
  pod2usage(-verbose => 1) if (!$opt_coverity_config);

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

  # Exported defect XML
  if (scalar(@ARGV) != 1) {
    $log->error("Must provide exported defect filename");
    exit 1;
  }

  $exportedDefectFile = $ARGV[0];

  if (! -f $exportedDefectFile) {
    $log->error("Unable to open exported defect XML file '$exportedDefectFile'");
    exit 1;
  }
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

# Open exported XML file and grab important fields
my $exportedDefect = XMLin($exportedDefectFile, forcearray => ['cxp:streamDefect']);
my $mergedDefect = $exportedDefect->{'cxp:mergedDefect'};

#print Dumper($exportedDefect), "\n";
#print Dumper($mergedDefect), "\n";

$projectName = $exportedDefect->{project};
$cid = $mergedDefect->{cid};

# get exporter's email
my $exportuser = $exportedDefect->{user};
my $userDataObj = $administrationService->getUser(username => $exportuser);
my $exportuserEmail = $userDataObj->{email};


# Do we already have an external reference?
if (!$opt_force) {
  # if an external reference then the key points to a string
  # but if not then it points to an empty hash
  my $er = $mergedDefect->{externalReference};
  if ($er and !ref($er)) {
    if ($er > 0) {
      $log->error("CID $cid already has external reference");
      print "CID $cid already has external reference\n";
      exit 1;
    }
  }
}

# Create a defect summary suitable for export
my $defectSummary = {};
$defectSummary->{status} = $mergedDefect->{status};
$defectSummary->{action} = $mergedDefect->{action};
$defectSummary->{checker} = $mergedDefect->{checker};
$defectSummary->{cid} = $mergedDefect->{cid};
$defectSummary->{classification} = $mergedDefect->{classification};
$defectSummary->{owner} = $mergedDefect->{owner};
$defectSummary->{severity} = $mergedDefect->{severity};


# Retrieve the actual projectDataObj that is being viewed within CIM
my $viewedProjectDataObj;

my @projects = $configurationService->getProjects();
foreach my $project (@projects) {
  if ($project->{id}->{name} eq $projectName) {
    $viewedProjectDataObj = $project;
    last;
  }
}



# query the stream defects to get the file, function, and line number
my @streamDefects = $defectService->getStreamDefects(
    cid => $cid,
    includeDetails => 'true',
    scopePattern => $viewedProjectDataObj->{defaultTriageScope}
  );

# The merged defect may have several fields as "Various".  We need to resolve the owner to a single user.
if ($defectSummary->{owner} eq "Various") {
  foreach (@streamDefects) {
    if (exists($_->{owner})) {
      $defectSummary->{owner} = $_->{owner};
      last;
    }
  }
}

# Another scary gotcha:
# if a defect is a historical one e.g. the file is not present in a recent
# analysis snapshot then there won't be any defectInstances!
my $diref = $streamDefects[0]->{defectInstances};
if ($diref) {
  # The 'defectInstances' key of a given streamDefect will point to an array
  # if there is more than one, or a hash otherwise... yuck
  my $defectInstance;
  if (ref($diref) eq 'HASH') {
    $defectInstance = $diref;
  } elsif (ref($diref) eq 'ARRAY') {
    $defectInstance = @{$diref}[0];
  } else {
    $log->error("Unable to handle $diref (".ref($diref).")");
    die "Unable to handle $diref (".ref($diref).")";
  }

  $defectSummary->{functionDisplayName} = $defectInstance->{function}->{functionDisplayName};
  $defectSummary->{file} = $defectInstance->{function}->{filePathname};

  # The 'events' key of a given defectInstance will point to an array
  # if there is more than one, or a hash otherwise... yuck
  my $event;
  my $evref = $defectInstance->{events};
  if (ref($evref) eq 'HASH') {
    $event = $evref;
  } elsif (ref($evref) eq 'ARRAY') {
    # usually the last event is where the actual defect is
    $event = @{$evref}[-1];
  } else {
    $log->error("Unable to handle $evref (".ref($evref).")");
    die "Unable to handle $evref (".ref($evref).")";
  }

  $defectSummary->{eventTag} = $event->{eventTag};
  $defectSummary->{eventDescription} = $event->{eventDescription};
  $defectSummary->{lineNumber} = $event->{lineNumber};
}


# find and load the correct bts plugin
my $bts;
my @systems = $coverityConfig->get_project_systems($projectName);

foreach my $system (@systems) {
  # use the first matching bts system
  if ($system->{type} eq 'bts') {
    my $plugin = "Coverity::IssueTracking::" . $system->{plugin};
    eval "use $plugin";
    # The system hash has everything the plugin needs so pass it in
    $bts = $plugin->new( %{$system} );

    $defectSummary->{url} = "http://$opt_host:$opt_port/sourcebrowser.htm?projectId=$viewedProjectDataObj->{projectKey}#mergedDefectId=$mergedDefect->{cid}";
  }
}

#print Dumper($bts);
#print Dumper($defectSummary);

my $issueId = $bts->create_issue($defectSummary);
# TODO: add any error checking for issue creation failure here

# Store issue ID in external reference field
if ($issueId) {

  # update each stream CID with some Issue Tracking information
  my $update = 0;
  foreach my $stream (@streamDefects) {
    if (!(defined $stream->{externalReference}) || $stream->{externalReference} eq "") {
      my $updateStreamDefectsResponse = $defectService->updateStreamDefects(
          streamDefectIds => $stream->{id},
          defectStateSpec => {
            externalReference => "$issueId",
            comment => "$exportuser($exportuserEmail): Exported CID $cid as Issue #$issueId"
          }
      );
      print "Updated CID $cid in stream: $stream->{streamId}->{name}\n";
      $update++;
    }
  }
  if (!$update) {
    print "All scoped streams for CID $cid already have External Reference.\n";
  }

  exit 0;
} else {
  $log->error("Issue tracking plugin returned invalid issue ID");
  exit 1;
}

exit 0;
