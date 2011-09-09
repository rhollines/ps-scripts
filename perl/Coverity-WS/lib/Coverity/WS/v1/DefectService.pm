# (c) 2010 Coverity, Inc.  All rights reserved worldwide.
#
# $Id: DefectService.pm,v 1.1 2010/04/04 22:20:51 jcroall Exp $

# See perldoc for external usage info, inline comments are comments on
# the code itself for developers and maintainers.

package Coverity::WS::v1::DefectService;

$VERSION = 0.2;

use strict;

require Exporter;
use Data::Dumper;
use Coverity::WS::v1::Service;

our @ISA = qw(Coverity::WS::v1::Service Exporter);

# Declare service
our $service_name = "defectservice";
our $service_ns = "http://ws.coverity.com/$Coverity::WS::v1::Service::VERSION_STRING";
our $service_methods = {
  getMergedDefectHistory => [
    {
      cid => ['pod', 1],
      scopePattern => ['pod', 0],
    },
    ['pod', 1]
  ],
  getMergedDefectsForProject => [
    {
      projectId => ['pod', 0],
      filterSpec => ['pod', 0],
      pageSpec => ['pod', 0],
    },
    ['pod', 0, 'mergedDefects']
  ],
  getMergedDefectsForStreams => [
    {
      analysisStreamIds => ['pod', 0],
      filterSpec => ['pod', 0],
      pageSpec => ['pod', 0],
    },
    ['pod', 0, 'mergedDefects']
  ],
  getSnapshotsForProject => [
    {
      projectId => ['pod', 0],
      filterSpec => ['pod', 0],
    },
    ['pod', 1]
  ],
  getStreamDefects => [
    {
      cid => ['pod', 1],
      includeDetails => ['pod', 1],
      scopePattern => ['pod', 0],
    },
    ['pod', 1]
  ],
  updateStreamDefects => [
    {
      streamDefectIds => ['pod', 0],
      defectStateSpec => ['pod', 0],
    },
    ['pod', 0]
  ]
};

#
# Constants
#

# Checker types
use constant STATIC_C     => "STATIC_C";
use constant STATIC_CS    => "STATIC_CS";
use constant STATIC_JAVA  => "STATIC_JAVA";
use constant DYNAMIC_JAVA => "DYNAMIC_JAVA";

our @EXPORT= (STATIC_C, STATIC_CS, STATIC_JAVA, DYNAMIC_JAVA);
our %EXPORT_TAGS = (
  checkerTypes => [ STATIC_C, STATIC_CS, STATIC_JAVA, DYNAMIC_JAVA ]
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

Coverity::WS::v1::DefectService - Perl interface for the Coverity Defect Service

=head1 DESCRIPTION

Coverity::WS::v1::DefectService provides a Perl native interface for the Coverity Integrity Manager Defect Service,
as defined in the Coverity Integrity Manager API reference manual.

This class implements wrappers for each DefectService complex type.

=head1 SYNOPSIS

The first step is to instantiate the DefectService, pointing it at the Coverity Integrity Manager:

  use Coverity::WS::v1::DefectService qw(:checkerTypes);

  # Create DefectService context
  my $defectService = new Coverity::WS::v1::DefectService(
    remote => "localhost",
    port => 8080,
    username => "admin",
    password => "coverity"
  );

The constructor method will only fail if invalid or incomplete options are presented.

DefectService method calls may now be invoked:

  # Get all defects for Demo project
  my @defects = $defectService->getMergedDefectsForProject(
    projectName => "Demo"
  );

Some methods may require complex data types to be created. These DefectService types must be explicitly instantiated:

  # Create a new severity data object
  my $severity = new Coverity::WS::v1::DefectService::severityDataObj;
  $severity->name = "Major";

  # Create a new defect change data object
  my $change = new Coverity::WS::v1::DefectService::defectStatusChangeDataObj;
  $change->severity = $severity;

  # Now we can update the defect
  $defectService->updateMergedDefect(cid => $cid, change => $change);

The DefectService will throw an exception on error, which may be handled using Perl's eval/die mechanism:

  eval {
    my $streamDefect = $defectService->getStreamDefect(
      id => $sid,
      includeDetails => "true"
    );
  };
  if ($@) {
    $logger->error("Unable to get stream defect $sid: $@");
    exit 1;
  }

=head1 AUTHOR

James Croall <jcroall@coverity.com>

(c) 2010 Coverity, Inc.  All rights reserved worldwide.

