# @(#)$Id: 20data-class.t 190 2010-01-12 17:57:10Z pjf $

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 190 $ =~ /\d+/gmx );
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

   plan tests => 4;
   use_ok( q(File::DataClass::Schema) );
}

sub test {
   my ($obj, $method, @args) = @_; local $EVAL_ERROR;

   my $wantarray = wantarray; my $res;

   eval {
      if ($wantarray) { @{ $res } = $obj->$method( @args ) }
      else { $res = $obj->$method( @args ) }
   };

   $EVAL_ERROR and return $EVAL_ERROR;

   return $wantarray ? @{ $res } : $res;
}

my $path   = catfile( qw(t dtd_test.xml) );
my $dumped = catfile( qw(t dumped.xml) );
my $schema = File::DataClass::Schema->new
   ( path => [ qw(t dtd_test.xml) ], tempdir => q(t) );

isa_ok( $schema, q(File::DataClass::Schema) );

my $data = $schema->load;

ok( $data->{ '_cvs_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 1' );

ok( ref $data->{levels}->{entrance}->{acl} eq q(ARRAY), 'Detects arrays' );

# Cleanup

io( $dumped )->unlink;
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catfile( qw(t file-dataclass-schema.dat) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
