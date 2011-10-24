#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2011 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

sync-triage-in-project.pl


=head1 SYNOPSIS

sync-triage-in-project.pl [options] --config CONFIG_FILE --project PROJECT


=head1 OPTIONS

=over 12

=item Required:

=item B<--config>

CONFIG_FILE e.g coverity_pse_config.xml

=item B<--project>

Synchronize triage by applying triage from triaged to untriaged defects of the
same PROJECT's triage scope if the result is consistent.

=item Optional:

=item B<--host>

CIM server HOST

=item B<--port>

CIM server PORT

=item B<--username>

CIM server USERNAME with admin access

=item B<--password>

CIM server PASSWORD

=item B<--dry-run>

Test run, do not update defects

=item B<--help>

Print documentation and exit

=back


=head1 DESCRIPTION

Often, a defect occurs in many streams of a project's triage scope.  This
defect might be triaged in some but not all streams and you'll see the dreaded
'Various' state.

It is desired that the defect be triaged the same in all streams.  This script
will do so if the result is consistent i.e. from the triaged defects it can
determine a consistent triage that can be applied to all stream defects.


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
  push(@INC, "$Bin/../lib");
  push(@INC, "$Bin/../lib-thirdparty");
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
    # Standard CIM options
    'host=s' => \$opt_host,
    'port=s' => \$opt_port,
    'username=s' => \$opt_username,
    'password=s' => \$opt_password,
    # Common script options
    'config=s' => \$opt_coverity_config,
    'dry-run!' => \$opt_dry_run,
    'help|?' => \$opt_help
  ) or pod2usage(-verbose => 1);
  pod2usage(-verbose => 2) if $opt_help;
  pod2usage(-verbose => 1) if (!$opt_coverity_config);
  pod2usage(-verbose => 1) if (!$opt_project);

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
sub getMergedDefectsForProject {
  # inputs
  my $defectService = shift;
  my $projectName = shift;

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
    $defectsPage = $defectService->getMergedDefectsForProject(
      projectId => {
        name => $projectName
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


my @projects = $configurationService->getProjects( filterSpec => { namePattern => $opt_project } );
my $project = @projects[0];
my $defaultTriageScope = $project->{'defaultTriageScope'};

my $longestStreamNameLen = 0;
foreach my $stream ( @{$project->{'streams'}} ) {
  my $len = length($stream->{'id'}->{'name'});
  if ($len > $longestStreamNameLen) {
    $longestStreamNameLen = $len;
  }
}

my @mergedDefects = getMergedDefectsForProject($defectService, $opt_project);

foreach my $md (@mergedDefects) {
  print "CID $md->{cid}  $md->{checker}\n";

  #print Dumper($md);

  my @streamDefects = $defectService->getStreamDefects(
    cid => $md->{'cid'},
    includeDetails => 'false',
    scopePattern => $defaultTriageScope
  );

  my $template_classification;
  my $template_severity;
  my $template_action;
  my $template_owner;
  my $template_externalReference;
  my $consistent = 1;

  foreach my $sd (@streamDefects) {
    #printf("  %-" . $longestStreamNameLen . "s", $sd->{'streamId'}->{'name'});
    #print "  $sd->{'classification'}" .
    #      "  $sd->{'severity'}" .
    #      "  $sd->{'action'}" .
    #      "  $sd->{'owner'}" .
    #      "  $sd->{'externalReference'}" .
    #      "\n";

    if ($consistent && $sd->{'classification'} ne 'Unclassified') {
      if ($template_classification && $template_classification ne $sd->{'classification'}) {
        print "  Classifications ($template_classification, $sd->{'classification'}) not consistent, skipping\n";
        $consistent = 0;
      } else {
        $template_classification = $sd->{'classification'};
      }
    }

    if ($consistent && $sd->{'severity'} ne 'Unspecified') {
      if ($template_severity && $template_severity ne $sd->{'severity'}) {
        print "  Severities ($template_severity, $sd->{'severity'}) not consistent, skipping\n";
        $consistent = 0;
      } else {
        $template_severity = $sd->{'severity'};
      }
    }

    if ($consistent && $sd->{'action'} ne 'Undecided') {
      if ($template_action && $template_action ne $sd->{'action'}) {
        print "  Actions ($template_action, $sd->{'action'}) not consistent, skipping\n";
        $consistent = 0;
      } else {
        $template_action = $sd->{'action'};
      }
    }

    if ($consistent && $sd->{'owner'} && length($sd->{'owner'}) > 0) {
      if ($template_owner && $template_owner ne $sd->{'owner'}) {
        print "  Owners ($template_owner, $sd->{'owner'}) not consistent, skipping\n";
        $consistent = 0;
      } else {
        $template_owner = $sd->{'owner'};
      }
    }

    if ($consistent && $sd->{'externalReference'} && length($sd->{'externalReference'}) > 0) {
      if ($template_externalReference && $template_externalReference ne $sd->{'externalReference'}) {
        print "  External references ($template_externalReference, $sd->{'externalReference'}) not consistent, skipping\n";
        $consistent = 0;
      } else {
        $template_externalReference = $sd->{'externalReference'};
      }
    }
  }

  if ($consistent && ($template_classification ||
                      $template_severity ||
                      $template_action ||
                      $template_owner ||
                      $template_externalReference)) {

    my $defectStateSpec = {};

    if ($template_classification) { $defectStateSpec->{'classification'} = $template_classification; }
    if ($template_severity) { $defectStateSpec->{'severity'} = $template_severity; }
    if ($template_action) { $defectStateSpec->{'action'} = $template_action; }
    if ($template_owner) { $defectStateSpec->{'owner'} = $template_owner; }
    if ($template_externalReference) { $defectStateSpec->{'externalReference'} = $template_externalReference; }

    # determine who needs triage (i.e. difference from the template)

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
    foreach my $sd (@streamDefects) {
      if (
          ($template_classification && $template_classification ne $sd->{'classification'}) ||
          ($template_severity && $template_severity ne $sd->{'severity'}) ||
          ($template_action && $template_action ne $sd->{'action'}) ||
          ($template_owner && $template_owner ne $sd->{'owner'}) ||
          ($template_externalReference && $template_externalReference ne $sd->{'externalReference'})) {
        push(@streamDefectIds, $sd->{id});

        foreach my $key (keys %{$defectStateSpec}) {
          if ($defectStateSpec->{$key} ne $sd->{$key}) {
            print "  ";
            if ($opt_dry_run) {
              print "[DRY-RUN] ";
            } else {
            }
            print "Updated (";
            printf("%-" . $longestStreamNameLen . "s", $sd->{'streamId'}->{'name'});
            print ") $key: $sd->{$key} -> $defectStateSpec->{$key}\n";
          }
        }
      }
    }

    $defectStateSpec->{'comment'} = 'Updated by sync-triage-in-project.pl';

    # apply it and print message
    if (!$opt_dry_run) {
      eval {
        $defectService->updateStreamDefects(
          streamDefectIds => \@streamDefectIds,
          defectStateSpec => $defectStateSpec
        );
      };
      if ($@) {
        $log->warn("Error updating stream defect: $@");
      }
    }
  }
}

