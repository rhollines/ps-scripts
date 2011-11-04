#!/usr/bin/perl

=pod

=head1 COPYRIGHT

(c) 2011 Coverity, Inc. All rights reserved worldwide.

=head1 NAME

create-stream.pl


=head1 SYNOPSIS

create-stream.pl [options] --stream STREAM


=head1 OPTIONS

=over 12

=item Required:

=item B<--host>

CIM server HOST

=item B<--port>

CIM server PORT

=item B<--username>

CIM server USERNAME with admin access

=item B<--password>

CIM server PASSWORD

=item B<--stream>

New STREAM

=item Optional:

=item B<--project>

Associate newly created stream to PROJECT


=item B<--help>

Print documentation and exit

=back


=head1 DESCRIPTION

Create a stream.

=cut

##############################################################################
####### Initialization #######################################################

use strict;

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

#use SOAP::Lite +trace => 'debug';
use SOAP::Lite;

##############################################################################
####### Global data and configuration ########################################

my $opt_stream;
my $opt_project;

my $opt_host;
my $opt_port;
my $opt_username;
my $opt_password;

my $opt_help = 0;

##############################################################################
####### Subroutines ##########################################################

sub handle_command_line_options {
    GetOptions(
        # What to operate on
        'stream=s' => \$opt_stream,
        'project=s' => \$opt_project,
        # Standard CIM options
        'host=s' => \$opt_host,
        'port=s' => \$opt_port,
        'username=s' => \$opt_username,
        'password=s' => \$opt_password,
        # Common script options
        'help|?' => \$opt_help
    ) or pod2usage(-verbose => 1);
    pod2usage(-verbose => 2) if $opt_help;
    pod2usage(-verbose => 1) if (!$opt_stream);

    if (!$opt_host or !$opt_port or !$opt_username or !$opt_password) {
        print "Must specify CIM server and authentication details\n";
        pod2usage(-verbose => 1);
    }
}


sub ws_authen_text {
    my ($username, $password) = @_;

    my $auth = SOAP::Header->new('name' => 'wsse:Security');
    $auth->attr({'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'});
    $auth->mustUnderstand(1);

    $auth->value(
        \SOAP::Data->value(
            SOAP::Data->name('wsse:UsernameToken' =>
                \SOAP::Data->value(
                    SOAP::Data->name('wsse:Username' => $username),
                    SOAP::Data->name('wsse:Password' => $password)
                )
            )
        )
    );

    $auth;
}


sub call_method {
    my ($proxy, $username, $password, $methodName, $params) = @_;

    my $som = $proxy->call(
        SOAP::Data->name("ws:$methodName") => $params,
        ws_authen_text($username, $password)
    );

    if ($som->fault()) {
        my $errorCode = $som->fault()->{'detail'}->{'CoverityFault'}->{'errorCode'};
        my $errorMessage = $som->fault()->{'detail'}->{'CoverityFault'}->{'message'};
        print "Web API returned error code $errorCode: $errorMessage\n";
        return -1;
    } else {
        # Returns all parameters from a SOAP response, including the result entity itself, as one array.
        return $som->paramsall;
    }
}

##############################################################################
######## Main Script #########################################################

handle_command_line_options();

my $defectProxy = SOAP::Lite->proxy("http://$opt_host:$opt_port/ws/v4/configurationservice")->uri('http://ws.coverity.com/v4');
$defectProxy->transport->timeout(10);
$defectProxy->serializer->register_ns('http://ws.coverity.com/v4', 'ws');

# TODO: handle $opt_project if set

my $ret = call_method($defectProxy, $opt_username, $opt_password, 'createStream',
    SOAP::Data->name('streamSpec' =>
        \SOAP::Data->value(
            SOAP::Data->name('description' => 'created by create-stream.pl'),
            SOAP::Data->name('language' => 'CXX'), # CXX, JAVA, or CSHARP
            SOAP::Data->name('name' => $opt_stream)
        )
    )
);

if ($ret != -1) {
    print "Created stream $opt_stream\n";
}

