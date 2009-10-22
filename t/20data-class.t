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

   plan tests => 20;
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

my $e = test( $obj, qw(load nonexistant_file) );

is( $e, 'File nonexistant_file cannot open', 'Cannot open nonexistant_file' );

my $cfg = test( $obj, qw(load t/default.xml t/default_en.xml) );

ok( $cfg->{ '_cvs_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 1' );

ok( $cfg->{ '_cvs_lang_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 2' );

ok( ref $cfg->{levels}->{entrance}->{acl} eq q(ARRAY), 'Detects arrays' );

$e = test( $obj, q(create) );

is( $e, 'No file path specified', 'No file path specified' );

my $path = catfile( qw(t default.xml) ); my $args = {};

$args->{path} = $path; $e = test( $obj, q(create), $args );

is( $e, 'No element name specified', 'No element name specified' );

$args->{name} = q(dummy); $e = test( $obj, q(create), $args );

is( $e, 'No element specified', 'No element specified' );

my $schema = $obj->result_source->schema; $schema->element( q(globals) );

my $res = test( $obj, q(create), $args );

ok( !defined $res, 'Creates dummy element but does not insert' );

$schema->attributes( [ qw(text) ] ); $args->{fields}->{text} = q(value1);

$res = test( $obj, q(create), $args );

is( $res, q(dummy), 'Creates dummy element and inserts' );

$args->{fields}->{text} = q(value2);

test( $obj, q(update), $args ); delete $args->{fields};

$res = test( $obj, q(find), $args );

is( $res->text, q(value2), 'Can update and find' );

$e = test( $obj, q(create), $args );

ok( $e =~ m{ already \s+ exists }mx, 'Detects already existing element' );

$res = test( $obj, q(delete), $args );

is( $res, q(dummy), 'Deletes dummy element' );

$e = test( $obj, q(delete), $args );

ok( $e =~ m{ does \s+ not \s+ exist }mx, 'Detects non existing element' );

my $dumped = catfile( qw(t dumped.xml) );

$args = { data => $obj->load( $path ), path => $dumped };

test( $obj, q(dump), $args );

my $diff = diff $path, $dumped;

ok( !$diff, 'Load and dump roundtrips' );

$schema->element( q(fields) ); $schema->attributes( [ qw(width) ] );
$args = { name => q(feedback.body), path => $path };

$res = test( $obj, q(list), $args );

ok( $res->element->width == 72 && scalar @{ $res->list } == 3, 'Can list' );

$schema->element( q(levels) ); $schema->attributes( [ qw(acl state) ] );
$args = { list => q(acl), name => q(admin), path => $path };
$args->{items} = [ qw(group1 group2) ];
$res  = test( $obj, q(push), $args );

ok( $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
    'Can push' );

$args = { criterion => { acl => q(@support) }, path => $path };

my @res = test( $obj, q(search), $args );

ok( $res[0] && $res[0]->name eq q(admin), 'Can search' );

$args = { list => q(acl), name => q(admin), path => $path };
$args->{items} = [ qw(group1 group2) ];
$res  = test( $obj, q(splice), $args );

ok( $res->[0] eq $args->{items}->[0] && $res->[1] eq $args->{items}->[1],
    'Can splice' );

# Cleanup

io( $dumped )->unlink;
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catdir ( qw(t file-dataclass) ) )->rmtree;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
