# @(#)$Ident: 40xml-bare.t 2013-06-08 18:04 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.22.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

my $reason;

BEGIN {
   my $builder = eval { Module::Build->current };

   $builder and $reason = $builder->notes->{stop_tests};
   $reason  and $reason =~ m{ \A TESTS: }mx and plan skip_all => $reason;
}

use English qw(-no_match_vars);
use File::DataClass::IO;
use Text::Diff;

use_ok( q(File::DataClass::Schema) );

my $args   = { path          => q(t/default.xml),
               storage_class => q(XML::Bare),
               tempdir       => q(t), };
my $schema = File::DataClass::Schema->new( $args );

isa_ok( $schema, q(File::DataClass::Schema) );

my $dumped = catfile( qw(t dumped.xml) ); io( $dumped )->unlink;

$schema->dump( { data => $schema->load, path => $dumped } );

my $diff = diff catfile( qw(t default.xml) ), $dumped;

ok( !$diff, 'Load and dump roundtrips' ); io( $dumped )->unlink;

$schema->dump( { data => $schema->load, path => $dumped } );

$diff = diff catfile( qw(t default.xml) ), $dumped;

ok( !$diff, 'Load and dump roundtrips 2' );

done_testing;

# Cleanup
io( $dumped )->unlink;
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catfile( qw(t file-dataclass-schema.dat) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
