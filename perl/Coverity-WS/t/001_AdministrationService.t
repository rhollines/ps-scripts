# (c) 2010 Coverity, Inc.  All rights reserved worldwide.
# 
# $Id: 001_AttributeService.t,v 1.1 2010/04/04 22:20:51 jcroall Exp $

use Test::More qw(no_plan);
use FindBin qw($Bin);
use File::Spec;
use Storable;
use Data::Dumper;
use Getopt::Long;
use File::Temp;
use File::Basename qw(basename);

use strict;

BEGIN {
  push(@INC, "$Bin/../lib");
  push(@INC, "$Bin");
}

use Test::Exception;

diag("Begin testing AdministrationService");

use TestConfig;

BEGIN { use_ok('Coverity::WS::v1::AdministrationService') }

# Create service context
my $administrationService = new Coverity::WS::v1::AdministrationService(
  remote => $remote,
  port => $port,
  username => $username,
  password => $password,
  ssl => $ssl
);

# 1. Create a Group and User
my $groupName = "testgroup$$";
my $userName = "testuser$$";

lives_ok {
  $administrationService->createGroup(
    groupSpec => {
      id => {
        name => $groupName
      },
      local => "true",
      nightRefresh => "false",
      roles => [
        {
          name => "ROLE_SYS_ADMIN"
        }
      ]
    }
  );
} "AdministrationService::createGroup";

lives_ok {
  $administrationService->createUser(
    userSpec => {
      disabled => "false",
      email => "user\@coverity.com",
      familyName => "Master",
      givenName => "Build",
      groupNames => [
        {
          name => $groupName
        }
      ],
      locked => "false",
      password => "c0v5rulZ",
      username => $userName
    }
  );
} "AdministrationService::createUser";

# 2. Get groups and users and make sure our newbies are there

my $i;
my $pageSpec = {
  pageSize => 1,
  sortAscending => "true",
  startIndex => 0
};

my $groupsPage;
my @groups;

$i = 0;
do {
  $pageSpec->{startIndex} = $i;
  $groupsPage = $administrationService->getAllGroups(
    pageSpec => $pageSpec
  );
  $i += 1;
  push(@groups, @{$groupsPage->{groups}});
} while ($i < $groupsPage->{totalNumberOfRecords});

my $groupFound = 0;
foreach my $group (@groups) {
  if ($group->{name}->{name} eq $groupName) {
    $groupFound = 1;
  }
}
ok($groupFound, "Group $groupName found");

my $group;

lives_ok {
  $group = $administrationService->getGroup(
    groupId => {
      name => $groupName
    }
  );
} "AdministrationService::getGroup";

ok($group->{name}->{name} eq $groupName, "Group $groupName found");

my $usersPage;
my @users;

$i = 0;
do {
  $pageSpec->{startIndex} = $i;
  $usersPage =  $administrationService->getAssignableUsers(
    pageSpec => $pageSpec
  );
  $i += 1;
  push(@users, @{$usersPage->{users}});
} while ($i < $usersPage->{totalNumberOfRecords});

my $userFound = 0;
foreach my $user (@users) {
  if ($user->{username} eq $userName) {
    $userFound = 1;
  }
}
ok($userFound, "User $userName found");

my $user;

lives_ok {
  $user = $administrationService->getUser(
    username => $userName
  );
} "AdministrationService::getUser";

ok($user->{username} eq $userName, "User $userName found");

lives_ok {
   @users = $administrationService->getUsersForGroup(
     groupId => {
       name => $groupName
     }
  );
} "AdministrationService::getUsersForGroup";

$userFound = 0;
foreach my $user (@users) {
  if ($user->{username} eq $userName) {
    $userFound = 1;
  }
}
ok($userFound, "User $userName found");

my @roles;
lives_ok {
   @roles = $administrationService->getAllRoles();
} "AdministrationService::getAllRoles";

lives_ok {
  $administrationService->updateGroup(
    groupId => {
      name => $groupName
    },
    groupSpec => {
      id => {
        name => "$groupName-renamed"
      },
      local => "true",
      nightRefresh => "false",
      roles => [
        {
          name => "ROLE_PROJECT_CONFIG"
        }
      ]
    }
  );
} "AdministrationService::updateGroup";

lives_ok {
  $administrationService->updateUser(
    username => $userName,
    userSpec => {
      disabled => "false",
      email => "newemail\@coverity.com",
      familyName => "Master",
      givenName => "Build",
      groupNames => [
        {
          name => "Users"
        }
      ],
      locked => "false",
      password => "cov5rulZ",
      username => "$userName"
    }
  );
} "AdministrationService::updateUser";

#
# Clean up our mess
#

lives_ok {
  $administrationService->deleteUser(
    username => $userName,
  );
} "AdministrationService::deleteUser";

lives_ok {
  $administrationService->deleteGroup(
    groupId => {
      name => $groupName
    }
  );
} "AdministrationService::deleteUser";




diag("End of tests");
