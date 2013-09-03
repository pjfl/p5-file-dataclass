# @(#)$Ident: 50json.t 2013-08-16 22:11 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.25.%d', q$Rev: 1 $ =~ /\d+/gmx );
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
use Text::Diff;

use_ok 'File::DataClass::IO';
use_ok 'File::DataClass::Schema';

my $args   = { path          => catfile( qw( t default.json ) ),
               storage_class => 'JSON',
               tempdir       => 't', };
my $schema = File::DataClass::Schema->new( $args );

isa_ok $schema, 'File::DataClass::Schema';

my $dumped = catfile( qw( t dumped.json ) ); io( $dumped )->unlink;

$schema->dump( { data => $schema->load, path => $dumped } );

my $diff = diff catfile( qw( t default.json ) ), $dumped;

ok( !$diff, 'Load and dump roundtrips' ); io( $dumped )->unlink;

$schema->dump( { data => $schema->load, path => $dumped } );

$diff = diff catfile( qw( t default.json ) ), $dumped;

ok( !$diff, 'Load and dump roundtrips 2' );

done_testing;

# Cleanup
io( $dumped )->unlink;
io( catfile( qw( t ipc_srlock.lck ) ) )->unlink;
io( catfile( qw( t ipc_srlock.shm ) ) )->unlink;
io( catfile( qw( t file-dataclass-schema.dat ) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
