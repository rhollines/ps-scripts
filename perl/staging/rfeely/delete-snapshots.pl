#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2010 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

delete-snapshots.pl


=head1 SYNOPSIS

delete-snapshots.pl [options] --config CONFIG_FILE --stream STREAM 


=head1 OPTIONS

=over 12

=item Required:

Either: 
=item B<--config>

CONFIG_FILE e.g coverity_pse_config.xml

or 

=item B<--host>

CIM server HOST

=item B<--port>

CIM server PORT

=item B<--username>

CIM server USERNAME with admin access

=item B<--password>

CIM server PASSWORD

=item B<--stream>

Stream to delete snapshots from

Either: 
=item B<--days>

within number of DAYS, default 1 (24 hours)

=item B<--date>
Date string of the format M/D/YYYY 

=item Optional:

=item B<--dry-run>

Test run, do not send delete snapshot

=item B<--help>

Print documentation and exit

=back


=head1 DESCRIPTION

Delete snapshots from a stream older than a given number of days or before 
a certain date.

Use the --dry-run flag to test what will be deleted.

=head1 CONFIGURATION

This script uses a configuration file (usually coverity_pse_config.xml) for CIM
server information or the --host,--port,--user,--password optison.


=head1 AUTHOR

  Eric Downing (edowning@coverity.com)

=cut

##############################################################################
####### Initialization #######################################################

use strict;

use Getopt::Long;
use Pod::Usage;
use File::Basename;
use FindBin qw($Bin $Script);
use Data::Dumper;

use Net::SMTP;

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
my $opt_stream;
my $opt_days;
my $opt_date;
my $opt_to;

my $opt_host;
my $opt_port;
my $opt_username;
my $opt_password;

my $opt_coverity_config;
my $coverityConfig;
my $coverityConfigFile;

my $opt_dry_run = 0;
my $opt_help = 0;
my $opt_new_owner=0;
my $opt_summary=0;
my $opt_severity;
my $opt_automatic;

my $projectName;
my $defectSummary;

my $defectService = {};
my $configurationService;
my $administrationService;

my $sec_since_epoch;
##############################################################################
####### Subroutines ##########################################################

sub handle_command_line_options {
  GetOptions(
    # What to operate on
    'stream=s' => \$opt_stream,
    'days=s' => \$opt_days,
    'date=s' => \$opt_date,
    'to=s' => \$opt_to,
    # Standard CIM options
    'host=s' => \$opt_host,
    'port=s' => \$opt_port,
    'username=s' => \$opt_username,
    'password=s' => \$opt_password,
    # Common script options
    'config=s' => \$opt_coverity_config,
    'severity=s' => \$opt_severity,
    'dry-run!' => \$opt_dry_run,
    'help|?' => \$opt_help
  ) or pod2usage(-verbose => 1);
  pod2usage(-verbose => 2) if $opt_help;
  pod2usage(-verbose => 1) if (!$opt_coverity_config);
  pod2usage(-verbose => 1) if (!$opt_stream);

 if ($opt_coverity_config)
 { 
   $coverityConfig = new Coverity::Config(filename => $opt_coverity_config);
  
   # Command-line options override values in config file.
   $opt_host = $opt_host ? $opt_host : $coverityConfig->get_cim_host();
   $opt_port = $opt_port ? $opt_port : $coverityConfig->get_cim_port();
   $opt_username = $opt_username ? $opt_username : $coverityConfig->get_cim_username();
   $opt_password = $opt_password ? $opt_password : $coverityConfig->get_cim_password();

  } 

  if ($opt_date && $opt_days)
  {
    print "Specify only --days or --date\n";
    exit ;
  }
  
  if (!$opt_host or !$opt_port or !$opt_username or !$opt_password) {
    $log->error("Must specify CIM server and authentication details on command line or configuration file");
    pod2usage(-verbose => 1);
  }

}

sub print_timestamp {
  # inputs
  my $sec_since_epoch = shift;  # Unix epoch time (seconds since Jan 1st, 1970)

  print "sec: $sec_since_epoch\n";
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($sec_since_epoch);  # $isdst always 0 for gmtime
  print sprintf("UTC: %4d-%02d-%02dT%02d:%02d:%02d\n", $year+1900,$mon+1,$mday,$hour,$min,$sec);
}

sub create_timestamp {
  my $sec_since_epoch;
 
  my ($month,$day,$year) = split("/",$opt_date); 

  if (!$month || !$day || !$year)
  {
    print "Invalid date string : $opt_date : should be of the form 1/1/2011\n";
    exit
  }

  $sec_since_epoch = timegm(0,0,0,$day,$month,$year);  
  
  return $sec_since_epoch; 
}

# An example timestamp that needs to be converted: 2010-08-16T17:00:00-07:00
#                                              or: 2010-08-16T17:00:00.999-07:00
sub parse_timestamp {
  # inputs
  my $str_iso8601 = shift;

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

my $filterSpec = {
      name => { namePattern =>$opt_stream }
 };

my @snapshots = $configurationService->getSnapshotsForStream(
    streamId => { name => $opt_stream, type => "STATIC"},
    filterSpec => $filterSpec 
   );

my $now = time();
my $cutoff;
print_timestamp($now);

if ($opt_date)
{
  $cutoff = create_timestamp($opt_date);
} elsif ($opt_days || $opt_days == 0)
{
  $cutoff = $now - ($opt_days * ( 24 * 60 * 60));
}
else
{
  print "No date set\n";
}

for my $snapshot (@snapshots)
{
    $sec_since_epoch = parse_timestamp($snapshot->{dateCreated});

 
    if ($sec_since_epoch < $cutoff)
    {
      if ($opt_dry_run == 1 )
      {
       print "DEL: ID: " . $snapshot->{snapshotId}->{id} . " Date: " .  $snapshot->{dateCreated} . "\n";
      }
      else
      {
       print 
       $configurationService->deleteSnapshot(
         snapshotId => { id => $snapshot->{snapshotId}->{id}}
       );
      }
    }
}


