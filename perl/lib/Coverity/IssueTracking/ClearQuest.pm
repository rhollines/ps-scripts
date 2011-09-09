package Coverity::IssueTracking::ClearQuest;

# (c) 2011 Coverity, Inc.  All rights reserved worldwide.
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
# my $bts = new Coverity::IssueTracking::ClearQuest( hashmap );
sub new {
  my ($class, %options) = @_;
  my $self = {
    %options
  };

  #print Dumper($self), "\n";

  if (!defined($self->{username}) || !defined($self->{password})) {
    die "Must specify username/password for ClearQuest";
  }

  if (!defined($self->{database})) {
    die "Must specify a Database for ClearQuest";
  }

  #unless (defined($self->{entitytype}) && length($self->{entitytype})) {
  #  die "Must specify ClearQuest entitytype";
  #}

  bless $self, $class;
}


sub replaceFields {
  my ($self, $template, $data) = @_;
  my $var = $template;

  foreach my $field (keys %{$data}) {
    $var =~ s/\%$field\%/$data->{$field}/g;
    $var =~ s/\\n/\n/g;
  }

  return $var;
}


sub create_issue {
  my ($self, $defectSummary) = @_;

  # Fill in necessary issue fields
  while ( my ($key, $field) = each %{$self->{field}} ) {
    my $val = $self->replaceFields($field->{content}, $defectSummary);

    # Truncate fields if necessary
    if (defined($field->{size}) and ($field->{size} >= 0)) {
      $val = sprintf("%.$field->{size}s", $val);
    }

    $field->{content} = $val;
  }

  # Create a temp file and write out the header and description
  use File::Temp qw(tempfile tempdir);
  use XML::Simple;

  my ($fh, $filepath) = tempfile();

  print $fh "$self->{field}->{headline}->{content}";  # assume first line of file
  print $fh "\n";
  print $fh "$self->{field}->{description}->{content}";  # rest of tempfile

  close($fh);

  # Complete command line
  my $cqperl_command .= "/full/path/to/cqperl /full/path/to/create_cq_ticket.pl $self->{username} $self->{password} $self->{database} $filepath";

  # Execute command line
  my $cqperl_output;

  #print "EXEC: $cqperl_command\n";
  my $cmd = new Coverity::Command();

  my $ret_code = $cmd->run($cqperl_command, \$cqperl_output);

  #print "OUTPUT: $cqperl_output\n";

  # delete the tempfile
  unlink($filepath);
  File::Temp::cleanup();

  # Warn if error
  if ($ret_code != 0) {
    $log->warn("command-line returned error code $ret_code: $cqperl_output");
  }

  return $cqperl_output;
}

1;
