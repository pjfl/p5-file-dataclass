# @(#)$Id$

package Bob;

use strict;
use warnings;
use inc::CPANTesting;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

BEGIN { my $reason; $reason = CPANTesting::should_abort and whimper $reason; }

use version; our $VERSION = qv( '1.5' );

use File::Spec::Functions;
use Module::Build;

sub new {
   my ($class, $p) = @_; $p ||= {}; $p->{requires} ||= {};

   my $perl_ver    = $p->{requires}->{perl} || 5.008_008;

   $] < $perl_ver and whimper "Perl minimum ${perl_ver}";

   my $module      = $p->{module} or whimper 'No module name';
   my $distname    = $module; $distname =~ s{ :: }{-}gmx;
   my $class_path  = catfile( q(lib), split m{ :: }mx, $module.q(.pm) );

   return __get_build_class( $p )->new
      ( add_to_cleanup     => __get_cleanup_list( $p, $distname ),
        build_requires     => $p->{build_requires},
        configure_requires => $p->{configure_requires},
        create_license     => 1,
        create_packlist    => 0,
        create_readme      => 1,
        dist_version_from  => $class_path,
        license            => $p->{license} || q(perl),
        meta_merge         => __get_resources( $p, $distname ),
        module_name        => $module,
        no_index           => __get_no_index( $p ),
        notes              => __get_notes( $p ),
        recommends         => $p->{recommends},
        requires           => $p->{requires},
        sign               => defined $p->{sign} ? $p->{sign} : 1, );
}

# Private functions

sub __get_build_class { # Which subclass of M::B should we create?
   my $p = shift; exists $p->{build_class} and return $p->{build_class};

   return Module::Build->subclass( code => q{
      use Pod::Select;

      sub ACTION_distmeta {
         my $self = shift;

         $self->notes->{create_readme_pod} and podselect( {
            -output => q(README.pod) }, $self->dist_version_from );

         return $self->SUPER::ACTION_distmeta;
      }
   } );
}

sub __get_cleanup_list {
   my $p = shift; my $distname = shift;

   return [ q(Debian_CPANTS.txt), "${distname}-*",
            map { ( q(*/) x $_ ).q(*~) } 0..5 ];
}

sub __get_git_repository {
   my ($info, $repo, $vcs); require Git::Class;

   $vcs = Git::Class::Worktree->new( path => q(.) )
      and $info = $vcs->git( q(remote) )
      and $repo = ($info !~ m{ \A file: }mx) ? $info : undef
      and return $repo;

   return;
}

sub __get_no_index {
   my $p = shift;

   return { directory => $p->{no_index_dir} || [ qw(examples inc t) ] };
}

sub __get_notes {
   my $p = shift; my $notes = exists $p->{notes} ? $p->{notes} : {};

   $notes->{create_readme_pod} = $p->{create_readme_pod} || 0;
   $notes->{stop_tests} = CPANTesting::test_exceptions( $p );

   return $notes;
}

sub __get_repository { # Accessor for the VCS repository information
   my $repo;

   -d q(.svn) and $repo = __get_svn_repository() and return $repo;
   -d q(.git) and $repo = __get_git_repository() and return $repo;

   return;
}

sub __get_resources {
   my $p         = shift;
   my $distname  = shift;
   my $tracker   = defined $p->{bugtracker}
                 ? $p->{bugtracker}
                 : q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
   my $resources = $p->{resources} || {};
   my $repo;

   $tracker and $resources->{bugtracker} = $tracker.$distname;
   $p->{home_page} and $resources->{homepage} = $p->{home_page};
   $resources->{license} ||= q(http://dev.perl.org/licenses/);

   # Only get repository info when authoring a distribution
   -f q(MANIFEST.SKIP) and $repo = __get_repository
      and $resources->{repository} = $repo;

   return { resources => $resources };
}

sub __get_svn_repository {
   my ($info, $repo, $vcs); require SVN::Class;

   $vcs = SVN::Class::svn_dir( q(.) )
      and $info = $vcs->info
      and $repo = ($info->root !~ m{ \A file: }mx) ? $info->root : undef
      and return $repo;

   return;
}

1;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
