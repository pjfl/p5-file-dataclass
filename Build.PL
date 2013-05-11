# @(#)$Ident: Build.PL 2013-05-11 08:46 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.20.%d', q$Rev: 8 $ =~ /\d+/gmx );

Bob->new( {
   module    => q(File::DataClass),
   home_page => q(http://www.roxsoft.co.uk),
   requires  => {
      'perl'                       => 5.01,
      'namespace::autoclean'       => 0.13,
      'namespace::clean'           => 0.23,
      'Cache::FastMmap'            => 1.36,
      'CHI'                        => 0.42,
      'Class::Null'                => 2.101420,
      'Hash::Merge'                => 0.12,
      'JSON'                       => 2.50,
      'Moose'                      => 2.0802,
      'MooseX::ClassAttribute'     => 0.27,
      'MooseX::Types'              => 0.35,
      'Sub::Exporter'              => 0.982,
      'Sub::Exporter::Progressive' => 0.001006,
      'Try::Tiny'                  => 0.09,
      'XML::Bare'                  => 0.47,
      'XML::DTD'                   => 0.10,
      'XML::Simple'                => 2.18,
      'Unexpected'                 => q(0.1.0), },
   recommends            => {
      'App::cpanminus'   => 1.6005, },
   configure_requires    => {
      'version'          => 0.88,
      'Module::Build'    => 0.4004, },
   build_requires        => {
      'version'          => 0.88,
      'Exception::Class' => 1.32,
      'Module::Build'    => 0.4004,
      'Text::Diff'       => 1.37, },
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: Dataclass
# eval: (load-project-state "file-dataclass")
# mode: perl
# tab-width: 3
# End:
