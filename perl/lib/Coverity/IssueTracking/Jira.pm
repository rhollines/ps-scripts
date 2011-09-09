package Coverity::IssueTracking::Jira;

#use SOAP::Lite +trace => [qw(debug)];
use SOAP::Lite;

use Data::Dumper;
use Log::Log4perl qw(get_logger);


my $log = get_logger('export-defect-handler');

sub new {
  my ($class, %options) = @_;
  my $self = {
    %options
  };

  unless (defined($self->{url}) and length($self->{url})) {
    die "Must specify a URL base for Jira";
  }

  unless (defined($self->{username}) and length($self->{username})) {
    die "Must specify a username for Jira";
  }

  unless (defined($self->{password}) and length($self->{password})) {
    die "Must specify a password for Jira";
  }

  #$log->info(*self{PACKAGE} . " initializing for product $self->{product}");

  bless $self, $class;
}


sub create_issue {
  my ($self, $defectSummary) = @_;

  my $soap = SOAP::Lite->proxy("$self->{url}/rpc/soap/jirasoapservice-v2?wsdl");

  # Log in to Jira
  my $auth = $soap->login($self->{username}, $self->{password});

  if ($auth->fault()) {
    die "authentication error: $auth->faultstring()";
  }


  # Adding to a specific component?
  my @component_list;
  if ($self->{component}) {
    # Get components
    my $components = $soap->getComponents($auth->result(), $self->{project});

    if ($components->fault()) {
      die "unable to get components: $components->faultstring()";
    }

    # Look for the appropriate component ID
    #print "Components = " . Dumper($components->result()) . "\n"; 
    foreach my $comp (@{$components->result()}) {
      if ($comp->{name} eq $self->{component}) {
        #print "FOUND $comp->{name}:$comp->{id}\n";
        $comp->{"id"} = SOAP::Data->type(string => $comp->{"id"});
        push(@component_list, $comp);
      }
    }

    if ($#component_list < 0) {
      die "could not find component: $self->{component}";
    }
  }

  # Create new issue, filling in fields
  my $new_issue = {};

  $new_issue->{project} = SOAP::Data->type(string => $self->{project});
  $new_issue->{assignee} = SOAP::Data->type(string => $defectSummary->{owner});
  $new_issue->{type} = SOAP::Data->type(string => "3");  # Task

  $new_issue->{components} = SOAP::Data->type('impl:ArrayOf_tns1_RemoteComponent' => \@component_list);

  # Add required custom fields
  my @customfield_list;

  my $cf1 = SOAP::Data->type('tns1:RemoteCustomFieldValue' =>
    {
      'customfieldId' => SOAP::Data->type(string => "customfield_10332"),
      'key' => SOAP::Data->type(string => ""),
      'values' => [SOAP::Data->type(string => "1. What is the testing strategy for this change?\n2. Do multiple instances of the same application exist? Identify and define the instances for which the change needs to be applied to.\n3. Will this change have any downstream impacts on other systems?  If so how will you test this?\n4. Will this change impact key system controls or system generated reports? If so how will you test this?")]
    }
  );

  push @customfield_list, $cf1;

  my $cf2 = SOAP::Data->type('tns1:RemoteCustomFieldValue' =>
    {
      'customfieldId' => SOAP::Data->type(string => "customfield_10350"),
      'key' => SOAP::Data->type(string => ""),
      'values' => [SOAP::Data->type(string => "N/A")]
    }
  );

  push @customfield_list, $cf2;

  $new_issue->{customFieldValues} = SOAP::Data->type('impl:ArrayOf_tns1_RemoteCustomFieldValue' => \@customfield_list);


  while ( my ($key, $field) = each %{$self->{field}} ) {
    my $val = $self->replaceFields($field->{content}, $defectSummary);

    if (defined($field->{size}) and ($field->{size} >= 0)) {
      $val = sprintf("%.$field->{size}s", $val);
    }

    $new_issue->{$key} = SOAP::Data->type(string => $val);
  }

  if ($#component_list >= 0) {
    $new_issue->{"components"} = SOAP::Data->type('impl:ArrayOf_tns1_RemoteComponent' => \@component_list);
  }

  my $issue = $soap->createIssue($auth->result(), $new_issue);

  if ($issue->fault()) {
    die "unable to create issue: $issue->faultstring()";
  }

  $soap->logout($auth->result());

  my $jira_issue = $issue->result();

# #print "Created new issue: $jira_issue->{key}\n";
# #print "==========================================================\n";
# #print Dumper($issue);
# #print "==========================================================\n";

  return $jira_issue->{key};
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

