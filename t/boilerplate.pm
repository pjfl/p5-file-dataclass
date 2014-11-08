package t::boilerplate;

use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' ), catdir( $Bin, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Module::Build;

my $builder; my $notes = {}; my $perl_ver;

BEGIN {
   $builder   = eval { Module::Build->current };
   $builder and $notes = $builder->notes;
   $perl_ver  = $notes->{min_perl_version} || 5.008;
   $Bin =~ m{ : .+ : }mx and plan skip_all => 'Two colons in $Bin path';
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
