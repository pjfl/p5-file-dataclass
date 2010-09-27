# @(#)$Id$
# Definitions

my $SIGN      = 1;
my $LICENSE   = q(perl);
my $MODULE    = q(File::DataClass);
my $HOME_PAGE = q(http://www.roxsoft.co.uk);
my $TRACKER   = q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
my $REQUIRES  = {
   'perl'                   => 5.008,
   'namespace::autoclean'   => 0.09,
   'namespace::clean'       => 0.11,
   'overload'               => 1.04,
   'version'                => 0.74,
   'Carp'                   => 0,
   'CHI'                    => 0.33,
   'Class::MOP'             => 0.84,
   'Class::Null'            => 1.09,
   'Data::Section'          => 0.093410,
   'Date::Format'           => 2.22,
   'Exception::Class'       => 1.23,
   'Hash::Merge'            => 0.08,
   'File::Path'             => 2.07,
   'File::Temp'             => 0.20,
   'Hash::Merge'            => 0.08,
   'IO::Dir'                => 1.06,
   'IO::File'               => 1.14,
   'IPC::SRLock'            => q(0.3.0),
   'JSON'                   => 2.16,
   'MealMaster'             => 0.28,
   'Moose'                  => 0.92,
   'MooseX::ClassAttribute' => 0.10,
   'MRO::Compat'            => 0.09,
   'Scalar::Util'           => 1.19,
   'Sub::Exporter'          => 0.982,
   'Template'               => 2.18,
   'Template::Stash'        => 2.9,
   'Text::Wrap'             => 2005.082401,
   'Try::Tiny'              => 0.06,
   'XML::Bare'              => 0.30,
   'XML::DTD'               => 0.09,
   'XML::Simple'            => 2.14,
};

# Boilerplate

use strict;
use warnings;

use English qw( -no_match_vars );

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

BEGIN {
   eval { require 5.008; }; $EVAL_ERROR and whimper 'Perl minimum 5.8';
}

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::Spec::Functions;
use Module::Build;

sub repository {
   # Accessor for the SVN repository information
   require SVN::Class;

   my $file = SVN::Class->svn_file( q(.svn) ) or return;
   my $info = $file->info;

   return $info && $info->root !~ m{ \A file: }mx ? $info->root : undef;
}

my $class_path = catfile( q(lib), split m{ :: }mx, $MODULE.q(.pm) );
my $distname   = $MODULE; $distname =~ s{ :: }{-}gmx;
my $resources  = { license => q(http://dev.perl.org/licenses/) };

$HOME_PAGE and $resources->{homepage  } = $HOME_PAGE;
$TRACKER   and $resources->{bugtracker} = $TRACKER.$distname,

-f q(MANIFEST.SKIP) and $resources->{repository} = repository();

Module::Build->new
   ( add_to_cleanup     => [ q(Debian_CPANTS.txt), $distname.q(-*),
                             map { ( q(*/) x $_ ).q(*~) } 0..5 ],
     build_requires     => { 'Exception::Class' => 1.23,
                             'Test::More'       => 0.74,
                             'Text::Diff'       => 1.37, },
     configure_requires => { 'Module::Build'    => 0.32,
                             'version'          => 0.74, },
     create_packlist    => 0,
     create_readme      => 1,
     dist_version_from  => $class_path,
     license            => $LICENSE,
     module_name        => $MODULE,
     no_index           => { directory => [ qw(t) ] },
     requires           => $REQUIRES,
     resources          => $resources,
     sign               => $SIGN, )->create_build_script; # Goal

# Local Variables:
# mode: perl
# tab-width: 3
# End:
