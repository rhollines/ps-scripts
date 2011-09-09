# Called by the Coverity perl script exporter.

use strict;
use warnings;

my ($login, $password, $database, $tempfile) = @ARGV;

open(TEMP, $tempfile);
my $headline = <TEMP>;  # assume headline is on first line of tempfile
chomp($headline);

my $description;  # assume description is rest of tempfile
while (<TEMP>) {
  $description .= $_;
}
chomp($description);
close(TEMP);

#print "headline: $headline\n";
#print "description: $description\n";


use CQPerlExt;

my $type = 'BaseCMActivity';

my $session = CQSession::Build();
if (! defined $session) {
    print STDERR "Could not create a ClearQuest session.\n";
    exit(1);
}

$session->UserLogon($login, $password, $database, '');


my ($entity) = $session->BuildEntity($type);
my $result;

#$result = $entity->SetFieldValue('Owner', $owner);
#if ($result ne "") {
#    print STDERR "SetFieldValue for Owner failed: $result\n";
#    exit(1);
#}

$result = $entity->SetFieldValue('Headline', $headline);
if ($result ne "") {
    print STDERR "SetFieldValue for Headline failed: $result\n";
    exit(1);
}

$result = $entity->SetFieldValue('Description', $description);
if ($result ne "") {
    print STDERR "SetFieldValue for Description failed: $result\n";
    exit(1);
}


my $cq_code_output = $entity->GetFieldValue('id')->GetValue();

$entity->Validate();
$entity->Commit();

CQSession::Unbuild($session);

print $cq_code_output;

