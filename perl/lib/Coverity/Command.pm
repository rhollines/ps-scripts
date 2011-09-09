package Coverity::Command;
# (c) 2008 Coverity, Inc.  All rights reserved worldwide.
#
# $Id: Command.pm,v 1.9 2009/05/15 17:52:40 jcroall Exp $

# See perldoc for external usage info, inline comments are comments on
# the code itself for developers and maintainers.

# Matthew Hayward mhayward@coverity.com

use strict;

# Replace with the path to the Coverity lib directory on your system.
BEGIN {
  push(@INC, "/home/coverity/lib");
}


sub new {
  my $type = shift;
  my $class = ref($type) || $type;

  my %param = @_;
  my $self = bless {}, $class;

  if (exists($param{logger}) and $param{logger}) {
    $self->{logger} = $param{logger};
  } else {
    $self->{logger} = 0;
  }

  return $self;
}

# Run a shell command
sub run {
  my $self = shift;
  my $cmd = shift;
  my $output = shift;
  my $tee = shift;

  my $cmd_out = "";

  if (defined($output) and !ref($output)) {
    die "ERROR: If you provide a second parameter to the run() method defining where the output of the command is to be stored, this parameter must be a reference";
  }

  my $log = $self->{logger};

  my $msg = "Running: $cmd\n";
  if ($log) {
    $log->log_message("LOG",$msg);
  }
  my $now = time();

  # Execute command
  my $buffer_size = 1024;
  my $buffer;

  if ($log) {
    $log->log_message("LOG", "DEBUG: executing command '$cmd'");
  }

  $| = 1;
  open(COMMAND, "$cmd |") or die("unable to open pipe $cmd: $!");
  while (sysread(COMMAND, $buffer, $buffer_size) > 0) {
    # Save memory -- only collect output if asked for it!
    if (defined($output)) {
      $cmd_out .= $buffer;
    }

    # Optionally print to STDOUT
    if (defined($tee) and $tee) {
      print $buffer;
    }
  }
  close(COMMAND);
  $| = 0;

  if (defined($output)) {
    $$output = $cmd_out;
  }
  my $secs = time() - $now;
  $msg = "Command took $secs seconds.\nOutput was:\n$cmd_out\n";
  if ($log) {
    $log->log_message("VERBOSE",$msg);
  }
  return ($? >> 8);
}

return 1;

__END__

=head1 DESCRIPTION

Command.pm - Simple shell command runner for Coverity scripts,
provides some housekeeping over inlined system() calls.

=head1 AUTHOR

Matthew Hayward

(c) 2008 Coverity, Inc.  All rights reserved worldwide.

=head1 SYNOPSIS

Create a Command object, run some commands:

 my $cmd = new Coverity::Command(logger=>$logger);
 my $dirlist;
 my $retval = $cmd->run("ls -l .",\$dirlist);

Here $dirlist is a reference output parameter which will store the
output of the command, and the return code is the OS return value of
the command.

=head1 DETAILS

=head2 Constructor

The constructor takes one arguments:

=over 2

=item logger - If provided, must be an object that provides a log_message method accepting positional text parameters reflecting:

=over 4

=item * 
severity

=item * 
messages

=back

For instance:
 
 $logger->log_message("WARNING","The return value was ", $rv, " which is bad!");

See Coverity::Logger for a sample class that meets these criteria.

=back

=head2 Methods

=over 2

=item run($command, $output, {$tee});

The run method takes in $command and runs it.

The optional $output parameter is a reference parameter.  The run()
method will store the output of the command in the dereference of
$output if it is provided and a reference.

If the optional $tee parameter is true, output from the command will
also be output to STDOUT.

If the Command object's logger member was set during construction, the
log_message method will be called on that logging object.

=back

=head2 Return Values

The output of the command will be stored in the dereference of the
reference $output parameter provided to run().

The return code of the command will be returned.

=head2 Error Handling

Because this method can not know if an external user intends for
commands to fail or not, no attempt is made at error handling, with
the exception of failing when the $output parameter to run() is not
defined and a reference.

If a logger is provided during construction that does not have a
log_message method undefined behavior can result.

The log_message method is always called with an LOG level of warning, as
Coverity::Command doesn't know what the user intends.

Because some commands could fail, robust programs should wrap calls to
run() within an eval block.

