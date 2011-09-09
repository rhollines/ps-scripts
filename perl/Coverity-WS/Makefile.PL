use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Coverity::WS',
    VERSION_FROM => 'lib/Coverity/WS/v1/Service.pm', # finds \$VERSION
    AUTHOR       => 'James Croall (jcroall@coverity.com)',
    ABSTRACT     => 'Coverity Integrity Manager Web Services API for Perl',
    #EXE_FILES    => [ 'scripts/cov-test-im' ],
    PREREQ_PM    => {
                     'SOAP::Lite'     => 0.711,
                     'HTTP::Request'  => 0,
                     'Test::Simple'   => 0,
                     'Test::Request'  => 0,

                    },
);
