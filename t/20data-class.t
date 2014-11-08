use t::boilerplate;

use Test::More;
use English               qw( -no_match_vars );
use File::DataClass::IO;
use File::Spec::Functions qw( catfile );
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
my $path_ref   = [ 't', 'default.json' ];
my $path       = catfile( @{ $path_ref } );
my $dumped     = catfile( 't', 'dumped.json' );
my $cache_file = catfile( 't', 'file-dataclass-schema.dat' );

io( $path_ref )->is_writable
   or plan skip_all => 'File t/default.json not writable';

my $schema     = File::DataClass::Schema->new
   ( cache_class => 'none',    lock_class => 'none',
     path        => $path_ref, tempdir    => 't' );

isa_ok $schema, 'File::DataClass::Schema';

ok !-f $cache_file, 'Cache file not created';

$schema = File::DataClass::Schema->new( path => $path_ref, tempdir => 't' );

ok !-f $cache_file, 'Cache file not created too early';

my $e = test( $schema, 'load', 'nonexistant_path' );

like $e, qr{ \QPath 'nonexistant_path' not found\E }msx,
    'Nonexistant path not found';

is ref $e, 'File::DataClass::Exception', 'Default exception class';

ok -f $cache_file, 'Cache file found'; ! -f $cache_file and warn "${e}\n";

ok !($schema->cache->set( '_mtimes' ))[ 0 ], 'Cannot use reserved key';

ok $schema->cache->set( 'test', 'data' ), 'Sets cache';

ok !$schema->cache->remove(), 'Cannot remove undefined key';

my $data = test( $schema, 'load', $path, catfile( 't', 'other.json' ) );

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

like $e, qr{ \Q'result source' not specified\E }msx,
   'Result source not specified';

$e = test( $schema, 'resultset', 'globals' );

like $e, qr{ \QResult source 'globals' unknown\E }msx, 'Result source unknown';

$schema = File::DataClass::Schema->new
   ( path                     => $path_ref,
     result_source_attributes => {
        globals               => { attributes => [ 'text' ], }, },
     tempdir                  => 't' );

is( ($schema->sources)[ 0 ], 'globals', 'Sources' );

my $rs = test( $schema, 'resultset', 'globals' );

$args = {}; $e = test( $rs, 'create', $args );

like $e, qr{ \Qnot specified\E }msx, 'Record id not specified';

$e = test( $rs, 'create' );

like $e, qr{ \Qnot specified\E }msx, 'Record id not specified - undefined args';

$args->{id} = 'dummy'; my $res = test( $rs, 'create', $args );

ok !$res, 'Creates dummy record but does not insert';

$args->{text} = 'value1'; $res = test( $rs, 'create', $args );

is $res->id, 'dummy', 'Creates dummy record and inserts';

$args->{text} = 'value2'; $res = test( $rs, 'update', $args );

$res->isa( 'File::DataClass::Exception' ) and warn "${res}";

is $res->id, 'dummy', 'Can update';

delete $args->{text}; $res = test( $rs, 'find', $args );

is $res->text, 'value2', 'Can find';

$e = test( $rs, 'create', $args );

like $e, qr{ already \s+ exists }mx, 'Detects already existing record';

$res = test( $rs, 'delete', $args );

is $res, 'dummy', 'Deletes dummy record';

$e = test( $rs, 'delete', $args );

like $e, qr{ \Qdoes not exist\E }mx, 'Detects non existing record';

$args = { id => 'dummy', text => 'value3' };

$res = test( $rs, 'create_or_update', $args );

is $res->id, 'dummy','Create or update creates';

$args->{text} = 'value4'; $res = test( $rs, 'create_or_update', $args );

is $res->id, 'dummy','Create or update updates';

$res = test( $rs, 'delete', $args );

is( ($rs->result_source->columns)[ 0 ], 'text', 'Result source columns' );

is $rs->result_source->has_column( 'text' ), 1, 'Has column - true';
is $rs->result_source->has_column( 'nochance' ), 0, 'Has column - false';
is $rs->result_source->has_column(), 0, 'Has column - undef';

$schema = File::DataClass::Schema->new
   ( path                     => $path_ref,
     result_source_attributes => {
        fields                => { attributes => [ 'width' ], }, },
     storage_class            => '+File::DataClass::Storage::JSON',
     tempdir                  => 't' );

$rs   = $schema->resultset( 'fields' );
$res  = test( $rs, 'list', { id => 'create-new' } );

is $res->result->id, 'create-new', 'Lists with non existant id';

$res  = test( $rs, 'list', { id => 'feedback.body' } );

ok $res->result->width == 72 && scalar @{ $res->list } == 3, 'Can list';

is $res->result->name, 'feedback.body',
   'Deprecated name attribute use id instead - accessor';
