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

   plan tests => 3;
   use_ok( q(File::DataClass) );
}

my $args = {
   result_source_attributes => {
      schema_attributes => {
         storage_class  => q(XML::Bare),
      }
   },
   tempdir => q(t),
};
my $obj = File::DataClass->new( $args );

isa_ok( $obj, q(File::DataClass) );

my $path   = catfile( qw(t default.xml) );
my $dumped = catfile( qw(t dumped) );
my $data   = $obj->load( $path );

$obj->dump( { data => $data, path => $dumped } );

my $diff = diff $path, $dumped;

ok( !$diff, 'Load and dump roundtrips' );

# Cleanup

io( $dumped )->unlink;
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catdir ( qw(t file-dataclass) ) )->rmtree;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
