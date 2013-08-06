# @(#)$Ident: Build.PL 2013-08-06 17:18 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.23.%d', q$Rev: 1 $ =~ /\d+/gmx );

Bob->new( {
   module    => 'File::DataClass',
   home_page => 'http://www.roxsoft.co.uk',
   requires  => {
      'perl'             => 5.010001,
      'namespace::clean' => 0.23,
      'namespace::sweep' => 0.006,
      'Cache::FastMmap'  => 1.36,
      'CHI'              => 0.58,
      'Class::Load'      => 0.18,
      'Class::Method::ModifiersX::Augment' => 0.001,
      'Class::Null'      => 2.101420,
      'File::Path'       => 2.08,
      'Hash::Merge'      => 0.12,
      'JSON'             => 2.50,
      'Moo'              => 1.003,
      'MooX::ClassStash' => 0.005,
      'Try::Tiny'        => 0.09,
      'Type::Tiny'       => 0.012,
      'XML::Bare'        => 0.47,
      'XML::DTD'         => 0.10,
      'XML::Simple'      => 2.18,
      'Unexpected'       => q(0.6.0), },
   recommends            => {
      'App::cpanminus'   => 1.6005, },
   configure_requires    => {
      'version'          => 0.88,
      'Module::Build'    => 0.4004, },
   build_requires        => {
      'version'          => 0.88,
      'File::pushd'      => 1.00,
      'Module::Build'    => 0.4004,
      'Test::Deep'       => 0.108,
      'Text::Diff'       => 1.37, },
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: Dataclass
# eval: (load-project-state "file-dataclass")
# mode: perl
# tab-width: 3
# End:
