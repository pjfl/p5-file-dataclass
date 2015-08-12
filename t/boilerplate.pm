package t::boilerplate;

use Cwd; # Load early as a workaround to ActiceState bug #104767
use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' ), catdir( $Bin, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Test::Requires { 'Test::Deep' => 0.108 };
use Module::Build;
use Sys::Hostname;
use Test::Deep;

my ($builder, $host, $notes, $perl_ver);

BEGIN {
   $host     = lc hostname;
   $builder  = eval { Module::Build->current };
   $notes    = $builder ? $builder->notes : {};
   $perl_ver = $notes->{min_perl_version} || 5.008;

   if ($notes->{testing}) {
      $Bin =~ m{ : .+ : }mx and plan skip_all => 'Two colons in $Bin path';
      $Test::Deep::VERSION == 0.116
         and plan skip_all => 'Broken Test::Deep distribution 0.116';
   }
}

use Test::Requires "${perl_ver}";
use Test::Requires { Moo => 1.002 };

sub import {
   strict->import;
   $] < 5.008 ? warnings->import : warnings->import( NONFATAL => 'all' );
   return;
}

1;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
