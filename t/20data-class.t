# @(#)$Ident: 20data-class.t 2013-10-21 15:05 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.26.%d', q$Rev: 2 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir catfile updir );
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
my $path       = catfile( qw( t default.xml ) );
my $dumped     = catfile( qw( t dumped.xml ) );
my $cache_file = catfile( qw( t file-dataclass-schema.dat ) );
my $schema     = File::DataClass::Schema->new
   ( cache_class => 'none',                  lock_class => 'none',
     path        => [ qw( t default.xml ) ], tempdir    => 't' );

isa_ok $schema, 'File::DataClass::Schema';

ok ! -f $cache_file, 'Cache file not created';

$schema = File::DataClass::Schema->new
   ( path => [ qw( t default.xml ) ], tempdir => 't' );

ok ! -f $cache_file, 'Cache file not created too early';

my $e = test( $schema, qw( load nonexistant_file ) );

like $e, qr{ \QFile 'nonexistant_file' cannot open\E }msx,
    'Cannot open nonexistant_file';

is ref $e, 'File::DataClass::Exception', 'Default exception class';

ok -f $cache_file, 'Cache file found'; ! -f $cache_file and warn "${e}\n";

my $data = test( $schema, qw(load t/default.xml t/default_en.xml) );

like $data->{ '_cvs_default' } || q(), qr{ @\(\#\)\$Id: }mx,
   'Has reference element 1';

like $data->{ '_cvs_lang_default' } || q(), qr{ @\(\#\)\$Id: }mx,
   'Has reference element 2';

ok exists $data->{levels}
   && ref $data->{levels}->{entrance}->{acl} eq 'ARRAY', 'Detects arrays';

$data = $schema->load( $path ); my $args = { data => $data, path => $dumped };

test( $schema, q(dump), $args ); my $diff = diff $path, $dumped;

ok ! $diff, 'Load and dump roundtrips';

$e = test( $schema, q(resultset) );

like $e, qr{ \QResult source not specified\E }msx,
   'Result source not specified';

$e = test( $schema, q(resultset), q(globals) );

like $e, qr{ \QResult source 'globals' unknown\E }msx, 'Result source unknown';

$schema = File::DataClass::Schema->new
   ( path    => [ qw(t default.xml) ],
     result_source_attributes => {
        globals => { attributes => [ qw(text) ], }, },
     tempdir => q(t) );

my $rs = test( $schema, q(resultset), q(globals) );

$args = {}; $e = test( $rs, q(create), $args );

like $e, qr{ \QNo element name specified\E }msx, 'No element name specified';

$args->{name} = q(dummy); my $res = test( $rs, q(create), $args );

ok ! defined $res, 'Creates dummy element but does not insert';

$args->{text} = q(value1); $res = test( $rs, q(create), $args );

is $res, q(dummy), 'Creates dummy element and inserts';

$args->{text} = q(value2); $res = test( $rs, q(update), $args );

is $res, q(dummy), 'Can update';

delete $args->{text}; $res = test( $rs, q(find), $args );

is $res->text, q(value2), 'Can find';

$e = test( $rs, q(create), $args );

like $e, qr{ already \s+ exists }mx, 'Detects already existing element';

$res = test( $rs, q(delete), $args );

is $res, q(dummy), 'Deletes dummy element';

$e = test( $rs, q(delete), $args );

like $e, qr{ does \s+ not \s+ exist }mx, 'Detects non existing element';

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
   ( path    => [ qw(t default.xml) ],
     result_source_attributes => {
        fields => { attributes => [ qw(width) ], }, },
     tempdir => q(t) );

$rs   = $schema->resultset( q(fields) );
$args = { name => q(feedback.body) };
$res  = test( $rs, q(list), $args );

ok $res->result->width == 72 && scalar @{ $res->list } == 3, 'Can list';

$schema = File::DataClass::Schema->new
   ( path    => [ qw(t default.xml) ],
     result_source_attributes => {
        levels => { attributes => [ qw(acl state) ] }, },
     tempdir => q(t) );

$rs   = $schema->resultset( q(levels) );
$args = { list => q(acl), name => q(admin) };
$args->{items} = [ qw(group1 group2) ];
$res  = test( $rs, q(push), $args );

ok $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
   'Can push';

$args = { acl => q(@support) };

my @res = test( $rs, q(search), $args );

ok $res[ 0 ] && $res[ 0 ]->name eq q(admin), 'Can search';

is $rs->search( $args )->first->name, 'admin', 'RS - first';
is $rs->search( $args )->last->name, 'admin', 'RS - last';
is $rs->search( $args )->next->name, 'admin', 'RS - next';

$args = { list => q(acl), name => q(admin) };
$args->{items} = [ qw(group1 group2) ];
$res  = test( $rs, q(splice), $args );

ok $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
   'Can splice';

my $translate = catfile( qw(t translate.json) ); io( $translate )->unlink;

$args = { from => $path,      from_class => q(XML::Simple),
          to   => $translate, to_class   => q(JSON) };

$e = test( $schema, q(translate), $args );

$diff = diff catfile( qw(t default.json) ), $translate;

ok ! $diff, 'Can translate from XML to JSON';

{  package Dummy;

   sub new { bless { tempdir => q(t) }, q(Dummy) }

   sub tempdir { $_[ 0 ]->{tempdir} }
}

use File::DataClass::Constants ();

File::DataClass::Constants->Exception_Class( q(Unexpected) );

$schema = File::DataClass::Schema->new
   ( builder => Dummy->new, path => [ qw(t default.xml) ] );

is ref $schema, q(File::DataClass::Schema),
   'File::DataClass::Schema - with inversion of control';

is $schema->tempdir, q(t), 'IOC tempdir';

$e = test( $schema, qw(load nonexistant_file) );

is ref $e, q(Unexpected), 'Non default exception class';

done_testing;

# Cleanup
io( $dumped     )->unlink;
io( $translate  )->unlink;
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( $cache_file )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
