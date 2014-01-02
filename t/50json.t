# @(#)$Ident: 50json.t 2013-12-30 19:34 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.30.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir catfile updir );
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
use Text::Diff;

sub test {
   my ($obj, $method, @args) = @_; my $wantarray = wantarray; local $EVAL_ERROR;

   my $res = eval {
      $wantarray ? [ $obj->$method( @args ) ] : $obj->$method( @args );
   };

   $EVAL_ERROR and return $EVAL_ERROR; return $wantarray ? @{ $res } : $res;
}

use_ok 'File::DataClass::IO';
use_ok 'File::DataClass::Schema';

my $path   = catfile( qw( t default.json ) );
my $schema = File::DataClass::Schema->new
   (  path          => $path,
      result_source_attributes => {
         globals    => { attributes => [ qw( text ) ], }, },
      storage_class => 'Any',
      tempdir       => 't' );

isa_ok $schema, 'File::DataClass::Schema';
is $schema->storage->extn, undef, 'Undefined extension';
is $schema->storage->meta_pack( 1 )->{mtime}, 1, 'Storage meta pack';
is $schema->storage->meta_unpack( { mtime => 1 } ), 1, 'Storage meta unpack';
is $schema->storage->meta_pack()->{mtime}, 1, 'Storage meta pack - cached';
is scalar keys %{ $schema->storage->load() }, 0, 'Storage load empty default';

my $dumped = catfile( qw( t dumped.json ) ); io( $dumped )->unlink;

$schema->dump( { data => $schema->load, path => $dumped } );

my $diff = diff $path, $dumped;

ok !$diff, 'Load and dump roundtrips'; io( $dumped )->unlink;

$schema->dump( { data => $schema->load, path => $dumped } );

$diff = diff $path, $dumped;

ok !$diff, 'Load and dump roundtrips 2';

my $data = test( $schema, 'load', $path, catfile( qw( t other.json ) ) );

like $data->{ '_cvs_default' } || q(), qr{ @\(\#\)\$Id: }mx,
   'Has reference element 1';

like $data->{ '_cvs_other' } || q(), qr{ @\(\#\)\$Id: }mx,
   'Has reference element 2';

my $rs   = test( $schema, qw( resultset globals ) );
my $args = { name => 'dummy', text => 'value3' };

is test( $rs, 'create_or_update', $args ), 'dummy','Create or update creates';

$args->{text} = 'value4';

is test( $rs, 'create_or_update', $args ), 'dummy','Create or update updates';

my $result = $rs->find( { name => 'dummy' } );

is test( $rs, 'delete', $args ), 'dummy', 'Deletes';

$schema->storage->create_or_update( io( $path ), $result, 1, sub { 1 } );

is test( $rs, 'delete', $args ), 'dummy', 'Deletes again';

$schema->storage->validate_params( io( $path ), 'globals' );

my $translate = catfile( qw( t translate.json ) ); io( $translate )->unlink;

$args = { from => $path,      from_class => 'JSON',
          to   => $translate, to_class   => 'JSON', };

my $e = test( $schema, 'translate', $args ); $diff = diff $path, $translate;

ok !$diff, 'Can translate from JSON to JSON';

File::DataClass::Schema->translate( { from => $path, to => $translate } );

ok !$diff, 'Can translate from JSON to JSON - class method';

done_testing;

# Cleanup
io( $dumped )->unlink;
io( $translate )->unlink;
io( catfile( qw( t ipc_srlock.lck ) ) )->unlink;
io( catfile( qw( t ipc_srlock.shm ) ) )->unlink;
io( catfile( qw( t file-dataclass-schema.dat ) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
