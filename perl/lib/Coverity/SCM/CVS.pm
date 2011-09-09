package Coverity::SCM::CVS;

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
# my $scm = new Coverity::SCM::CVS( hashmap );
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


sub get_owner {
  my ($self, $filename) = @_;

  # Start building cvs command line
  my $cvs_command = "cvs log ";

  # Use authentication?
  #if ($self->{username} and $self->{password}) {
    #$cvs_command .= " --username $self->{username} --password $self->{password} ";
  #}

  # Strip source code path
  if ($self->{"strip-path"}) {
    $filename =~ s!$self->{"strip-path"}!!;
  }

  # Complete command line
  $cvs_command .= "$filename";

  # Execute cvs command line
  my $ret_code;
  my $cvs_output;

  $log->debug("EXEC: $cvs_command");
  my $cmd = new Coverity::Command();

  $ret_code = $cmd->run($cvs_command, \$cvs_output);

  # Warn if SCM error
  if ($ret_code != 0) {
    $log->warn("cvs returned error code $ret_code: $cvs_output");
  }

  my @cvs_output_lines = split("\n", $cvs_output);
  my $owner = "";
  foreach my $line (@cvs_output_lines) {

    # cvs output looks similar to:
    # ----------------------------
    # revision 1.5
    # date: 2006/10/09 23:18:13;  author: dhsscan;  state: Exp;  lines: +1 -2

    my ($owner) = ($line =~ /^date:.*author: ([^;]+);.*$/);
    if ($owner) {
      return $owner;
    }
  }

  return $owner;
}
