#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2011 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

update-exported-bug.pl


=head1 SYNOPSIS

update-exported-bug.pl [options] --config configfile.xml --project PROJECT


=head1 OPTIONS

=over 12

=item Required:

=item B<--project>

Report on new defects appearing in PROJECT

=item B<--config>

CONFIG_FILE e.g coverity_pse_config.xml OR

=item Optional:

=item B<--host>

CIM server HOST

=item B<--port>

CIM server PORT

=item B<--username>

CIM server USERNAME with admin access

=item B<--password>

CIM server PASSWORD

=item B<--days>

within number of DAYS, default 1 (24 hours)

=item B<--dry-run>

Test run, do not send emails

=item B<--help>

Print documentation and exit

=back


=head1 DESCRIPTION

Run after a commit, this will update JIRA issues for defects which 
have an ext ref which does not end in X


=head1 CONFIGURATION

This script uses a configuration file (usually coverity_pse_config.xml) for CIM
server information.


=head1 AUTHOR

 Michael White (mwhite@coverity.com)
 Sumio Kiyooka (skiyooka@coverity.com)
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
  push(@INC, "$Bin/../lib-thirdparty");
  push(@INC, "$Bin/../Coverity-WS/lib");
  $Script =~ s/\.pl//g;
};

use Log::Log4perl qw(get_logger :levels);
use Coverity::WS::v2::DefectService qw(:checkerTypes);
use Coverity::WS::v2::ConfigurationService;
use Coverity::WS::v2::AdministrationService;
use Coverity::Config;
use Time::Local;

# Initialize logging
Log::Log4perl->init("$Bin/log.conf");
my $log = get_logger($Script);


##############################################################################
####### Global data and configuration ########################################

my $opt_project;
my $opt_days = 1;

my $opt_host;
my $opt_port;
my $opt_username;
my $opt_password;

my $opt_coverity_config;
my $coverityConfig;

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
    'days=s' => \$opt_days,
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
  pod2usage(-verbose => 1) if (!$opt_project);

  if ($opt_coverity_config) {
    $coverityConfig = new Coverity::Config(filename => $opt_coverity_config);

    # Command-line options override values in config file.
    $opt_host = $opt_host ? $opt_host : $coverityConfig->get_cim_host();
    $opt_port = $opt_port ? $opt_port : $coverityConfig->get_cim_port();
    $opt_username = $opt_username ? $opt_username : $coverityConfig->get_cim_username();
    $opt_password = $opt_password ? $opt_password : $coverityConfig->get_cim_password();
  }

  if (!$opt_host or !$opt_port or !$opt_username or !$opt_password) {
    $log->error("Must specify CIM server and authentication details on command line or configuration file");
    pod2usage(-verbose => 1);
  }
}

sub xml_quote {
  my ($value) = @_;
  $value =~ s/&/&amp;/g;
  $value =~ s/</&lt;/g;
  $value =~ s/>/&gt;/g;
  $value =~ s/"/&quot;/g;
  $value =~ s/'/&apos;/g;
  $value;
}


# This is in a subroutine because it verbose considering we're only retrieving
# a list of merged defects.  This is because of all the required paging.
sub getMergedDefectsForProject {
  # inputs
  my $defectService = shift;
  my $projectName = shift;
  my $fixDate = shift;
  
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

  print Dumper($fixDate);

  # Uncommenting this and passing in the filterSpec to the API will speed up
  # the query greatly.  Use with caution.
  my $filterSpec = {
    lastFixedStartDate => $fixDate
  };

  do {
    $pageSpec->{startIndex} = $i;
    $defectsPage = $defectService->getMergedDefectsForProject(
      projectId => {
        name => $projectName
      },
      filterSpec => $filterSpec,
      pageSpec => $pageSpec
    );
    $i += $PAGE_SIZE;
    if ($defectsPage->{totalNumberOfRecords} > 0) {
      push(@defects, @{$defectsPage->{mergedDefects}});
    }
  } while ($i < $defectsPage->{totalNumberOfRecords});

  return @defects;
}


sub get_md_history {
  # inputs
  my $defectService = shift;
  my $cid = shift;

  # getMergedDefectHistory(cid, scopePattern)
  return $defectService->getMergedDefectHistory(cid => $cid, scopePattern => "*/*");
}


sub getStreamDefects {
  # inputs
  my $defectService = shift;
  my $cid = shift;
  my $projectName = shift;
  
  # getStreamDefects(cid, includeDetails, scopePattern)
  return $defectService->getStreamDefects(cid => $cid,  includeDetails => 1,  scopePattern => "$projectName/*");
}


sub get_email {
  # inputs
  my $administrationService = shift;
  my $username = shift;

  my $userDO = $administrationService->getUser(username => $username);
  if (exists $userDO->{email}) {
    return $userDO->{email};
  } else {
    return "";
  }
}


