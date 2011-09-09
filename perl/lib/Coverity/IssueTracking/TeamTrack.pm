package Coverity::IssueTracking::TeamTrack;

#
# (c) 2010 Coverity, Inc.  All rights reserved worldwide.
#
# $Id: Coverity::IssueTracking::TeamTrack;
#

use strict;

use Data::Dumper;
use Log::Log4perl qw(get_logger);


use Coverity::Command;

my $log = get_logger('export-defect-handler');

# Constructor.
#
# To initialize directly, call in the following manner:
# my $bts = new Coverity::IssueTracking::Teamtrack( hashmap );

sub new {
  my ($class, %options) = @_;
  my $self = {
    %options
  };

  bless $self, $class;

}


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
  

sub dump {
  my ($self) = @_;
  print Dumper($self), "\n";
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


# -----

sub create_issue {
  my ($self, $defectSummary) = @_;

  # create a TeamTrack issue
  my $tt_url = 'http://teamtrackdev.qualcomm.com:80/gsoap/gsoap_ssl.dll?ttwebservices';
  my $username = 'rchicken';
  my $password = '';
  
  my $projectID = 132;  # Brew Mobile Platform
  
  my $description_template = <<END;
Coverity Defect<br>
<br>
File: %file%:%lineNumber%<br>
Function: %functionDisplayName%<br>
<br>
%eventTag%: %eventDescription%
END
  
  my $title       = xml_quote($self->replaceFields("CID %cid%: %checker%", $defectSummary));
  my $description = xml_quote($self->replaceFields($description_template,  $defectSummary));


  
  # the following are all specific to QCOM
  my $subsystem = "Unknown";
  my $build = "0";
  my $product = "BUILD_GENBMPDYNAMIC";
  my $phase = "Development";
  my $baseline = "N/A";
  my $impact = "To Be Determined";
  my $testcase = "N/A";

  # Extract product name from filepath  
=cut
  my ($waste, $bmp_subsystem) = split(/brewmp\//, $defectSummary->{file});
  my ($sub1, $sub2) = split(/\//, $bmp_subsystem, 3);
  my $product_subsystem = uc($sub1."_".$sub2);
  #print "Now printing $product_subsystem\n";
  if ($product_subsystem eq "_") {
    print "<br>Unable to create TeamTrack item!";
    print "<br>Please consult your Coverity Administrator.";
    print "<br><br>Reason: Extracted '_' as product subsystem which is invalid.";
    return "";    
  }
  $product = $product_subsystem;
=cut

  # TTItem
  my $item = "<item>" .
          "<classification>Bug</classification>" .
          "<title>$title</title>" .
          "<description>$description</description>" .
          "<activeInactive>true</activeInactive>" .
          
          "<extendedFieldList>" .
          "  <name>Product</name>" .
          "  <value>$product</value>" .
          "</extendedFieldList>" .
          
          "<extendedFieldList>" .
          "  <name>SUBSYSTEM</name>" .
          "  <value>$subsystem</value>" .
          "</extendedFieldList>" .
          
          "<extendedFieldList>" .
          "  <name>FOUND_IN_BUILD_ID_NUM</name>" .
          "  <value>$build</value>" .
          "</extendedFieldList>" .
          
          "<extendedFieldList>" .
          "  <name>PHASE_FOUND_IN</name>" .
          "  <value>$phase</value>" .
          "</extendedFieldList>" .
          
          "<extendedFieldList>" .
          "  <name>BREW_MP_BASELINE</name>" .
          "  <value>$baseline</value>" .
          "</extendedFieldList>" .
          
          "<extendedFieldList>" .
          "  <name>BMP_SYSTEM_IMPACT</name>" .
          "  <value>$impact</value>" .
          "</extendedFieldList>" .
          
          "<extendedFieldList>" .
          "  <name>TESTCASE_ID</name>" .
          "  <value>$testcase</value>" .
          "</extendedFieldList>" .
          
          "</item>";


  # Create a temp file and write out the item xml
  use File::Temp qw(tempfile tempdir);
  use XML::Simple;
  
  my ($fh, $filepath) = tempfile();  
  print $fh $item;  
  close($fh);

  # This must be in a separate file otherwise the export-defect-handler in CIM
  # hangs when the TeamTrack Web API is called.
  my $script = 'C:\Program Files\Coverity\ps-scripts\lib\Coverity\IssueTracking\create_tt_item.pl';
  if (! -e $script) {
    print "<br>Unable to create TeamTrack item!";
    print "<br>Please consult your Coverity Administrator.";
    print "<br><br>Reason: cannot find script $script called from lib/Coverity/IssueTracking/TeamTrack.pm";
    return "";
  }
  
  # Complete command line
  my $perl_command .= "perl \"$script\" \"$tt_url\" \"$username\" \"$password\" \"$projectID\" $filepath";
  
  # Execute command line
  my $perl_output;
  
  #print "EXEC: $perl_command\n";
  my $cmd = new Coverity::Command();
  
  my $ret_code = $cmd->run($perl_command, \$perl_output);
  
  #print "OUTPUT: retcode: $ret_code\n";
  #print "OUTPUT: $cqperl_output\n";
  
  # Warn if error
  if ($ret_code != 0) {
    print "<br>Unable to create TeamTrack item!";
    print "<br>Please consult your Coverity Administrator.";
    print "<br><br>Reason: $script exited with $ret_code<br>";
    if ($perl_output) {
      print $perl_output;
    }
    return "";
  } else {
    # return unique id
    return $perl_output;
  }
}

