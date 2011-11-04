#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2011 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

minimal.pl


=head1 SYNOPSIS

minimal.pl [options] --project PROJECT


=head1 OPTIONS

=over 12

=item Required:

=item B<--project>

Fetch one page of defects appearing in PROJECT

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

Fetch one page of defects in a given project.  This demonstrates minimal perl dependencies.


=head1 AUTHOR

Sumio Kiyooka (skiyooka@coverity.com)

=cut

##############################################################################
####### Initialization #######################################################

use strict;

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

#use SOAP::Lite +trace => 'debug';
use SOAP::Lite;

##############################################################################
####### Global data and configuration ########################################

my $opt_project;

my $opt_host;
my $opt_port;
my $opt_username;
my $opt_password;

my $opt_help = 0;

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
    'help|?' => \$opt_help
  ) or pod2usage(-verbose => 1);
  pod2usage(-verbose => 2) if $opt_help;
  pod2usage(-verbose => 1) if (!$opt_project);

  if (!$opt_host or !$opt_port or !$opt_username or !$opt_password) {
    print "Must specify CIM server and authentication details\n";
    pod2usage(-verbose => 1);
  }
}


sub ws_authen_text {
  my($username,$password) = @_;

  my $auth = SOAP::Header->new('name' => 'wsse:Security');
  $auth->attr({'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'});
  $auth->mustUnderstand(1);

  $auth->value(
    \SOAP::Data->value(
      SOAP::Data->name('wsse:UsernameToken' => \SOAP::Data->value(
        SOAP::Data->name('wsse:Username' => $username),
        SOAP::Data->name('wsse:Password' => $password)
      ))
    ));

  $auth;
}

##############################################################################
######## Main Script #########################################################

handle_command_line_options();

my $proxy = SOAP::Lite->proxy("http://$opt_host:$opt_port/ws/v4/defectservice")->uri('http://ws.coverity.com/v4');
$proxy->serializer()->register_ns('http://ws.coverity.com/v4', 'ws');

my $soap_param =
 SOAP::Data->value(
   SOAP::Data->name('projectId' => \SOAP::Data->value(
     SOAP::Data->name('name' => $opt_project)
   )),
   SOAP::Data->name('pageSpec' => \SOAP::Data->value(
     SOAP::Data->name('pageSize' => '100'),
     SOAP::Data->name('sortAscending' => 'true'),
     SOAP::Data->name('startIndex' => '0')
   ))
 );

my $som = $proxy->call(
  SOAP::Data->name("ws:getMergedDefectsForProject") => $soap_param,
  ws_authen_text($opt_username, $opt_password)
);

if ($som->fault()) {
  print Dumper($som->fault()->{'detail'}->{'CoverityFault'});
} else {
  # Returns all parameters from a SOAP response, including the result entity itself, as one array.
  print Dumper($som->paramsall);
}
