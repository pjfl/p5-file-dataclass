# @(#)Ident: 17constraints.t 2013-08-16 22:02 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.27.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

use Module::Build;
use Test::More;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";

{  package TC1;

   use Moo;
   use File::DataClass::Types qw( Directory );

   has 'path' => is => 'ro', isa => Directory, coerce => Directory->coercion;
}

{  package TC2;

   use Moo;

   extends 'TC1';
}

my $tc; eval { $tc = TC2->new( path => 't' ) };

ok defined $tc, 'Failed to construct coercion test case';

defined $tc
   and is $tc->path, 't', 'Moose + Inheritance + Type::Tiny + Coercion';

done_testing;

#SKIP: {
#   $reason and $reason =~ m{ \A tests: }mx and skip $reason, 1;
#}

# Local Variables:
# mode: perl
# tab-width: 3
# End:
