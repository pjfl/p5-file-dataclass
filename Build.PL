use strict;
use warnings;

use Module::Build 0.4004;

my $perl_ver = 5.010001;
my $name     = 'File-DataClass'; $name =~ s{ - }{::}gmx;
my $prereqs  = {
  'build_requires' => {
    'File::pushd' => '1.00',
    'Module::Build' => '0.4004',
    'Path::Tiny' => '0.013',
    'Test::Deep' => '0.108',
    'Test::Requires' => '0.06',
    'Text::Diff' => '1.37',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'requires' => {
    'Cache::FastMmap' => '1.40',
    'Class::Null' => '2.110730',
    'File::Path' => '2.09',
    'File::ReadBackwards' => '1.05',
    'Hash::Merge' => '0.200',
    'JSON::MaybeXS' => '1.002002',
    'Module::Pluggable' => '5.1',
    'Module::Runtime' => '0.014',
    'Moo' => '2.000001',
    'Sub::Install' => '0.928',
    'Subclass::Of' => '0.003',
    'Try::Tiny' => '0.22',
    'Type::Tiny' => '1.000002',
    'Unexpected' => 'v0.38.0',
    'boolean' => '0.45',
    'namespace::autoclean' => '0.22',
    'namespace::clean' => '0.25',
    'perl' => '5.010001'
  },
};
my $testing  = sub { $ENV{AUTOMATED_TESTING}
                  || $ENV{PERL_CPAN_REPORTER_CONFIG}
                  || $ENV{PERL5_CPANPLUS_IS_VERSION} };
my $whimper  = sub { print {*STDOUT} $_[ 0 ]."\n"; exit 0 };
my $stop     = sub {
   $testing->() or $whimper->( $_[ 0 ] );
   $prereqs->{build_requires} = { %{ $prereqs->{configure_requires} } };
   $prereqs->{build_requires}->{ 'Test::Requires' } = 0.06;
   delete $prereqs->{requires};
};

# Not interested in reports below min perl ver
$] < $perl_ver and $stop->( "Minimum required Perl version is ${perl_ver}" );

Module::Build->new(
   'module_name' => $name,
   'notes'       => { min_perl_version => $perl_ver, testing => $testing->() },
   %{ $prereqs },

)->create_build_script;

exit 0;
