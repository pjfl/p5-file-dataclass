# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;
use Text::Diff;

BEGIN {
   if ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
       || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) {
      plan skip_all => q(CPAN Testing stopped);
   }

   plan tests => 18;
   use_ok( q(File::DataClass) );
}

sub test {
   my ($file, $method, @rest) = @_; local $EVAL_ERROR;

   my $wantarray = wantarray; my ($e, $res);

   eval {
      if ($wantarray) { @{ $res } = $file->$method( @rest ) }
      else { $res = $file->$method( @rest ) }
   };

   return $e if ($e = $EVAL_ERROR);

   return $wantarray ? @{ $res } : $res;
}

my $file = File::DataClass->new( tempdir => q(t) );

isa_ok( $file, q(File::DataClass) );

my $e = test( $file, qw(load nonexistant_file) );

is( $e, 'Cannot open nonexistant_file', 'Cannot open nonexistant_file' );

my $cfg = test( $file, qw(load t/default.xml t/default_en.xml) );

ok( $cfg->{ '_cvs_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 1' );

ok( $cfg->{ '_cvs_lang_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 2' );

ok( ref $cfg->{levels}->{entrance}->{acl} eq q(ARRAY), 'Detects arrays' );

$e = test( $file, q(create) );

is( $e, 'No element name specified', 'No element name specified' );

my $args = {}; $args->{name} = q(dummy); $e = test( $file, q(create), $args );

is( $e, 'No file path specified', 'No file path specified' );

$args->{path} = q(t/default.xml); $e = test( $file, q(create), $args );

is( $e, 'No element specified', 'No element specified' );

my $schema = $file->result_source->schema; $schema->element( q(globals) );

my $res = test( $file, q(create), $args );

ok( !defined $res, 'Creates dummy element but does not insert' );

$schema->attributes( [ qw(text) ] ); $args->{fields}->{text} = q(value1);

$res = test( $file, q(create), $args );

is( $res, q(dummy), 'Creates dummy element and inserts' );

$args->{fields}->{text} = q(value2);

test( $file, q(update), $args ); delete $args->{fields};

$res = test( $file, q(find), $args );

is( $res->text, q(value2), 'Can update and find' );

$e = test( $file, q(create), $args );

ok( $e =~ m{ already \s+ exists }mx, 'Detects already existing element' );

$res = test( $file, q(delete), $args );

is( $res, q(dummy), 'Deletes dummy element' );

$e = test( $file, q(delete), $args );

ok( $e =~ m{ does \s+ not \s+ exist }mx, 'Detects non existing element' );

$args = { data => $file->load( q(t/default.xml) ), path => q(t/dumped.xml) };

test( $file, q(dump), $args );

my $diff = diff q(t/default.xml), q(t/dumped.xml);

ok( !$diff, 'Load and dump roundtrips' );

$schema->element( q(fields) ); $schema->attributes( [ qw(width) ] );
$args = { name => q(feedback.body), path => q(t/default.xml) };

$res = test( $file, q(list), $args );

ok( $res->element->width == 72 && scalar @{ $res->list } == 3, 'Can list' );

# push

$schema->element( q(levels) ); $schema->attributes( [ qw(acl state) ] );
$args = { path => q(t/default.xml), criterion => { acl => q(@support) } };

my @res = test( $file, q(search), $args );

ok( $res[0] && $res[0]->name eq q(admin), 'Can search' );

# splice

unlink( q(t/dumped.xml) );
unlink( q(t/ipc_srlock.lck) );
unlink( q(t/ipc_srlock.shm) );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
