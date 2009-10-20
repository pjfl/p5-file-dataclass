# @(#)$Id$

my $MODULE     = q(File::DataClass);
my $HOME_PAGE  = q(http://www.roxsoft.co.uk);
my $LICENSE    = q(http://dev.perl.org/licenses/);
my $TRACKER    = q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
my $REQUIRES   = {
   'perl'                     => 5.008,
   'namespace::autoclean'     => 0.09,
   'namespace::clean'         => 0.11,
   'overload'                 => 1.04,
   'version'                  => 0.74,
   'Cache::Cache'             => 1.05,
   'Carp'                     => 0,
   'Class::Accessor::Grouped' => 0.08002,
   'Class::MOP'               => 0.84,
   'Class::Null'              => 1.09,
   'Exception::Class'         => 1.23,
   'Hash::Merge'              => 0.08,
   'File::Path'               => 2.07,
   'File::Temp'               => 0.20,
   'Hash::Merge'              => 0.08,
   'IO::Dir'                  => 1.06,
   'IO::File'                 => 1.14,
   'IPC::SRLock'              => q(0.3.0),
   'JSON'                     => 2.12,
   'Moose'                    => 0.92,
   'MRO::Compat'              => 0.09,
   'Scalar::Util'             => 1.19,
   'Sub::Exporter'            => 0.982,
   'Text::Wrap'               => 2005.082401,
   'TryCatch'                 => 1.002000,
   'XML::Bare'                => 0.30,
   'XML::Simple'              => 2.14,
};

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::Spec::Functions;
use Module::Build;
use SVN::Class ();

sub repository {
   # Accessor for the SVN repository information
   my $file = SVN::Class->svn_file( q(.svn) );

   return unless ($file);

   my $info = $file->info;

   return $info && $info->root !~ m{ \A file: }mx ? $info->root : undef;
}

my $class_path = catfile( q(lib), split m{ :: }mx, $MODULE.q(.pm) );
my $distname   = $MODULE; $distname =~ s{ :: }{-}gmx;
my $repository = repository();
my $resources  = { license => $LICENSE, bugtracker => $TRACKER.$distname, };

$resources->{homepage  } = $HOME_PAGE  if ($HOME_PAGE);
$resources->{repository} = $repository if ($repository);

my $builder = Module::Build->new
   ( add_to_cleanup     => [ q(Debian_CPANTS.txt), $distname.q(-*),
                             map { ( q(*/) x $_ ).q(*~) } 0..5 ],
     build_requires     => { 'Exception::Class'    => 1.23,
                             'Test::More'          => 0.74,
                             'Text::Diff'          => 1.37, },
     configure_requires => { 'version'             => 0.74,
                             'ExtUtils::MakeMaker' => 6.42, },
     create_makefile_pl => q(traditional),
     create_readme      => 1,
     create_packlist    => 0,
     dist_version_from  => $class_path,
     license            => q(perl),
     module_name        => $MODULE,
     no_index           => { directory => [ q(t) ] },
     notes              => { cpan_testers_version => 1 },
     requires           => $REQUIRES,
     resources          => $resources,
     sign               => 1, );

$builder->create_build_script; # Goal

# Local Variables:
# mode: perl
# tab-width: 3
# End:
