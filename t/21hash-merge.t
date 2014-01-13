# @(#)Ident: 21hash-merge.t 2013-12-29 03:29 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.31.%d', q$Rev: 1 $ =~ /\d+/gmx );
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

use_ok 'File::DataClass::Schema';

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
     path                     => [ qw( t default.json ) ],
     result_source_attributes => {
        keys                  => {
           attributes         => [ qw( vals ) ],
           defaults           => { vals => {} }, }, },
     storage_class            => 'JSON',
     tempdir                  => 't', );

my $rs   = test( $schema, 'resultset', 'keys' );
my $args = { name => 'dummy', vals => { k1 => 'v1' } };
my $res  = test( $rs, 'create', $args );

is $res, q(dummy), 'Creates dummy element and inserts';

delete $args->{vals}; $res = test( $rs, 'find', $args );

is $res->vals->{k1}, 'v1', 'Finds defined value';

$args->{vals}->{k1} = 0; $res = test( $rs, 'update', $args );

delete $args->{vals}; $res = test( $rs, 'find', $args );

is $res->vals->{k1}, 0, 'Update with false value';

$args->{vals}->{k1} = undef; $res = test( $rs, 'update', $args );

delete $args->{vals}; $res = test( $rs, 'find', $args );

ok( (not exists $res->vals->{k1}), 'Delete attribute from hash' );

$res = test( $rs, 'delete', $args );

is $res, 'dummy', 'Deletes dummy element';

use_ok 'File::DataClass::HashMerge';

my $dest = {};
my $src  = { key => 'value', };

File::DataClass::HashMerge->merge( \$dest, $src );

is $dest->{key}, 'value', 'Default merge filter';

File::DataClass::HashMerge->merge( \$dest );

is $dest->{key}, 'value', 'No source required';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
