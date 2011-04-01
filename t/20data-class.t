# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use File::DataClass::IO;
use Module::Build;
use Test::More;
use Text::Diff;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};

   plan tests => 25;
}

sub test {
   my ($obj, $method, @args) = @_; local $EVAL_ERROR;

   my $wantarray = wantarray; my ($e, $res);

   eval {
      if ($wantarray) { @{ $res } = $obj->$method( @args ) }
      else { $res = $obj->$method( @args ) }
   };

   return $e if ($e = $EVAL_ERROR);

   return $wantarray ? @{ $res } : $res;
}

use_ok( q(File::DataClass::Schema) );

my $path       = catfile( qw(t default.xml) );
my $dumped     = catfile( qw(t dumped.xml) );
my $cache_file = catfile( qw(t file-dataclass-schema.dat) );
my $schema     = File::DataClass::Schema->new
   ( simple => 1, path => [ qw(t default.xml) ], tempdir => q(t) );

isa_ok( $schema, q(File::DataClass::Schema) );
ok( ! -f $cache_file, 'Cache file not created' );

$schema = File::DataClass::Schema->new
   ( path => [ qw(t default.xml) ], tempdir => q(t) );

ok( ! -f $cache_file, 'Cache file not created too early' );

my $e = test( $schema, qw(load nonexistant_file) );

ok( -f $cache_file, 'Cache file found' );
is( $e, 'File nonexistant_file cannot open', 'Cannot open nonexistant_file' );

my $data = test( $schema, qw(load t/default.xml t/default_en.xml) );

ok( $data->{ '_cvs_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 1' );

ok( $data->{ '_cvs_lang_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 2' );

ok( ref $data->{levels}->{entrance}->{acl} eq q(ARRAY), 'Detects arrays' );

$data = $schema->load( $path ); my $args = { data => $data, path => $dumped };

test( $schema, q(dump), $args );

my $diff = diff $path, $dumped;

ok( !$diff, 'Load and dump roundtrips' );

$e = test( $schema, q(resultset) );

is( $e, 'Result source not specified', 'Result source not specified' );

$e = test( $schema, q(resultset), q(globals) );

is( $e, 'Result source globals unknown', 'Result source unknown' );

$schema = File::DataClass::Schema->new
   ( path    => [ qw(t default.xml) ],
     result_source_attributes => { globals => {}, },
     tempdir => q(t) );

my $rs = test( $schema, q(resultset), q(globals) );

$args = {}; $e = test( $rs, q(create), $args );

is( $e, 'No element name specified', 'No element name specified' );

$args->{name} = q(dummy);

my $res = test( $rs, q(create), $args );

ok( !defined $res, 'Creates dummy element but does not insert' );

my $source = $schema->source( q(globals) );

$source->attributes( [ qw(text) ] ); $args->{text} = q(value1);

$res = test( $rs, q(create), $args );

is( $res, q(dummy), 'Creates dummy element and inserts' );

$args->{text} = q(value2);

$res = test( $rs, q(update), $args );

is( $res, q(dummy), 'Can update' );

delete $args->{text}; $res = test( $rs, q(find), $args );

is( $res->text, q(value2), 'Can find' );

$e = test( $rs, q(create), $args );

ok( $e =~ m{ already \s+ exists }mx, 'Detects already existing element' );

$res = test( $rs, q(delete), $args );

is( $res, q(dummy), 'Deletes dummy element' );

$e = test( $rs, q(delete), $args );

ok( $e =~ m{ does \s+ not \s+ exist }mx, 'Detects non existing element' );

$schema = File::DataClass::Schema->new
   ( path    => [ qw(t default.xml) ],
     result_source_attributes => { fields => {}, },
     tempdir => q(t) );

$schema->source( q(fields) )->attributes( [ qw(width) ] );
$rs   = $schema->resultset( q(fields) );
$args = { name => q(feedback.body) };
$res  = test( $rs, q(list), $args );

ok( $res->result->width == 72 && scalar @{ $res->list } == 3, 'Can list' );

$schema = File::DataClass::Schema->new
   ( path    => [ qw(t default.xml) ],
     result_source_attributes => { levels => {}, },
     tempdir => q(t) );

$schema->source( q(levels) )->attributes( [ qw(acl state) ] );
$rs   = $schema->resultset( q(levels) );
$args = { list => q(acl), name => q(admin) };
$args->{items} = [ qw(group1 group2) ];
$res  = test( $rs, q(push), $args );

ok( $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
    'Can push' );

$args = { acl => q(@support) };

my @res = test( $rs, q(search), $args );

ok( $res[0] && $res[0]->name eq q(admin), 'Can search' );

$args = { list => q(acl), name => q(admin) };
$args->{items} = [ qw(group1 group2) ];
$res  = test( $rs, q(splice), $args );

ok( $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
    'Can splice' );

my $translate = catfile( qw(t translate.json) ); io( $translate )->unlink;

$args = { from => $path,      from_class => q(XML::Simple),
          to   => $translate, to_class   => q(JSON) };

$e = test( $schema, q(translate), $args );

$diff = diff catfile( qw(t default.json) ), $translate;

ok( !$diff, 'Can translate from XML to JSON' );

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
