# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.7.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );
use utf8;

use English qw(-no_match_vars);
use File::DataClass::IO;
use Module::Build;
use Test::More;
use Text::Diff;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};

   plan tests => 7;
}

use_ok q(File::Gettext );

my $orig   = catfile( qw(t messages.po) );
my $dumped = io( [ qw(t dumped.messages) ] ); $dumped->unlink;
my $schema = File::Gettext->new( { charset => 'UTF-8',
                                   path => $orig, tempdir => q(t) } );

isa_ok $schema, q(File::Gettext);

my $data = $schema->load;

$schema->dump( { data => $data, path => $dumped } );

my $diff = diff $orig, $dumped->pathname;

ok !$diff, 'Load and dump roundtrips' ; $dumped->unlink;

$schema->dump( { data => $schema->load, path => $dumped } );
$diff = diff $orig, $dumped->pathname;

ok !$diff, 'Load and dump roundtrips 2';

$orig   = catfile( qw(t existing.po) );
$schema = File::Gettext->new( { path => $orig, tempdir => q(t) } );
$data   = $schema->load;

ok $data->{po}->{January}->{msgstr}->[ 0 ] eq 'Januar', 'PO message lookup';

$orig   = catfile( qw(t existing.mo) );
$schema = File::Gettext->new( {
   path => $orig, source_name => q(mo), tempdir => q(t) } );
$data   = $schema->load;

ok $data->{mo}->{January}->{msgstr}->[ 0 ] eq 'Januar', 'MO message lookup';
ok $data->{mo}->{March}->{msgstr}->[ 0 ] eq 'März', 'MO charset decode';

# Cleanup

$dumped->unlink;
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catfile( qw(t file-dataclass-schema.dat) ) )->unlink;

# Local Variables:
# coding: utf-8
# mode: perl
# tab-width: 3
# End:
