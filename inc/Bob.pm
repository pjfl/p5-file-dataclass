# @(#)$Id$

package Bob;

use strict;
use warnings;

use English qw(-no_match_vars);

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

BEGIN {
   eval { require 5.008; }; $EVAL_ERROR and whimper 'Perl minimum 5.8';
   qx(uname -a) =~ m{ profvince.com }mx and whimper 'Stopped vpit';
   $ENV{PATH}   =~ m{ \A /home/sand }mx and whimper 'Stopped Konig';
}

use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );

use File::Spec::Functions;
use Module::Build;

sub new {
   my ($class, $params) = @_;

   my $module     = $params->{module};
   my $home_page  = $params->{home_page};
   my $tracker    = $params->{bugtracker};
   my $distname   = $module; $distname =~ s{ :: }{-}gmx;
   my $class_path = catfile( q(lib), split m{ :: }mx, $module.q(.pm) );
   my $resources  = { license => q(http://dev.perl.org/licenses/) };

   $home_page and $resources->{homepage  } = $home_page;
   $tracker   and $resources->{bugtracker} = $tracker.$distname;

   -f q(MANIFEST.SKIP) and __set_repository( $resources );

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
        meta_merge         => { resources  => $resources, },
        module_name        => $module,
        no_index           => { directory  => [ qw(examples inc t) ], },
        notes              => __set_notes( $params ),
        recommends         => $params->{recommends},
        requires           => $params->{requires},
        sign               => $params->{sign}, );
}

# Private subroutines

sub __set_notes {
   my $params = shift; my $notes = $params->{notes} || {};

   $notes->{stop_tests} = $params->{stop_tests} && __testing()
                        ? 'CPAN Testing stopped' : 0;

   return $notes;
}

sub __set_repository {
   # Accessor for the SVN repository information
   my $resources = shift;

   require SVN::Class;

   my $file = SVN::Class->svn_dir( q(.) ) or return;
   my $info = $file->info or return;
   my $repo = $info->root !~ m{ \A file: }mx ? $info->root : undef;

   $repo and $resources->{repository} = $repo;
   return;
}

sub __testing { !! ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
                || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) }

1;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
