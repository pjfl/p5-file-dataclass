# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use File::DataClass::IO;
use Test::More;
use Text::Diff;

BEGIN {
   if ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
       || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) {
      plan skip_all => q(CPAN Testing stopped);
   }

   plan tests => 22;
   use_ok( q(File::DataClass) );
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

my $obj = File::DataClass->new( tempdir => q(t) );

isa_ok( $obj, q(File::DataClass) );

my $source = $obj->result_source;
my $e      = test( $source, qw(load nonexistant_file) );

is( $e, 'File nonexistant_file cannot open', 'Cannot open nonexistant_file' );

my $data = test( $source, qw(load t/default.xml t/default_en.xml) );

ok( $data->{ '_cvs_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 1' );

ok( $data->{ '_cvs_lang_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 2' );

ok( ref $data->{levels}->{entrance}->{acl} eq q(ARRAY), 'Detects arrays' );

my $path   = catfile( qw(t default.xml) );
my $dumped = catfile( qw(t dumped.xml) );

$data = $source->load( $path ); my $args = { data => $data, path => $dumped };

test( $source, q(dump), $args );

my $diff = diff $path, $dumped;

ok( !$diff, 'Load and dump roundtrips' );

$e = test( $source, q(resultset) );

is( $e, 'No file path specified', 'No file path specified' );

my $rs = $source->resultset( { path => $path } );

$args = {}; $e = test( $rs, q(create), $args );

is( $e, 'No element name specified', 'No element name specified' );

$args->{name} = q(dummy); $e = test( $rs, q(create), $args );

is( $e, 'No element specified', 'No element specified' );

my $schema = $source->schema; $schema->element( q(globals) );

my $res = test( $rs, q(create), $args );

ok( !defined $res, 'Creates dummy element but does not insert' );

$schema->attributes( [ qw(text) ] ); $args->{fields}->{text} = q(value1);

$res = test( $rs, q(create), $args );

is( $res, q(dummy), 'Creates dummy element and inserts' );

$args->{fields}->{text} = q(value2);

$res = test( $rs, q(update), $args );

is( $res, q(dummy), 'Can update' );

delete $args->{fields}; $res = test( $rs, q(find), $args );

is( $res->text, q(value2), 'Can find' );

$e = test( $rs, q(create), $args );

ok( $e =~ m{ already \s+ exists }mx, 'Detects already existing element' );

$res = test( $rs, q(delete), $args );

is( $res, q(dummy), 'Deletes dummy element' );

$e = test( $rs, q(delete), $args );

ok( $e =~ m{ does \s+ not \s+ exist }mx, 'Detects non existing element' );

$schema->element( q(fields) ); $schema->attributes( [ qw(width) ] );
$args = { name => q(feedback.body), path => $path };

$res = test( $rs, q(list), $args );

ok( $res->element->width == 72 && scalar @{ $res->list } == 3, 'Can list' );

$schema->element( q(levels) ); $schema->attributes( [ qw(acl state) ] );
$args = { list => q(acl), name => q(admin), path => $path };
$args->{items} = [ qw(group1 group2) ];
$res  = test( $rs, q(push), $args );

ok( $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
    'Can push' );

$args = { criterion => { acl => q(@support) }, path => $path };

my @res = test( $rs, q(search), $args );

ok( $res[0] && $res[0]->name eq q(admin), 'Can search' );

$args = { list => q(acl), name => q(admin), path => $path };
$args->{items} = [ qw(group1 group2) ];
$res  = test( $rs, q(splice), $args );

ok( $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
    'Can splice' );

my $translate = catfile( qw(t translate.json) );

$args = { from => $path,      from_class => q(XML::Simple),
          to   => $translate, to_class   => q(JSON) };

test( $obj, q(translate), $args );

$diff = diff catfile( qw(t default.json) ), $translate;

ok( !$diff, 'Can translate from XML to JSON' );

# Cleanup

io( $dumped    )->unlink;
io( $translate )->unlink;
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catdir ( qw(t file-dataclass) ) )->rmtree;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
