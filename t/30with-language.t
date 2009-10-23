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

   plan tests => 10;
   use_ok( q(File::DataClass) );
   use_ok( q(File::DataClass::Schema::WithLanguage) );
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

my $obj = File::DataClass->new
   ( result_source_attributes => {
      schema_attributes => { attributes => [ qw(columns heading) ],
                             element    => q(pages),
                             lang       => q(en),
                             lang_dep   => { qw(heading 1) } },
      schema_class      => q(File::DataClass::Schema::WithLanguage),
     },
     tempdir => q(t) );

isa_ok( $obj, q(File::DataClass) );

my $source = $obj->result_source;

is( $source->schema->lang, q(en), 'Has language attribute' );

my $path = catfile( qw(t default.xml) );

my $rs = $source->resultset( $path ); my $args = {};

$args->{name  } = q(dummy);
$args->{fields}->{columns} = 3;
$args->{fields}->{heading} = q(This is a heading);

my $res = test( $rs, q(create), $args );

is( $res, q(dummy), 'Creates dummy element and inserts' );

$args->{fields}->{columns} = q(2);
$args->{fields}->{heading} = q(This is a heading also);

$res = test( $rs, q(update), $args );

is( $res, q(dummy), 'Can update' );

delete $args->{fields}; $res = test( $rs, q(find), $args );

is( $res->columns, 2, 'Can find' );

my $e = test( $rs, q(create), $args );

ok( $e =~ m{ already \s+ exists }mx, 'Detects already existing element' );

$res = test( $rs, q(delete), $args );

is( $res, q(dummy), 'Deletes dummy element' );

$e = test( $rs, q(delete), $args );

ok( $e =~ m{ does \s+ not \s+ exist }mx, 'Detects non existing element' );

# Cleanup

io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catdir ( qw(t file-dataclass) ) )->rmtree;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
