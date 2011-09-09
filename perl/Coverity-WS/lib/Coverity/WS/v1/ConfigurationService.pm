# (c) 2010 Coverity, Inc.  All rights reserved worldwide.
#
# $Id: ConfigurationService.pm,v 1.1 2010/04/04 22:20:51 jcroall Exp $

# See perldoc for external usage info, inline comments are comments on
# the code itself for developers and maintainers.

package Coverity::WS::v1::ConfigurationService;

$VERSION = 0.2;

use strict;

require Exporter;
use Data::Dumper;
use Coverity::WS::v1::Service;

our @ISA = qw(Coverity::WS::v1::Service Exporter);

# Declare service
our $service_name = "configurationservice";
our $service_ns = "http://ws.coverity.com/$Coverity::WS::v1::Service::VERSION_STRING";
our $service_methods = {
  createProject => [
    {
      projectSpec => ['pod', 0]
    },
    ['pod', 0]
  ],
  createStream => [
    {
      streamSpec => ['pod', 0]
    },
    ['pod', 0]
  ],
  deleteProject => [
    {
      projectId => ['pod', 0]
    },
    ['pod', 0]
  ],
  deleteStream => [
    {
      streamId => ['pod', 0]
    },
    ['pod', 0]
  ],
  getActions => [
    {
      # None
    },
    ['pod', 1]
  ],
  getClassifications => [
    {
      # None
    },
    ['pod', 1]
  ],
  getDefectStatuses => [
    {
      # None
    },
    ['pod', 1]
  ],
  getProjects => [
    {
      filterSpec => ['pod', 0]
    },
    ['pod', 1]
  ],
  getSeverities => [
    {
      # None
    },
    ['pod', 1]
  ],
  getStreams => [
    {
      filterSpec => ['pod', 0]
    },
    ['pod', 1]
  ],
  updateActions => [
    {
      actions => ['pod', 0]
    },
    ['pod', 0]
  ],
  updateProject => [
    {
      projectId => ['pod', 0],
      projectSpec => ['pod', 0]
    },
    ['pod', 0]
  ],
  updateSeverities => [
    {
      severities => ['pod', 0]
    },
    ['pod', 0]
  ],
  updateStream => [
    {
      streamId => ['pod', 0],
      streamSpec => ['pod', 0]
    },
    ['pod', 0]
  ]
};

#
# Constants
#

# Stream types
use constant SOURCE   => "SOURCE";
use constant STATIC   => "STATIC";
use constant DYNAMIC  => "DYNAMIC";

# Languages
use constant CXX      => "CXX";
use constant CSHARP   => "CSHARP";
use constant JAVA     => "JAVA";

our @EXPORT= (SOURCE, STATIC, DYNAMIC, CXX, CSHARP, JAVA);
our %EXPORT_TAGS = (
  streamTypes => [ SOURCE, STATIC, DYNAMIC ],
  languages => [CXX, CSHARP, JAVA]
);

#
# Initialize
#

sub init {
  my $self = shift;
}

1;

__END__

=head1 NAME

Coverity::WS::v1::ConfigurationService - Perl interface for the Coverity Project Service

=head1 DESCRIPTION

Coverity::WS::v1::ConfigurationService provides a Perl native interface for the Coverity Integrity Manager Project Service,
as defined in the Coverity Integrity Manager API reference manual.

This class implements wrappers for each ConfigurationService complex type.

=head1 SYNOPSIS

The first step is to instantiate the ConfigurationService, pointing it at the Coverity Integrity Manager:

  use Coverity::WS::v1::ConfigurationService qw(:streamTypes :languages);

  # Create ConfigurationService context
  my $defectService = new Coverity::WS::v1::ConfigurationService(
    remote => "localhost",
    port => 8080,
    username => "admin",
    password => "coverity"
  );

The constructor method will only fail if invalid or incomplete options are presented.

ConfigurationService method calls may now be invoked:

  # Get project details for "Demo
  my $project = $defectService->getProject(
    name => "Demo"
  );

Some methods may require complex data types to be created. These ConfigurationService types must be explicitly instantiated:

  # Create streams
  my $code_stream = new Coverity::WS::v1::ConfigurationService::streamSpecDataObj;
  $code_stream->description = "Source code stream";
  $code_stream->language = CXX;
  $code_stream->name = "Demo";
  $code_stream->type = SOURCE;

  $projectService->createStream(streamSpec => $code_stream); }

The ConfigurationService will throw an exception on error, which may be handled using Perl's eval/die mechanism:

  eval {
    $projectService->createStream(streamSpec => $code_stream); }
  };
  if ($@) {
    $logger->error("Unable to create stream: $@");
    exit 1;
  }

=head1 AUTHOR

James Croall <jcroall@coverity.com>

(c) 2010 Coverity, Inc.  All rights reserved worldwide.

