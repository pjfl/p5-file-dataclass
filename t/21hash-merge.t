# @(#)Ident: 21hash-merge.t 2013-06-08 18:03 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.24.%d', q$Rev: 1 $ =~ /\d+/gmx );
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

use English qw(-no_match_vars);
use File::DataClass::Schema;

sub test {
   my ($obj, $method, @args) = @_; my $wantarray = wantarray; local $EVAL_ERROR;

   my $res = eval {
      $wantarray ? [ $obj->$method( @args ) ] : $obj->$method( @args );
   };

   $EVAL_ERROR and return $EVAL_ERROR; return $wantarray ? @{ $res } : $res;
}


my $schema = File::DataClass::Schema->new
   ( cache_class              => 'none',
     lock_class               => 'none',
     path                     => [ qw(t default.json) ],
     result_source_attributes => {
        keys                  => {
           attributes         => [ qw(vals) ],
           defaults           => { vals => {} }, }, },
     storage_class            => 'JSON',
     tempdir                  => q(t), );

my $rs   = test( $schema, 'resultset', 'keys' );
my $args = { name => 'dummy', vals => { k1 => 'v1' } };
my $res  = test( $rs, q(create), $args );

is $res, q(dummy), 'Creates dummy element and inserts';

delete $args->{vals}; $res = test( $rs, q(find), $args );

is $res->vals->{k1}, 'v1', 'Finds defined value';

$args->{vals}->{k1} = 0; $res = test( $rs, q(update), $args );

delete $args->{vals}; $res = test( $rs, q(find), $args );

is $res->vals->{k1}, 0, 'Update with false value';

$args->{vals}->{k1} = undef; $res = test( $rs, q(update), $args );

delete $args->{vals}; $res = test( $rs, q(find), $args );

ok( (not exists $res->vals->{k1}), 'Delete attribute from hash' );

$res = test( $rs, q(delete), $args );

is $res, q(dummy), 'Deletes dummy element';

done_testing;

#print qx{ cat t/default.json };

# Local Variables:
# mode: perl
# tab-width: 3
# End:
