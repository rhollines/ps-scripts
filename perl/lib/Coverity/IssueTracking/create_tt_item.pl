# This must be in a separate file otherwise the export-defect-handler in CIM
# hangs when the TeamTrack Web API is called.

# Anything printed to stdout will be displayed in the dialog box.  This script
# should return 0 for success or non-zero otherwise.

use strict;
use SOAP::Lite; # +trace => [ transport => sub { print Dumper(@_); } ];

# --- some subroutines ---

sub xml_quote {
  my ($value) = @_;
  $value =~ s/&/&amp;/g;
  $value =~ s/</&lt;/g;
  $value =~ s/>/&gt;/g;
  $value =~ s/"/&quot;/g;  #" fix TextPad highlighting
  $value =~ s/'/&apos;/g;
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


# -----

#
# Get the command line arguments
#
my ($url, $username, $password, $projectID, $tempfile) = @ARGV;
unless (-e $tempfile) {
  print "Temp file \"$tempfile\" from coverity not found\n";
  exit(-1);
}

my $item;

# Open the tmp file that was created by coverity and passed on the
# command line
open(TEMP, $tempfile);

while (<TEMP>) {
  $item .= $_;
}

close(TEMP);


# Use TeamTrack SOAP Web API to create the item.
my $soap = SOAP::Lite->new(
    proxy => $url,
    uri => 'urn:ttwebservices');
  
my $som;
  
# For the submit to work, one must call GetVersion, GetSubmitProjects, and finally CreateItem.
# Oddly, if GetSubmitProjects is omitted, it doesn't seem to work.
  
$som = $soap->GetVersion();
#print "GetVersion() result: ", Dumper($som->result), "\n"; 
#print Dumper($som);
  
$som = $soap->GetSubmitProjects(ws_authen_text($username, $password));
#print "GetSubmitProjects() result: ", Dumper($som->result), "\n";
#print Dumper($som);

$som = $soap->CreatePrimaryItem(
  ws_authen_text($username, $password),
  SOAP::Data->name("projectID" => $projectID),
  SOAP::Data->type('xml' => $item)
);

#print "CreatePrimaryItem() result: ", Dumper($som->result), "\n";
#print Dumper($som);
my $itemName = "";
  
if ($som->result) {
  $itemName = $som->result->{genericItem}->{itemName};
} else {
  print "<br>Nested reason: TeamTrack CreatePrimaryItem failed - $som->{_content}[4]->{Body}->{Fault}->{faultstring}";
  exit(-1);
}

print $itemName;
exit(0);

