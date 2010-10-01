# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use File::DataClass::IO;
use Module::Build;
use Test::More;
use Text::Diff;

BEGIN {
   Module::Build->current->notes->{stop_tests}
      and plan skip_all => q(CPAN Testing stopped);

   plan tests => 4;
}

use_ok( q(File::MailAlias) );

my $args   = { path => [ qw(t aliases) ], tempdir => q(t) };
my $schema = File::MailAlias->new( $args );

isa_ok( $schema, q(File::MailAlias) );

my $dumped = catfile( qw(t dumped.aliases) ); io( $dumped )->unlink;

$schema->dump( { data => $schema->load, path => $dumped } );

my $diff = diff catfile( qw(t aliases) ), $dumped;

ok( !$diff, 'Load and dump roundtrips' ); io( $dumped )->unlink;

$schema->dump( { data => $schema->load, path => $dumped } );

$diff = diff catfile( qw(t aliases) ), $dumped;

ok( !$diff, 'Load and dump roundtrips 2' );

# Cleanup

io( $dumped )->unlink;
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catfile( qw(t file-dataclass-schema.dat) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
