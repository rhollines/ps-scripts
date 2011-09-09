#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2010 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

email-notify-owners.pl


=head1 SYNOPSIS

email-notify-owners.pl [options] --project PROJECT


=head1 OPTIONS

=over 12

=item Required:

=item B<--project>

Report on new defects appearing in PROJECT


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

=item B<--days>

within number of DAYS, default 1 (24 hours)

=item B<--dry-run>

Test run, do not send emails

=item B<--help>

Print documentation and exit

=back


=head1 DESCRIPTION

Send an email to defect owners on defect assigned to them in a project within
the last N days.  This script is not designed to operate explicitly on streams.

Emails are sent using the email facilities within CIM.


=head1 CONFIGURATION

This script uses a configuration file (usually coverity_pse_config.xml) for CIM
server information.


=head1 AUTHOR

 Michael White (mwhite@coverity.com)
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

  # Uncommenting this and passing in the filterSpec to the API will speed up
  # the query greatly.  Use with caution.
  #my $filterSpec = {
  #  ownerNameList = 'Unassigned',
  #};

  do {
    $pageSpec->{startIndex} = $i;
    $defectsPage = $defectService->getMergedDefectsForProject(
      projectId => {
        name => $projectName
      },
      # filterSpec => $filterSpec,
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
  my $streamName = shift;

  # getStreamDefects(cid, includeDetails, scopePattern)
  return $defectService->getStreamDefects($cid, 1, "*/$streamName");
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


sub print_timestamp {
  # inputs
  my $sec_since_epoch = shift;  # Unix epoch time (seconds since Jan 1st, 1970)

  print "sec: $sec_since_epoch\n";
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($sec_since_epoch);  # $isdst always 0 for gmtime
  print sprintf("UTC: %4d-%02d-%02dT%02d:%02d:%02d\n", $year+1900,$mon+1,$mday,$hour,$min,$sec);
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

  my ($year,$mon,$mday,$hour,$min,$sec,$tz_plus_minus,$tz_hour,$tz_min) = $str_iso8601 =~ /(\d{4})\-(\d{2})\-(\d{2})T(\d{2})\:(\d{2})\:(\d{2})(\.\d+)?([\+\-])(\d{2})\:(\d{2})/;

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
print "now\n";
print_timestamp($now);

my $cutoff = $now - $opt_days * (24 * 60 * 60);
print "cutoff\n";
print_timestamp($cutoff);

my @defects = getMergedDefectsForProject($defectService, $opt_project);

print "Fetched " . ($#defects+1) . " defects from project $opt_project\n";

# hash of user (string) to list of mergedDefectDOs
my %user_to_defects_hash = ();

foreach my $md (@defects) {
  my @defectChangeDOs = get_md_history($defectService, $md->{cid});
  my $i = @defectChangeDOs - 1;

  my $iso_8601 = $defectChangeDOs[$i]->{dateModified};
  my $sec_since_epoch = parse_timestamp($iso_8601);

  while ($i >= 0 and $sec_since_epoch > $cutoff) {
    if ($defectChangeDOs[$i]->{ownerChange}) {
      my $assigned_owner = $defectChangeDOs[$i]->{ownerChange}->{newValue};

      if (not exists $user_to_defects_hash{$assigned_owner}) {
        $user_to_defects_hash{$assigned_owner} = [];
      }

      # not the most efficient way to determine if something is in an array
      my $found = 0;
      foreach my $c (@{$user_to_defects_hash{$assigned_owner}}) {
        if ($c->{cid} == $md->{cid}) {
          $found = 1;
          last;
        }
      }

      if (!$found) {
        push  @{$user_to_defects_hash{$assigned_owner}}, $md;
      }

      last;  # we found our ownerChange so no need to process more history
    } else {
      $i -= 1;
      if ($i >= 0) {
        $iso_8601 = $defectChangeDOs[$i]->{dateModified};
        $sec_since_epoch = parse_timestamp($iso_8601);
      }
    }
  }
}

if (keys(%user_to_defects_hash) == 0) {
  print "No defects assigned within cutoff to notify about.\n";
  exit(0);
}

my $fromaddr = "noreply+coverity\@coverity.com";
my $subject = "New defects assigned to you in Coverity";


foreach my $u (keys(%user_to_defects_hash)) {
  my $toaddr = get_email($administrationService, $u);

  my $new_defect_count = @{$user_to_defects_hash{$u}};

  if (length($toaddr) == 0) {
    print "Skipping user $u regarding $new_defect_count defect(s) - no email address\n";
    next;
  }

  my $body = "<html><body><p>The following ";

  if ($new_defect_count == 1) {
    $body .= "defect was";
  } else {
    $body .= "$new_defect_count defects were";
  }

  $body .= " assigned to you in project $opt_project within the past ";

  if ($opt_days == 1) {
    $body .= "24 hours.</p>";
  } else {
    $body .= "$opt_days days.</p>";
  }

  $body .= "<br/><table border=\"1\"><tr><th>CID</th><th>Checker</th><th>File</th></tr>";
  foreach my $md (@{$user_to_defects_hash{$u}}) {
    my $url = "http://$opt_host:$opt_port/sourcebrowser.htm?projectId=$projectId#mergedDefectId=$md->{cid}";
    $body .= "<tr><td><a href=\"$url\">$md->{cid}</a></td><td>$md->{checker}</td><td>$md->{filePathname}</td></tr>";
  }

  $body .= "</table></body></html>";


  my $msg = "Subject: $subject\nFrom: $fromaddr\nTo: $toaddr\n\n";
  $msg .= $body;


  if ($u ne "Unassigned") {
    if ($opt_dry_run) {
      #print $msg;
      print "[DRY-RUN] Email sent to user $u at $toaddr regarding $new_defect_count defect(s)\n";
    } else {
      $administrationService->notify(
        usernames => $u, # usernames is an api typo
        subject => $subject,
        message => xml_quote($body)
      );
      print "Email sent to user $u at $toaddr regarding $new_defect_count defect(s)\n";
    }
  } else {
    print "Skipping user $u regarding $new_defect_count defect(s)\n";
  }
}
