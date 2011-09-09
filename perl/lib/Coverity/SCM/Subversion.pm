package Coverity::SCM::Subversion;

# (c) 2010 Coverity, Inc.  All rights reserved worldwide.

# See perldoc for external usage info, inline comments are comments on
# the code itself for developers and maintainers.
#

use strict;

use Data::Dumper;
use Log::Log4perl qw(get_logger);

my $log = get_logger();

use Coverity::Command;


# Constructor.
#
# To initialize directly, call in the following manner:
# my $scm = new Coverity::SCM::Subversion( hashmap );
sub new {
  my ($class, %options) = @_;
  my $self = {
    %options
  };

  #print Dumper($dom), "\n";

  bless $self, $class;
}

sub dump {
  my ($self) = @_;
  print Dumper($self), "\n";
}


sub get_owner {
  my ($self, $filename) = @_;

  # Start building Svn command line
  my $svn_command = "svn praise --non-interactive ";

  # Use authentication?
  if ($self->{username} and $self->{password}) {
    $svn_command .= " --username $self->{username} --password $self->{password} ";
  }

  # Strip source code path
  if ($self->{"strip-path"}) {
    $filename =~ s!$self->{"strip-path"}!!;
  }

  # Complete command line
  $svn_command .= "\"$self->{repository}/$filename\"";

  # Execute subversion command line
  my $ret_code;
  my $svn_output;

  $log->debug("EXEC: $svn_command");
  my $cmd = new Coverity::Command();

  $ret_code = $cmd->run($svn_command, \$svn_output);

  # Warn if SCM error
  if ($ret_code != 0) {
    $log->warn("subversion returned error code $ret_code: $svn_output");
  }

  # Search for highest revision number and return that username
  my @svn_output_lines = split("\n", $svn_output);
  my $line_number = 1;
  my $highest_revision = 0;
  my $owner = "";
  foreach my $line (@svn_output_lines) {
    my ($revision, $username, $line) = ($line =~ /^\s*(\d+)\s+(\w+) (.*)$/);

    # Is this the highest revision
    # TODO: Also look around the line number
    # TODO: Also look for the detes?
    if ($revision > $highest_revision) {
      $owner = $username;
      $highest_revision = $revision;
    }

    $line_number ++;
  }

  return $owner;
}
