# @(#)$Id$

package Bob;

use strict;
use warnings;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

BEGIN {
   eval { require 5.008; };          $@ and whimper 'Perl minimum 5.8';
   qx(uname -a) =~ m{ higgsboson    }mx and whimper 'Stopped dcollins';
   qx(uname -a) =~ m{ profvince.com }mx and whimper 'Stopped vpit';
   $ENV{PATH}   =~ m{ \A /home/sand }mx and whimper 'Stopped Konig';
}

use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );

use File::Spec::Functions;
use Module::Build;

sub new {
   my ($class, $params) = @_;

   ($params and ref $params eq q(HASH)) or whimper 'No params hash';

   my $module     = $params->{module};
   my $distname   = $module; $distname =~ s{ :: }{-}gmx;
   my $class_path = catfile( q(lib), split m{ :: }mx, $module.q(.pm) );

   return Module::Build->new
      ( add_to_cleanup     => [ q(Debian_CPANTS.txt), $distname.q(-*),
                                map { ( q(*/) x $_ ).q(*~) } 0..5 ],
        build_requires     => $params->{build_requires},
        configure_requires => $params->{configure_requires},
        create_license     => 1,
        create_packlist    => 0,
        create_readme      => 1,
        dist_version_from  => $class_path,
        license            => $params->{license},
        meta_merge         => __get_resources( $params, $distname ),
        module_name        => $module,
        no_index           => __get_no_index( $params ),
        notes              => __get_notes( $params ),
        recommends         => $params->{recommends},
        requires           => $params->{requires},
        sign               => defined $params->{sign} ? $params->{sign} : 1, );
}

# Private subroutines

sub __cpan_testing { !! ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
                     || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) }

sub __get_no_index {
   my $params = shift;

   return { directory => $params->{no_index_dir} || [ qw(examples inc t) ] };
}

sub __get_notes {
   my $params = shift; my $notes = $params->{notes} || {};

   $notes->{stop_tests} = $params->{stop_tests} && __cpan_testing()
                        ? 'CPAN Testing stopped' : 0;

   return $notes;
}

sub __get_repository {
   # Accessor for the SVN repository information
   require SVN::Class;

   my $file = SVN::Class->svn_dir( q(.) ) or return;
   my $info = $file->info or return;
   my $repo = $info->root !~ m{ \A file: }mx ? $info->root : undef;

   return $repo;
}

sub __get_resources {
   my $params     = shift;
   my $distname   = shift;
   my $tracker    = defined $params->{bugtracker}
                  ? $params->{bugtracker}
                  : q(http://rt.cpan.org/NoAuth/Bugs.html?Dist=);
   my $resources  = $params->{resources} || {};
   my $repo;

   $tracker and $resources->{bugtracker} = $tracker.$distname;
   $params->{home_page} and $resources->{homepage} = $params->{home_page};
   $resources->{license} ||= q(http://dev.perl.org/licenses/);

   -f q(MANIFEST.SKIP) and $repo = __get_repository
      and $resources->{repository} = $repo;

   return { resources => $resources };
}

1;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
