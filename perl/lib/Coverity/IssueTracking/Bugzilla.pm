package Coverity::IssueTracking::Bugzilla;

#
# (c) 2008 Coverity, Inc.  All rights reserved worldwide.
#
# $Id: Bugzilla.pm,v 1.6 2009/05/15 17:52:40 jcroall Exp $
#

use strict;

use LWP::UserAgent;
use HTTP::Cookies;
use File::Spec;
use Data::Dumper;
use Log::Log4perl qw(get_logger);

my $log = get_logger('export-defect-handler');


# Report this user agent when querying Bugzilla
my $user_agent_string = "Coverity/1.0";


# Constructor.
#
# To initialize directly, call in the following manner:
# my $bts = new Coverity::IssueTracking::Bugzilla( hashmap );
sub new {
  my ($class, %options) = @_;
  my $self = {
    %options
  };

  #print Dumper($dom), "\n";

  # Must specify a URL base for Bugzilla
  unless (defined($self->{url}) and length($self->{url})) {
    die "Must specify a URL base for Bugzilla";
  }

  # Must specify username and password to login to Bugzilla
  unless (defined($self->{username}) and length($self->{username})) {
    die "Must specify username for Bugzilla";
  }

  unless (defined($self->{password}) and length($self->{password})) {
    die "Must specify password for Bugzilla";
  }

  # Log in to Bugzilla
  my $user_agent = LWP::UserAgent->new(agent => $user_agent_string);
  my $cookies = HTTP::Cookies->new(
    file => File::Spec->tmpdir() . "bugzilla-cookies.txt",
    autosave => 1,
    ignore_discard => 1
  );
  $user_agent->cookie_jar($cookies);

  my $request = HTTP::Request->new(
    POST => $self->{url} . "/index.cgi"
  );
  $request->content_type("application/x-www-form-urlencoded");
  $request->content("Bugzilla_login=$self->{username}&Bugzilla_password=$self->{password}");

  my $response = $user_agent->request($request);

  if ($response->is_success && (my $cookie = $response->header("Set-Cookie"))) {
    $self->{cookies} = $cookies;
  } else {
    $log->error("Could not log into Bugzilla");
  }

  bless $self, $class;
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


sub create_issue {
  my ($self, $defectSummary) = @_;

  # Construct the post bug query
  my $url = URI->new("$self->{url}/post_bug.cgi");

  # Fill in necessary form fields for a new bug
  my $form_data = {};

  while ( my ($key, $field) = each %{$self->{field}} ) {
    my $val = $self->replaceFields($field->{content}, $defectSummary);

    # Truncate fields if necessary
    if (defined($field->{size}) and ($field->{size} >= 0)) {
      $form_data->{$key} = sprintf("%.$field->{size}s", $val);
    } else {
      $form_data->{$key} = $val;
    }
  }

  $url->query_form(%{$form_data});

  # Create a user agent, load our previously saved cookie and submit the bug
  my $user_agent = LWP::UserAgent->new(agent => $user_agent_string);
  $user_agent->cookie_jar($self->{cookies});

  my $response = $user_agent->get($url);
  my $content = $response->content;

  # If the submission was successful we should receive an HTML page containing
  # the new bug ID.
  my ($bugzilla_id) = ($content =~ /Bug (\d+) Submitted/);

  if ($bugzilla_id) {
    $log->info("Created Bugzilla issue, ID is $bugzilla_id");
  } else {
    $log->error("Unable to create Bugzilla issue, post_bug URL was $url");
    $bugzilla_id = -1;
  }

  return $bugzilla_id;
}


# TODO-SK: I have no idea if this works or not...
sub close_issue {
  my ($self, $defect, $id) = @_;

  # Construct the update/process bug query
  my $url = URI->new("$self->{url}/process_bug.cgi");

  # Fill in the necessary form fields for updating a bug. Similar to bug post
  # but leave out the comment and turn the knobs in order to close the bug.
  my $form_data = {};

  $form_data->{id} = $id;
  $form_data->{knob} = "resolve";
  $form_data->{resolution} = "FIXED";
  $form_data->{bug_file_loc} = "1";
  $form_data->{longdesclength} = "1";

  foreach my $field (@{$self->{field}}) {
    my $key = $field->{id};

    # We do not want to add another comment to the bug
    if ($key eq "comment") { next; }

    my $val = $self->replace_fields($field->{content}, $defect);

    # Truncate fields if necessary
    if (defined($field->{size}) and ($field->{size} >= 0)) {
      $form_data->{$key} = sprintf("%.$field->{size}s", $val);
    } else {
      $form_data->{$key} = $val;
    }
  }

  $url->query_form(%{$form_data});

  my $user_agent = LWP::UserAgent->new(agent => $user_agent_string);
  $user_agent->cookie_jar($self->{cookies});

  my $response = $user_agent->get($url);
  my $content = $response->content;

  # TODO: Check content for error code?

  return;
}
