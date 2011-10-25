#! /usr/bin/perl

use strict;

#Load the services - usually Configuration and Defect.  This imports constant types (streamTypes and checkerTypes) so that they won't need to be explicitly referenced.

#Set up finding the modules necessary

use FindBin qw($Bin $Script);

BEGIN {
  push(@INC, "$Bin/../../Coverity-WS-0.3.3/lib/");
  push(@INC, "$Bin/../../ps-scripts-5.3/lib-thirdparty/");
  $Script =~ s/\.pl//g;
}

use Coverity::WS::v2::ConfigurationService;
use Coverity::WS::v2::AdministrationService;
use Coverity::WS::v2::DefectService qw(:checkerTypes);


# Tell the services where to find our CIM instance
my $host = "localhost";
my $port = 8084;
my $user = "admin";
my $password = "welcome";


# Create the ConfigurationService context
my $configService = new Coverity::WS::v2::ConfigurationService(
	host => $host,
	port => $port,
	username => $user,
	password => $password
);

# Create the AdministrativeService Context
my $adminService = new Coverity::WS::v2::AdministrationService(
	host=> $host,
	port => $port,
	username => $user,
	password => $password
);

# Create the DefectService context
my $defectService = new Coverity::WS::v2::DefectService(
	host => $host,
	port => $port,
	username => $user,
	password => $password
);

#  Add a local user

my $myname = "LukeSkywalker";
my $pw = "MTFBWY";
my $local = 'true';
my $email = "luke@rebelalllience.org";

my $userSpec = {
	username => $myname,
	password => $pw,
	local => $local,
	email => $email
};

 $adminService ->createUser(userSpec=>$userSpec);



