package Coverity::SCM::Perforce;

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

  # Start building p4 command line
  my $p4_command = "p4 -s ";

  # Specify p4 client?
  if ($self->{p4client} and !($self->{p4client} =~ m/^HASH/)) {
    $p4_command .= " -c $self->{p4client} ";
  }
  # Specify p4 port?
  if ($self->{p4port} and !($self->{p4port} =~ m/^HASH/)) {
    $p4_command .= " -p $self->{p4port} ";
  }
  # Use authentication?
  if ($self->{username} and !($self->{username} =~ m/^HASH/) and $self->{password} and !($self->{password} =~ m/^HASH/)) {
    $p4_command .= " -u $self->{username} -P $self->{password} ";
  }

  # Strip source code path
  if ($self->{"strip-path"} and !($self->{"strip-path"} =~ m/^HASH/)) {
    $filename =~ s!$self->{"strip-path"}!!;
  }

  # Add depot path
  if ($self->{repository} and !($self->{repository} =~ m/^HASH/)) {
    $filename = $self->{repository} . $filename;
  }

  # The Win32 call will convert the lowercase path in CIM to correct casing
  $filename = Win32::GetLongPathName($filename);

  # Complete command line
  $p4_command .= " filelog -i -m 5 \"$filename\" ";
  #print "EXEC: $p4_command\n";

  # Execute Perforce command line
  my $ret_code;
  my $p4_output;
  my $cmd = new Coverity::Command();

  $ret_code = $cmd->run($p4_command, \$p4_output);

  # Warn if SCM error
  if ($ret_code != 0) {
    $log->warn("p4 returned error code $ret_code: $p4_output");
  }

  my $owner = parse_output_for_owner($p4_output);
  return $owner;
}

sub parse_output_for_owner {
  my $output = shift;
  my $owner = "Unknown";
  my @lines = split(/\n/, $output);
  my $change_userid = ""; 
  my $edit_userid = "";
  my $line;
  # Determine most recent person to change the file, note if the change is an edit
  while (!$change_userid and scalar(@lines)) {
    $line = shift (@lines);
    if ($line =~ /^info\d: #/) {
      $change_userid = $line;
    }
    if ($line =~ /edit on \d{4}\/\d{1,2}\/\d{1,2} by/) {
      $edit_userid = $line;
    }
  }
  # If most recent change is not an edit, search for the most recent edit
  if (!$edit_userid) {
    foreach (@lines) {
      if (/edit on \d{4}\/\d{1,2}\/\d{1,2} by/) {
        $edit_userid = $_;
        last;
      } else {
        next;
      }
    }
  }
  if ($edit_userid) {
    $owner = $edit_userid;
  } elsif ($change_userid) {
    $owner = $change_userid;
  }
  $owner =~ s/.* \d{4}\/\d{1,2}\/\d{1,2} by //;
  $owner =~ s/@.*//;
  return $owner;
}

