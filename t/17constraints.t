# @(#)Ident: 17constraints.t 2013-06-30 00:43 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.22.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

my $reason;

BEGIN {
   my $builder = eval { Module::Build->current };

   $builder and $reason = $builder->notes->{stop_tests};
   $reason  and $reason =~ m{ \A TESTS: }mx and plan skip_all => $reason;
}

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
