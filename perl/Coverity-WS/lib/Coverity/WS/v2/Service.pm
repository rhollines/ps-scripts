# (c) 2010 Coverity, Inc.  All rights reserved worldwide.
#
# $Id: Service.pm,v 1.2 2010/04/07 17:12:47 jcroall Exp $

# See perldoc for external usage info, inline comments are comments on
# the code itself for developers and maintainers.

package Coverity::WS::v2::Service::CovRemoteServiceException;

$VERSION = 0.3.1;

use overload ('""' => 'stringify');

sub stringify
{
  my ($self) = @_;

  my $class = ref($self) || $self;

  return "$class Exception: $self->{errorCode}: $self->{message}\n";
  # Assuming that errMsg(), lineNo() & file() are methods
  # in the exception class
  # to store & return error message, line number and source
  # file respectively.
}

sub new {
  my ($class, %param) = @_;

  if (!$param{errorCode} or !$param{message}) {
    die "CovRemoteServiceException requires errorCode and message\n";
  }

  my $self = {};
  bless $self, $class;

  $self->{errorCode} = $param{errorCode};
  $self->{message} = $param{message};

  return $self;
}

package Coverity::WS::v2::Service;

our $VERSION = 0.3.1;
our $VERSION_STRING = "v2";

use Data::Dumper;
#use SOAP::Lite +trace => 'debug';
use SOAP::Lite;
use Time::Local;
use MIME::Base64;

use Coverity::WS::v2::Serializer;

use strict;

##############################################################################
####### Global Data ##########################################################

my $coverity_service_ns = "http://ws.coverity.com";

##############################################################################
####### Utilities ############################################################

sub xml_quote {
  my ($value) = @_;
  $value =~ s/&/&amp;/;
  $value =~ s/</&lt;/;
  $value =~ s/>/&gt;/;
  $value;
}

sub _complex_type {
  my ($name,@childs) = @_;
  my $data = SOAP::Data->new( name => $name );
  $data->value( \SOAP::Data->value(@childs));
  $data;
}

sub _typeless {
  my ($name,$value) = @_;
  my $data = SOAP::Data->new( name => $name );

  $value = xml_quote($value);

  $data->value( $value );
  $data->type( "" );
  $data;
}

sub _soap_args {
  my (%hash) = @_;
  SOAP::Data->value(map { SOAP::Data->name( $_ => $hash{$_}) } keys(%hash));
}

sub ws_authen_text {
  my($username,$password) = @_;

  my $auth = SOAP::Header->new( name => "wsse:Security" );

  $auth->attr( {
    "xmlns:wsse" => "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
  } );
  $auth->mustUnderstand(1);

  $auth->value( \SOAP::Data->value(
    _complex_type ( "wsse:UsernameToken",
      _typeless("wsse:Username",$username),
      _typeless("wsse:Password",$password)->attr({
        "Type" => "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText"
      })
    )
  ));
  $auth;
}

##############################################################################
####### Constructor ##########################################################

sub new {
  my ($class, %param) = @_;

  my $self = {
    %param,
  };

  bless $self, $class;

  if (exists($param{logger}) and $param{logger}) {
    $self->{logger} = $param{logger};
  } else {
    $self->{logger} = 0;
  }

  # Must specify host name
  if (!$param{host}) {
    die "ERROR: Must specify host name"
  }
  $self->{host} = $param{host};

  # Port is optional
  if (!$param{port}) {
    $param{port} = 8080;
  }
  $self->{port} = $param{port};

  # Must specify username and password
  if (!$param{username} || !$param{password}) {
    die "ERROR: Must specify username and password\n";
  }

  # Authentication method defaults to text
  if (!$param{authtype}) {
    $param{authtype} = "text";
  }
  $self->{authtype} = $param{authtype};

  # Secure connection
  $self->{protocol} = "http";
  if ($param{ssl}) {
    if ($param{ssl} =~ /on/i or $param{ssl} =~ /1/ or $param{ssl} =~ /true/i) {
      $self->{protocol} = "https";
    }
  }

  # Create appropriate Web Services Security header: Plain Text or Digest
  if ($self->{authtype} =~ /text/i) {
    $self->{wss} = ws_authen_text($param{username}, $param{password});
  } else {
    die "ERROR: Unsuppotred authentication type '$self->{authtype}'\n";
  }

  # Load service name from subclass
  eval "\$self->{service_name} = \$$class" . "::service_name";
  die $@ if $@;

  # Load service namespace from subclass
  eval "\$self->{service_ns} = \$$class" . "::service_ns";
  die $@ if $@;

  # Load supported methods from subclass
  eval "\$self->{service_methods} = \$$class" . "::service_methods";
  die $@ if $@;

  if (!$self->{service_name} || !$self->{service_ns} ||
      !$self->{service_methods}) {
      die "ERROR: Class $class must declare service name, namespace and methods\n";
    }

  # Format address of service
  $self->{address} =
    $self->{protocol} . "://" . $self->{host} . ":" . $self->{port} . "/ws/" .
      $VERSION_STRING . "/" .
      $self->{service_name};
  $self->{wsdl} =
    $self->{protocol} . "://" . $self->{host} . ":" . $self->{port} . "/ws/" .
      $VERSION_STRING . "/" .
      $self->{service_name} . "?wsdl";

  # Create SOAP Proxy
  if (!$param{proxy}) {
    $self->{soap_proxy} = SOAP::Lite->proxy($self->{address});
  } else {
    $self->{soap_proxy} = SOAP::Lite->proxy(
      $self->{address},
      proxy => ["http" => $param{proxy}]
    );
  }
  #$self->{proxy}->transport->proxy(http => "http://blade3.sf.coverity.com:8888");

  # Very important! Keep XML simple and turn off fancy auto-typing.
  $self->{soap_proxy}->autotype(0);

  $self->{soap_proxy}->serializer(Coverity::WS::v2::Serializer->new);

  $self->{serializer} = $self->{soap_proxy}->serializer();
  $self->{serializer}->register_ns($self->{service_ns}, "ws");
  $self->{serializer}->autotype(0);

  # Save class name
  $self->{class} = $class;

  # Fill in service-specific details
  $self->init($class);

  return $self;
}

sub init {
  die "ERROR: Mandatory method init() not defined in ", ref $_[0];
}

##############################################################################
####### Autoload Catch-all ###################################################

sub AUTOLOAD {
  #my $self = shift;
  my ($self, %param) = @_;

  our $AUTOLOAD;
  my $subroutine_name = $AUTOLOAD;

  my $method = substr($subroutine_name, rindex($subroutine_name, '::') + 2);
  # Skip DESTROY and other all-cap methods
  return unless $method =~ /[^A-Z]/;

  # Is this a supported method for this service?
  if ($self->{service_methods}->{$method}) {
    #print "OK: calling $self->{service_name}::$method\n";

    # Check parameters. Step 1 - are they all present?
    foreach my $arg (keys %{$self->{service_methods}->{$method}[0]}) {
      my $required = $self->{service_methods}->{$method}[0]->{$arg}[1];

      if ($required and !$param{$arg}) {
        die "method '$method' requires parameter '$arg'";
      }
    }

    # Check parameters. Step 2 - are they valid?
    foreach my $arg (keys %param) {
      if (!$self->{service_methods}->{$method}[0]->{$arg}) {
        warn "Extra argument '$arg' for method '$method'";
      } else {

        # XXX Deprecated
        if (0) {
        # What type should this parameter be?
        my $type = $self->{service_methods}->{$method}[0]->{$arg}[0];
        # It's actually of this type
        my $arg_type = ref $param{$arg};

        # If the wrong type was passed in, throw an exception
        if ($type ne "pod" and ($arg_type ne  $self->{class} . "::" . $type)) {
          die "parameter $arg is of type $arg_type, expecting $self->{class}" . "::" . "$type";
        }
        }
        # XXX Deprecated
      }
    }

    # Format parameters for SOAP -- only have to do the top level,
    # SOAP modules will handle nested data structures.
    my $soap_param = SOAP::Data->value(
      map {
        SOAP::Data->name( $_ => $param{$_})
      } keys(%param)
    );
    $soap_param = _soap_args(%param);

    my $som = $self->{soap_proxy}->call(
      SOAP::Data->name("ws:" . $method)
        => $soap_param,
        $self->{wss}
    );

    if (!$som->fault()) {
      my $return_type = $self->{service_methods}->{$method}[1][0];
      my $want_array =  $self->{service_methods}->{$method}[1][1];
      my $convert_to_array = $self->{service_methods}->{$method}[1][2];
      my @return_data;

      # Return without checking data types
      @return_data = $som->paramsall;
        
      if ($want_array) {
        return @return_data;
      } else {
        if ($convert_to_array and length($convert_to_array) > 0) {
          $return_data[0]->{$convert_to_array} = forceArray($return_data[0]->{$convert_to_array});
        }
        return $return_data[0];
      }
    } else {
      # Exception was thrown
      my $fault = $som->faultdetail();

      # If we don't have a CoverityFault it was a general error
      if (!$fault->{'CoverityFault'}) {
        if (!$fault->{'exception'}->{'message'}) {
          die "unknown error: " . Dumper($fault);
        } else {
          die "generic error: $fault->{'exception'}->{'message'}";
        }
      }

      # Create new CovRemoteServiceException based on fault
      my $exception = new Coverity::WS::v2::Service::CovRemoteServiceException(
        errorCode =>  $fault->{CoverityFault}->{errorCode},
        message =>  $fault->{CoverityFault}->{message}
      );

      # Throw
      die $exception;
    }
  } else {
    die new Coverity::WS::v2::Service::CovRemoteServiceException(
      errorCode => -1,
      message => "cannot find $self->{service_name}::$method"
    );
  }

  return;
}

sub forceArray {
  my ($possibleArrayRef) = @_;
  my @returnArray;

  if (ref $possibleArrayRef eq "ARRAY") {
    return $possibleArrayRef;
  }
  push(@returnArray, $possibleArrayRef);
  return \@returnArray;
}


1;

__END__

=head1 NAME

Coverity::WS::v2::Service - Base class for all Coverity Integrity Manager Web Services

=head1 DESCRIPTION

Coverity::WS::v2::Service is an abstract base class for all CIM Web Services.
This class performs authentication, SOAP data marshalling, and automatic
dispatch for individual services.

All a subclass must provide is three critical variables:

=over 4

=item B<$service_name> - name of the service being implemented

=item B<$service_ns> - namespace of the service being implemented

=item B<$service_methods> - A list of the methods this service provide (This is required because SOAP::Lite does not support WSDL for automatic discovery)

=back

A subclass may optionally provide:

=over 4

=item B<Constant values> - Constant values to be used by client applications

=item B<init()> - An initialization routine, called during construction of the subclass

=item B<Service data types> - Data types used by this service

=back

The constructor takes the following options:

=over 4

=item B<host> - Hostname of Coverity Integrity Manager server

=item B<port> - Port number of Coverity Integrity Manager server

=item B<username> - Username to log in as

=item B<password> - Password for username

=item B<protocol> - Protocol to use, either http or https. Defaults to http.

=item B<proxy> - Optional HTTP proxy server, of the format: http://proxyserver:port/

=back

=head1 SYNOPSIS

A service-specific subclass first inherits from Coverity::WS::v2::Service:

  our @ISA = qw(Coverity::WS::v2::Service);

Next provide the service-specific details:

  our $service_name = "projectservice";
  our $service_ns = "http://ws.coverity.com";
  our $service_methods = {
  getStream => [                # Name of method
    {                           #   List of parameters
      name => ['pod', 0],       #     name of parameter, data type, is sequence
      streamType => ['pod', 0]  #     name is streamType, plain old Perl data, single item
    },                          # 
    ['streamDataObj', 0]        #   Return data type
  ],
  getAllProjects => [
    {
      # No arguments
    },
    ['projectDataObj', 1]
  ]
  };

We may also specify some constants:

  # Stream types
  use constant SOURCE   => "SOURCE";
  use constant STATIC   => "STATIC";
  use constant DYNAMIC  => "DYNAMIC";

Making sure to export to the client environment:

  our @EXPORT= (SOURCE, STATIC, DYNAMIC);
  our %EXPORT_TAGS = (
    streamTypes => [ SOURCE, STATIC, DYNAMIC ],
  );

Our service may also require some complex data types, which all in herit from DataObj:

  package Coverity::WS::v2::ProjectService::streamSpecDataObj;

  # Inherit from DataObj base class
  use Coverity::WS::v2::DataObj
    'description' => ["pod", 0 ],
    'language' => ["pod", 0 ],
    'name' => ["pod", 0 ],
    'type' => ["pod", 0 ];

  our @ISA = qw(Coverity::WS::v2::DataObj);

That's it, we now have a service we can use!

  use Coverity::WS::v2::ProjectService;

  my $projectService = new Coverity::WS::v2::ProjectService(
                          host => "localhost",
                          username => "admin",
                          password => "coverity"
                        );

  my @projects = $projectService->getAllProjects();

=head1 AUTHOR

James Croall <jcroall@coverity.com>

(c) 2010 Coverity, Inc.  All rights reserved worldwide.