sub mark_fixed {
	my $defectService = shift;
	my $streamDefect = shift;
	my $extRef = shift;
	
	my $defectStateSpecDataObj = { externalReference => "$extRef X" };
	
	my $sdid = $streamDefect->{id};
	#print Dumper($sdid);
	
	#print "updating $sdid\n";
	
	$defectService->updateStreamDefects(streamDefectIds => $sdid , defectStateSpec =>  $defectStateSpecDataObj );

}

sub print_timestamp {
  # inputs
  my $sec_since_epoch = shift;  # Unix epoch time (seconds since Jan 1st, 1970)

  print "sec: $sec_since_epoch\n";
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($sec_since_epoch);  # $isdst always 0 for gmtime
  print sprintf("UTC: %4d-%02d-%02dT%02d:%02d:%02d\n", $year+1900,$mon+1,$mday,$hour,$min,$sec);
}


sub get_timestamp {
  # inputs
  my $sec_since_epoch = shift;  # Unix epoch time (seconds since Jan 1st, 1970)

  print "sec: $sec_since_epoch\n";
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($sec_since_epoch);  # $isdst always 0 for gmtime
  return sprintf("%4d-%02d-%02dT%02d:%02d:%02d", $year+1900,$mon+1,$mday,$hour,$min,$sec)
}

# An example timestamp that needs to be converted: 2010-08-16T17:00:00-07:00
#                                              or: 2010-08-16T17:00:00.999-07:00
sub parse_timestamp {
  # inputs
  my $str_iso8601 = shift;
  #print "str_iso8601: $str_iso8601\n";

  my $tz_plus_minus;
  my $tz_hour;
  my $tz_min;

  my ($year,$mon,$mday,$hour,$min,$sec,$tz_plus_minus,$tz_hour,$tz_min) = $str_iso8601 =~ /(\d{4})\-(\d{2})\-(\d{2})T(\d{2})\:(\d{2})\:(\d{2})(\.\d+)?([Z\+\-])(\d{2})\:(\d{2})?/;

  $year -= 1900;  # canonicize
  $mon -= 1;  # canonicize

  my $sec_since_epoch = timegm($sec,$min,$hour,$mday,$mon,$year);

  if ($tz_plus_minus eq "+") {
    $sec_since_epoch += ($tz_hour * 60 * 60);
    $sec_since_epoch += ($tz_min * 60);
  } else {
    $sec_since_epoch -= ($tz_hour * 60 * 60);
    $sec_since_epoch -= ($tz_min * 60);
  }

  return $sec_since_epoch;
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


my $projectId;

my @projects = $configurationService->getProjects();
foreach my $project (@projects) {
  if ($project->{id}->{name} eq $opt_project) {
    $projectId = $project->{projectKey};
    last;
  }
}


my $now = time();
print "now: $now\n";
print_timestamp($now);

my $cutoff = $now - $opt_days * (24 * 60 * 60);
print "cutoff\n";
print_timestamp($cutoff);

my @defects = getMergedDefectsForProject($defectService, $opt_project, get_timestamp($cutoff));

print "Fetched " . ($#defects+1) . " defects from project $opt_project\n";

my @new_defects = ();
foreach my $md (@defects) {
  my $iso_8601 = $md->{firstDetected};
  #print "stored value: $iso_8601\n";

  my $sec_since_epoch = parse_timestamp($iso_8601);

  #print "first detected\n";
  #print_timestamp($sec_since_epoch);

  if ($sec_since_epoch > $cutoff) {
    push @new_defects, $md;
  }
}

# hash of user (string) to list of mergedDefectDOs
my %user_to_defects_hash = ();

# get the BTS name for this project..
my @systems = $coverityConfig->get_project_systems($opt_project);
my $bts;

foreach my $system (@systems) {
  # use the first matching bts system
  if ($system->{type} eq 'bts') {
    my $plugin = "Coverity::IssueTracking::" . $system->{plugin};
    eval "use $plugin";
    # The system hash has everything the plugin needs so pass it in
    $bts = $plugin->new( %{$system} );
   }
}

foreach my $md (@defects) {
  #print Dumper($md);
  my @sds = getStreamDefects($defectService, $md->{cid}, $opt_project);
  
  foreach my $sd (@sds) {
    if($sd->{externalReference} ne "") {
		my $extRef =  $sd->{externalReference};
		unless($extRef =~ m/\sX$/) {
			print 'Has a suitable external reference: ' . $extRef . "\n";
			#if ( $bts->fix_issue($extRef) eq "true") {
		#	  mark_fixed($defectService, $sd, $extRef);
		#	}
			
		} else {
			print "Skipping external reference: $extRef\n";
			# already fixed, bypass.
		}
		
	}
  
  }
  
}



