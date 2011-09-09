package Coverity::SCM::ClearCase;

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


my $viewroot = `cleartool pwv -root`;
chomp($viewroot);

#print "viewroot: $viewroot\n";


# Constructor.
#
# To initialize directly, call in the following manner:
# my $scm = new Coverity::SCM::ClearCase( hashmap );
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

  # Start building the cleartool command line
  my $ct_command = "cleartool desc -fmt \"%u\" ";

  # Use authentication?
  #if ($self->{username} and $self->{password}) {
    #$ct_command .= " --username $self->{username} --password $self->{password} ";
  #}

  # Strip source code path
  if ($self->{"strip-path"}) {
    $filename =~ s!$self->{"strip-path"}!!;
  }

  # The file path should be located at the VOB root.
  my $filepath = $viewroot.$filename;
  # The Win32 call will convert the lowercase path in CIM to correct casing
  #$filepath = Win32::GetLongPathName($filepath);
  #print "filepath: $filepath\n";

  # Complete command line
  $ct_command .= "\"$filepath\" ";

  # Execute cleartool command line
  my $ct_output;

  $log->debug("EXEC: $ct_command");
  my $cmd = new Coverity::Command();

  my $ret_code = $cmd->run($ct_command, \$ct_output);

  # Warn if SCM error
  if ($ret_code != 0) {
    $log->warn("cleartool returned error code $ret_code: $ct_output");
  }

  return $ct_output;
}