is $res->result->name( 'old_tosh' ), 'old_tosh',
   'Deprecated name attribute use id instead - mutator';

$schema = File::DataClass::Schema->new
   ( path                     => $path_ref,
     result_source_attributes => {
        levels                => { attributes => [ qw( acl count state ) ] }, },
     tempdir                  => 't' );

$rs   = $schema->resultset( 'levels' );
$args = { list => 'acl', id => 'admin' };
$res  = test( $rs, 'push', $args );

like $res, qr{ no \s items }mx, 'Cannot push an empty list';

$args->{items} = [ 'group1', 'group2' ];
$res  = test( $rs, 'push', $args );

ok $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
   'Can push';

$args = { list => 'acl', id => 'admin' };
$res  = test( $rs, 'splice', $args );

like $res, qr{ no \s items }mx, 'Cannot splice an empty list';

$args->{items} = [ 'group1', 'group2' ];
$res  = test( $rs, 'splice', $args );

ok $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
   'Can splice';

my @res = test( $rs, 'search', $args = { acl => '@support' } );

ok $res[ 0 ] && $res[ 0 ]->id eq 'admin', 'Can search';
is $rs->search( $args )->first->id, 'admin', 'RS - first';
is $rs->search( $args )->last->id,  'admin', 'RS - last';
is $rs->search( $args )->next->id,  'admin', 'RS - next';

$rs = $schema->resultset( 'levels' );

my $search_rs = $rs->search( $args ); $search_rs->next; $search_rs->reset;

is $search_rs->next->id, 'admin', 'RS - reset';

sub search {
   my $where = shift; my $rs = $schema->resultset( 'levels' );

   return [ sort map { $_->id } $rs->search( $where )->all ];
}

is_deeply search( { id    => { 'eq' => 'admin' } } ), [ 'admin' ],
   'RS - eq operator';
is_deeply search( { count => { '==' => '1'     } } ), [ 'admin' ],
   'RS - == operator';
is_deeply search( { acl   => { '=~' => 'port'  } } ), [ 'admin' ],
   'RS - =~ operator';
is_deeply search( { acl   => { '!~' => 'port'  } } ), [ 'entrance', 'library' ],
   'RS - !~ operator';
is_deeply search( { id    => { 'ne' => 'admin' } } ), [ 'entrance', 'library' ],
   'RS - ne operator';
is_deeply search( { count => { '!=' => '1'     } } ), [ 'entrance', 'library' ],
   'RS - != operator';
is_deeply search( { count => { '>' => '1'      } } ), [ 'entrance', 'library' ],
   'RS - > operator';
is_deeply search( { count => { '>=' => '2'     } } ), [ 'entrance', 'library' ],
   'RS - >= operator';
is_deeply search( { count => { '<' => '3'      } } ), [ 'admin',   'entrance' ],
   'RS - < operator';
is_deeply search( { count => { '<=' => '2'     } } ), [ 'admin',   'entrance' ],
   'RS - <= operator';

io( $path_ref )->copy( [ 't', 'update.json' ] );

$schema = File::DataClass::Schema->new
   ( path    => [ qw( t update.json ) ],
     result_source_attributes => {
        fields => { attributes => [ qw( width ) ], }, },
     tempdir => 't' );

$rs = $schema->resultset( 'fields' );
$rs = $rs->search( { width => { '>' => '10' } } );
$rs->update( { width => '100' } );
$rs = $schema->resultset( 'fields' );
$rs = $rs->search( { width => { '==' => '100' } } );

is_deeply [ sort map { $_->id } $rs->all ],
   [ 'app_closed.user', 'feedback.body' ], 'Resultset update';

$rs = $schema->resultset( 'fields' );
$rs->find_and_update( { id => 'feedback.body', width => '12' } );
$rs = $schema->resultset( 'fields' );

is $rs->find( 'feedback.body' )->width, 12, 'Find and update';

{  package Dummy;

   sub new { bless { tempdir => 't' }, 'Dummy' }

   sub tempdir { $_[ 0 ]->{tempdir} }
}

use File::DataClass::Constants ();

File::DataClass::Constants->Exception_Class( 'Unexpected' );

$schema = File::DataClass::Schema->new
   ( builder => Dummy->new, path => $path_ref );

is ref $schema, q(File::DataClass::Schema),
   'File::DataClass::Schema - with inversion of control';

is $schema->tempdir, 't', 'IOC tempdir';

$e = test( $schema, qw( load nonexistant_file ) );

is ref $e, 'Unexpected', 'Non default exception class';

done_testing;

# Cleanup
io( $dumped )->unlink;
io( $cache_file )->unlink;
io( [ qw( t update.json ) ] )->unlink;
io( catfile( qw( t ipc_srlock.lck ) ) )->unlink;
io( catfile( qw( t ipc_srlock.shm ) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
