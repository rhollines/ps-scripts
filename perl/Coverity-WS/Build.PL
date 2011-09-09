use Module::Build;
use version;

$build = Module::Build->new(
    dist_author        => 'James Croall <jcroall@coverity.com>',
    create_makefile_pl => 'small',
    dist_abstract      => 'Coverity Integrity Manager Web Services',
    dist_name          => 'Coverity-WS',
    dist_version       => '0.3',
    module_name        => 'Coverity::WS',
    #license            => 'artistic',
    requires           => {
        # 5.6.x is way too buggy and has no unicode support
        # for us.
        'perl'                    => q(5.8.0),
        'Digest::SHA1'            => q(2.12),
        'SOAP::Lite'              => q(0.711),
        #'SOAP::Lite'              => q(0.711),
        'HTTP::Request'           => q(5.827),
        'Test::Simple'            => q(0.44),
    },
    #build_requires => {
    #    'Class::Std::Fast'        => q(0.0.5),
    #    'Cwd'                     => 0,
    #    'Date::Parse'             => 0,
    #    'Date::Format'            => 0,
    #    'Getopt::Long'            => 0,
    #    'List::Util'              => 0,
    #    'LWP::UserAgent'          => 0,
    #    'Module::Build'           => 0,
    #    'File::Basename'          => 0,
    #    'File::Path'              => 0,
    #    'File::Spec'              => 0,
    #    'Storable'                => 0,
    #    'Test::More'              => 0,
    #    'Template'                => q(2.18),
    #    'XML::Parser::Expat'      => 0,
    #},
    recursive_test_files => 1,
    #meta_add => {
    #    no_index => {
    #        directory => 'lib/SOAP/WSDL/Generator/Template/XSD/',
    #    },
    #}
);
#$build->add_build_element('tt');
$build->create_build_script;
