package TestConfig;

use base Exporter;
our @EXPORT = qw($remote $port $username $password $ssl);

# Point to your CIM instance here

our $remote = "t-linux64-15";
our $port = 6613;
our $username = "admin";
our $password = "coverity";
our $ssl = "off";

1;
