# @(#)Ident: 17constraints.t 2013-12-21 01:59 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.28.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Module::Build;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";
use English qw( -no_match_vars );

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

use_ok 'File::DataClass::Constants';

eval { File::DataClass::Constants->Exception_Class( 'TC1' ) };

like $EVAL_ERROR, qr{ \A Class \s TC1 \s is \s not \s loaded }mx,
   'Bad exception class';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
