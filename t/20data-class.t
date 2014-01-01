# @(#)$Ident: 20data-class.t 2013-12-31 17:11 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.28.%d', q$Rev: 1 $ =~ /\d+/gmx );
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
use File::DataClass::IO;
use Text::Diff;

sub test {
   my ($obj, $method, @args) = @_; my $wantarray = wantarray; local $EVAL_ERROR;

   my $res = eval {
      $wantarray ? [ $obj->$method( @args ) ] : $obj->$method( @args );
   };

   $EVAL_ERROR and return $EVAL_ERROR; return $wantarray ? @{ $res } : $res;
}

use File::DataClass::Schema;

my $osname     = lc $OSNAME;
my $ntfs       = $osname eq 'mswin32' || $osname eq 'cygwin' ? 1 : 0;
my $path       = catfile( qw( t default.json ) );
my $dumped     = catfile( qw( t dumped.json ) );
my $cache_file = catfile( qw( t file-dataclass-schema.dat ) );
my $schema     = File::DataClass::Schema->new
   ( cache_class => 'none',                   lock_class => 'none',
     path        => [ qw( t default.json ) ], tempdir    => 't' );

isa_ok $schema, 'File::DataClass::Schema';

is $schema->extensions->{ '.json' }->[ 0 ], 'JSON', 'Default extension';

ok !-f $cache_file, 'Cache file not created';

$schema = File::DataClass::Schema->new
   ( path => [ qw( t default.json ) ], tempdir => 't' );

ok !-f $cache_file, 'Cache file not created too early';

my $e = test( $schema, qw( load nonexistant_file ) );

like $e, qr{ \QFile 'nonexistant_file' not found\E }msx,
    'Nonexistant file not found';

is ref $e, 'File::DataClass::Exception', 'Default exception class';

ok -f $cache_file, 'Cache file found'; ! -f $cache_file and warn "${e}\n";

my $data = test( $schema, 'load', $path, catfile( qw( t other.json ) ) );

