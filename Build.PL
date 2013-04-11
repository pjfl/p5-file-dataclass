# @(#)$Id$

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev$ =~ /\d+/gmx );

Bob->new( {
   module    => q(File::DataClass),
   home_page => q(http://www.roxsoft.co.uk),
   requires  => {
      'perl'                       => 5.010,
      'namespace::autoclean'       => 0.13,
      'namespace::clean'           => 0.22,
      'overload'                   => 1.04,
      'parent'                     => 0.224,
      'version'                    => 0.74,
      'Cache::FastMmap'            => 1.36,
      'Carp'                       => 0,
      'CHI'                        => 0.33,
      'Class::Null'                => 1.09,
      'Date::Format'               => 2.22,
      'Encode'                     => 2.12,
      'Exception::Class'           => 1.23,
      'File::Path'                 => 2.08,
      'File::Temp'                 => 0.20,
      'Hash::Merge'                => 0.08,
      'IO::Dir'                    => 1.05,
      'IO::File'                   => 1.13,
      'IPC::Cmd'                   => 0.68,
      'JSON'                       => 2.16,
      'Lingua::EN::NameParse'      => 1.28,
      'MealMaster'                 => 0.28,
      'Moose'                      => 2.0801,
      'MooseX::ClassAttribute'     => 0.27,
      'MooseX::Types'              => 0.25,
      'Scalar::Util'               => 1.18,
      'Sub::Exporter'              => 0.982,
      'Sub::Exporter::Progressive' => 0.001006,
      'Template'                   => 2.18,
      'Template::Stash'            => 2.9,
      'Text::Wrap'                 => 2005.082401,
      'Try::Tiny'                  => 0.06,
      'XML::Bare'                  => 0.30,
      'XML::DTD'                   => 0.09,
      'XML::Simple'                => 2.14, },
   recommends         => { 'App::cpanminus'   => 1.6005,
                           'Pod::Markdown'    => 1.322, },
   configure_requires => { 'Module::Build'    => 0.32,
                           'version'          => 0.74, },
   build_requires     => { 'utf8'             => 1.06,
                           'Exception::Class' => 1.23,
                           'Test::More'       => 0.74,
                           'Text::Diff'       => 1.37, },
} )->create_build_script; # Goal!

# Local Variables:
# tab-title: Dataclass
# eval: (load-project-state "file-dataclass")
# mode: perl
# tab-width: 3
# End:
