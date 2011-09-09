#!/usr/bin/perl

package Coverity::Config;

# This class handles the reading of the coverity config file and also provides
# some enscapulation for the project/stream and system mappings.

use strict;

use Carp;
use XML::Simple;
use Data::Dumper;
use Log::Log4perl qw(get_logger);

my $log = get_logger();
my $dom = {};

# Constructor.
#
# To initialize, call in the following manner:
# my $config = new Coverity::Config(filename => 'coverity_pse_config.xml');
sub new {
  my ($class, %options) = @_;
  my $self = {
    %options
  };

  $dom = XMLin($self->{filename},
    ForceArray => ['map', 'id', 'system'],
    KeyAttr => ['id'],
    KeepRoot => 0,
    # ignore empty elements
    SuppressEmpty => 1
  );

  #print Dumper($dom), "\n";

  bless $self, $class;
}

sub get_cim_host { return $dom->{cim}->{host}; }
sub get_cim_port { return $dom->{cim}->{port}; }
sub get_cim_username { return $dom->{cim}->{username}; }
sub get_cim_password { return $dom->{cim}->{password}; }


# Returns system that matches given id
#
# Call this subroutine in the following manner:
# $system_hash = $config->get_system('id');
#
# returns a hash of the xml data of the matching system
sub get_system {
  my ($self, $id) = @_;
  if (!$id or length $id == 0) {
    croak "Config.get_system(): You must specify a system id";
  }

  # this hash does not have the id element
  my $system_hash = $dom->{systems}->{'system'}->{$id};

  #print Dumper($system_hash), "\n";
  return $system_hash;
}


# Returns systems that are mapped to the given project.
#
# Call this subroutine in the following manner:
# my @systems = $config->get_project_systems('CIM_PROJECT');
#
# returns an array of hashes, 1 for each matching system
sub get_project_systems {
  my ($self, $project) = @_;
  if (!$project or length $project == 0) {
    croak "Config.get_project_systems(): You must specify a CIM project name";
  }

  my $mappings = $dom->{'project-mappings'}->{'map'};
  foreach my $mapping (@{$mappings}) {
    if ($project =~ $mapping->{pattern}) {
      # we found a match, return all systems listed for this project
      my @systems;  # matching systems
      foreach my $id (@{$mapping->{systems}->{id}}) {
        my $system_hash = get_system($self, $id);
        if ($system_hash) {
          push @systems, $system_hash;
        } else {
          $log->warn("no system found for id: $id");
        }
      }
      return @systems;
    }
  }

  $log->warn("no mapping found for project: $project");
  return ();
}


# Returns systems that are mapped to the given stream.
#
# Call this subroutine in the following manner:
# my @systems = $config->get_stream_systems('CIM_STREAM');
#
# returns an array of hashes, 1 for each matching system
sub get_stream_systems {
  my ($self, $stream) = @_;
  if (!$stream or length $stream == 0) {
    croak "Config.get_stream_systems(): You must specify a CIM stream name";
  }

  my $mappings = $dom->{'stream-mappings'}->{'map'};
  foreach my $mapping (@{$mappings}) {
    if ($stream =~ $mapping->{pattern}) {
      # we found a match, return all systems listed for this stream
      my @systems;  # matching systems
      foreach my $id (@{$mapping->{systems}->{id}}) {
        my $system_hash = get_system($self, $id);
        if ($system_hash) {
          push @systems, $system_hash;
        } else {
          $log->warn("no system found for id: $id");
        }
      }
      return @systems;
    }
  }

  $log->warn("no mapping found for stream: $stream");
  return ();
}


sub dump {
  my ($self) = @_;
  print Dumper($self), "\n";
  print Dumper($dom), "\n";
}