like $data->{ '_cvs_default' } || q(), qr{ @\(\#\)\$Id: }mx,
   'Has reference element 1';

like $data->{ '_cvs_other' } || q(), qr{ @\(\#\)\$Id: }mx,
   'Has reference element 2';

ok exists $data->{levels}
   && ref $data->{levels}->{admin}->{acl} eq 'ARRAY', 'Detects arrays';

$data = $schema->load( $path ); my $args = { data => $data, path => $dumped };

test( $schema, 'dump', $args ); my $diff = diff $path, $dumped;

ok !$diff, 'Load and dump roundtrips';

$data = File::DataClass::Schema->load( $path );

like $data->{ '_cvs_default' }, qr{ default\.xml }mx, 'Loads from class method';

$e = test( $schema, 'resultset' );

like $e, qr{ \Q'Result source' not specified\E }msx,
   'Result source not specified';

$e = test( $schema, qw( resultset globals ) );

like $e, qr{ \QResult source 'globals' unknown\E }msx, 'Result source unknown';

$schema = File::DataClass::Schema->new
   ( path    => [ qw( t default.json ) ],
     result_source_attributes => {
        globals => { attributes => [ qw( text ) ], }, },
     tempdir => 't' );

is( ($schema->sources)[ 0 ], 'globals', 'Sources' );

my $rs = test( $schema, qw( resultset globals ) );

$args = {}; $e = test( $rs, 'create', $args );

like $e, qr{ \Q'Record name' not specified\E }msx, 'Record name not specified';

$args->{name} = 'dummy'; my $res = test( $rs, 'create', $args );

ok !defined $res, 'Creates dummy element but does not insert';

$args->{text} = 'value1'; $res = test( $rs, 'create', $args );

is $res, 'dummy', 'Creates dummy element and inserts';

$args->{text} = 'value2'; $res = test( $rs, 'update', $args );

is $res, 'dummy', 'Can update';

delete $args->{text}; $res = test( $rs, 'find', $args );

is $res->text, 'value2', 'Can find';

$e = test( $rs, 'create', $args );

like $e, qr{ already \s+ exists }mx, 'Detects already existing element';

$res = test( $rs, 'delete', $args );

is $res, 'dummy', 'Deletes dummy element';

$e = test( $rs, 'delete', $args );

like $e, qr{ \Qdoes not exist\E }mx, 'Detects non existing element';

$args = { name => 'dummy', text => 'value3' };

$res = test( $rs, 'create_or_update', $args );

is $res, 'dummy','Create or update creates';

$args->{text} = 'value4'; $res = test( $rs, 'create_or_update', $args );

is $res, 'dummy','Create or update updates';

$res = test( $rs, 'delete', $args );

is( ($rs->source->columns)[ 0 ], 'text', 'Result source columns' );

is $rs->source->has_column( 'text' ), 1, 'Has column - true';
is $rs->source->has_column( 'nochance' ), 0, 'Has column - false';
is $rs->source->has_column(), 0, 'Has column - undef';

$schema = File::DataClass::Schema->new
   ( path    => [ qw( t default.json ) ],
     result_source_attributes => {
        fields => { attributes => [ qw( width ) ], }, },
     storage_class => '+File::DataClass::Storage::JSON',
     tempdir => 't' );

$rs   = $schema->resultset( 'fields' );
$args = { name => 'feedback.body' };
$res  = test( $rs, 'list', $args );

ok $res->result->width == 72 && scalar @{ $res->list } == 3, 'Can list';

$schema = File::DataClass::Schema->new
   ( path    => [ qw( t default.json ) ],
     result_source_attributes => {
        levels => { attributes => [ qw( acl count state ) ] }, },
     tempdir => 't' );

$rs   = $schema->resultset( 'levels' );
$args = { list => 'acl', name => 'admin' };
$res  = test( $rs, 'push', $args );

like $res, qr{ no \s items }mx, 'Cannot push an empty list';

$args->{items} = [ qw( group1 group2 ) ];
$res  = test( $rs, 'push', $args );

ok $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
   'Can push';

$args = { list => 'acl', name => 'admin' };
$res  = test( $rs, 'splice', $args );

like $res, qr{ no \s items }mx, 'Cannot splice an empty list';

$args->{items} = [ qw( group1 group2 ) ];
$res  = test( $rs, 'splice', $args );

ok $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
   'Can splice';

my @res = test( $rs, 'search', $args = { acl => '@support' } );

ok $res[ 0 ] && $res[ 0 ]->name eq 'admin', 'Can search';
is $rs->search( $args )->first->name, 'admin', 'RS - first';
is $rs->search( $args )->last->name,  'admin', 'RS - last';
is $rs->search( $args )->next->name,  'admin', 'RS - next';

$rs = $schema->resultset( 'levels' );

my $search_rs = $rs->search( $args ); $search_rs->next; $search_rs->reset;

is $search_rs->next->name, 'admin', 'RS - reset';

$rs = $schema->resultset( 'levels' );
is $rs->search( { name => { 'eq' => 'admin' } } )->first->name, 'admin',
   'RS - eq operator';
$rs = $schema->resultset( 'levels' );
is $rs->search( { count => { '==' => '1' } } )->first->name, 'admin',
   'RS - == operator';
$rs = $schema->resultset( 'levels' );
is $rs->search( { name => { 'ne' => 'admin' } } )->first->name, 'library',
   'RS - != operator';
$rs = $schema->resultset( 'levels' );
is $rs->search( { count => { '!=' => '1' } } )->last->name, 'entrance',
   'RS - > operator';
$rs = $schema->resultset( 'levels' );
is $rs->search( { count => { '>' => '1' } } )->last->name, 'entrance',
   'RS - > operator';
$rs = $schema->resultset( 'levels' );
is $rs->search( { count => { '>=' => '2' } } )->last->name, 'entrance',
   'RS - >= operator';
$rs = $schema->resultset( 'levels' );
is $rs->search( { count => { '<' => '3' } } )->last->name, 'entrance',
   'RS - < operator';
$rs = $schema->resultset( 'levels' );
is $rs->search( { count => { '<=' => '2' } } )->last->name, 'entrance',
   'RS - <= operator';
$rs = $schema->resultset( 'levels' );
is $rs->search( { acl => { '=~' => 'port' } } )->first->name, 'admin',
   'RS - match operator';
$rs = $schema->resultset( 'levels' );
is $rs->search( { acl => { '!~' => 'fred' } } )->first->name, 'admin',
   'RS - not match operator';

{  package Dummy;

   sub new { bless { tempdir => 't' }, 'Dummy' }

   sub tempdir { $_[ 0 ]->{tempdir} }
}

use File::DataClass::Constants ();

File::DataClass::Constants->Exception_Class( 'Unexpected' );

$schema = File::DataClass::Schema->new
   ( builder => Dummy->new, path => [ qw( t default.json ) ] );

is ref $schema, q(File::DataClass::Schema),
   'File::DataClass::Schema - with inversion of control';

is $schema->tempdir, 't', 'IOC tempdir';

$e = test( $schema, qw( load nonexistant_file ) );

is ref $e, 'Unexpected', 'Non default exception class';

done_testing;

# Cleanup
io( $dumped )->unlink;
io( $cache_file )->unlink;
io( catfile( qw( t ipc_srlock.lck ) ) )->unlink;
io( catfile( qw( t ipc_srlock.shm ) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
