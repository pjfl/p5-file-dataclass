# @(#)$Id$

my $MODULE     = q(File::DataClass);
my $HOME_PAGE  = q(http://www.roxsoft.co.uk);
my $LICENSE    = q(http://dev.perl.org/licenses/);
my $TRACKER    = q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
my $RECOMMENDS = {
};
my $REQUIRES   = {
   'perl'                                       => 5.008,
   'version'                                    => 0.74,
   'Carp'                                       => 0,
   'Class::Accessor::Grouped'                   => 0.08002,
   'Class::MOP'                                 => 0.84,
   'Hash::Merge'                                => 0.08,
   'IO::Dir'                                    => 1.06,
   'IO::File'                                   => 1.14,
   'IPC::SRLock'                                => q(0.3.0),
   'JSON'                                       => 2.12,
   'Scalar::Util'                               => 1.19,
   'TryCatch'                                   => 1.002000,
   'XML::Bare'                                  => 0.30,
   'XML::Simple'                                => 2.14,
};

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );

use File::Spec::Functions;
use Module::Build;
use SVN::Class ();

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
                             'Test::More'          => 0.74, },
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
     recommends         => $RECOMMENDS,
     requires           => $REQUIRES,
     resources          => $resources,
     sign               => 1, );

$builder->create_build_script; # Goal

sub repository {
   # Accessor for the SVN repository information
   my $file = SVN::Class->svn_file( q(.svn) );

   return unless ($file);

   my $info = $file->info;

   return $info && $info->root !~ m{ \A file: }mx ? $info->root : undef;
}

# Local Variables:
# mode: perl
# tab-width: 3
# End:
