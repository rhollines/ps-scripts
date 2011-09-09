package Coverity::SCM::Accurev;

# (c) 2010 Coverity, Inc.  All rights reserved worldwide.
#

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
# my $scm = new Coverity::SCM::Accurev( hashmap );
sub new {
  my ($class, %options) = @_;
  my $self = {
    %options
  };

  #print Dumper($self), "\n";

  bless $self, $class;
}


sub dump {
  my ($self) = @_;
  print Dumper($self), "\n";
}


sub login {
  # TODO: not wired in--either login each lookup or once at the beginning
  my ($user) = $ENV{USER};
  my ($password) = `sed -n 's/^\\\\set password=//p' $ENV{HOME}/.sqshrc`;
  my ($command) = `accurev login -n $user $password`;
}


sub get_owner {
  my ($self, $filename) = @_;

  # Start building the accurev command line

  # Strip source code path
  if ($self->{"strip-path"}) {
    $filename =~ s!$self->{"strip-path"}!!;
  }

  my $accurev_command = "pushd $self->{basedir}; accurev hist -t now.1 $self->{basedir}/$filename; popd";

  # Execute accurev command line
  my $accurev_output;

  $log->debug("EXEC: $accurev_command");
  my $cmd = new Coverity::Command();

  my $ret_code = $cmd->run($accurev_command, \$accurev_output);

  # Warn if SCM error
  if ($ret_code != 0) {
    $log->warn("accurev returned error code $ret_code: $accurev_output");
  }

  # Search for highest revision number and return that username
  my @accurev_output_lines = split("\n", $accurev_output);
  my $line_number = 1;
  my $highest_revision = 0;
  my $owner = "";
  foreach my $line (@accurev_output_lines) {
    ($owner) = ($line =~ /^.+ user: (\w+)/);

    #print "$line\n$owner\n";
    if ($owner) {
      last;
    }
  }

  return $owner;
}
