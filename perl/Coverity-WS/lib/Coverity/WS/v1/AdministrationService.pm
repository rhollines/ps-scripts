# (c) 2010 Coverity, Inc.  All rights reserved worldwide.
#
# $Id$

# See perldoc for external usage info, inline comments are comments on
# the code itself for developers and maintainers.

package Coverity::WS::v1::AdministrationService;

our $VERSION = 0.2;

use strict;

require Exporter;
use Data::Dumper;
use Coverity::WS::v1::Service;

our @ISA = qw(Coverity::WS::v1::Service Exporter);

# Declare service
our $service_name = "administrationservice";
our $service_ns = "http://ws.coverity.com/$Coverity::WS::v1::Service::VERSION_STRING";
our $service_methods = {
  createGroup     => [
     {
       groupSpec => ['pod', 0]
     },
     ['pod', 0]
   ],
  createUser    => [
     {
       userSpec => ['pod', 0]
     },
     ['pod', 0]
   ],
  deleteGroup   => [
     {
       groupId => ['pod', 0]
     },
     ['pod', 0]
   ],
  deleteUser    => [
     {
       username => ['pod', 0]
     },
     ['pod', 0]
   ],
  getAllGroups    => [
     {
       pageSpec => ['pod', 0]
     },
     ['pod', 0, 'groups']
   ],
 getAllRoles   => [
     {
       # No arguments
     },
     ['pod', 1]
   ],
  getAssignableUsers    => [
     {
       pageSpec => ['pod', 0]
     },
     ['pod', 0, 'users']
   ],
  getGroup    => [
     {
       groupId => ['pod', 0]
     },
     ['pod', 0]
   ],
  getUser   => [
     {
       username => ['pod', 0]
     },
     ['pod', 0]
   ],
  getUsersForGroup    => [
     {
       groupId => ['pod', 0]
     },
     ['pod', 1]
   ],
  updateGroup   => [
     {
       groupId => ['pod', 0],
       groupSpec => ['pod', 0]
     },
     ['pod', 0]
   ],
  updateUser => [
     {
       username => ['pod', 0],
       userSpec => ['pod', 0]
     },
     ['pod', 0]
   ]
};

#
# Constants
#

our @EXPORT= ();
our %EXPORT_TAGS = ();

#
# Initialize
#

sub init {
  my $self = shift;
}

1;

__END__

=head1 NAME

Coverity::WS::v1::AdministrationService - Perl interface for the Coverity User Service

=head1 DESCRIPTION

Coverity::WS::v1::AdministrationService provides a Perl native interface for the Coverity Integrity Manager User Service,
as defined in the Coverity Integrity Manager API reference manual.

This class implements wrappers for each AdministrationService complex type.

=head1 SYNOPSIS

The first step is to instantiate the AdministrationService, pointing it at the Coverity Integrity Manager:

  use Coverity::WS::v1::AdministrationService;

  # Create AdministrationService context
  my $defectService = new Coverity::WS::v1::AdministrationService(
    remote => "localhost",
    port => 8080,
    username => "admin",
    password => "coverity"
  );

The constructor method will only fail if invalid or incomplete options are presented.

AdministrationService method calls may now be invoked:

  # Get all users in "Administrators"
  my @users = $userService->getUsersForGroup(
    groupName => "Administrators"
  );

Some methods may require complex data types to be created. These AdministrationService types must be explicitly instantiated:

  my $user = new Coverity::WS::v1::AdministrationService::userSpecDataObj;
  $user->email = "email\@coverity.com";
  $user->familyName = "User";
  $user->givenName = "Joe";
  $user->groupNames = [ $group ];
  $user->password = "test123";
  $user->username = $userName;

  $userService->createUser(userSpec => $user);

The AdministrationService will throw an exception on error, which may be handled using Perl's eval/die mechanism:

  eval {
    $userService->createUser(userSpec => $user);
  };
  if ($@) {
    $logger->error("Unable to create user: $@");
    exit 1;
  }

=head1 AUTHOR

James Croall <jcroall@coverity.com>

(c) 2010 Coverity, Inc.  All rights reserved worldwide.

