# @(#)$Ident: Build.PL 2013-08-13 17:55 pjf ;

use strict;
use warnings;

use Module::Build;

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

$] >= 5.01 or whimper "Minimum required Perl version is 5.01";

my $code = do { local $/; <DATA> };

Module::Build->subclass( code => $code )->new(
  'module_name' => 'File::DataClass',
  'notes'       => { min_perl_version => 5.01 },
  'share_dir'   => -d 'share' ? 'share' : undef,
##{ $plugin->get_prereqs( 1 ) ##}
)->create_build_script;

exit 0;

__DATA__

sub _normalize_prereqs { # Dynamic config
   my $self = shift; my $p = $self->SUPER::_normalize_prereqs; return $p;
}
