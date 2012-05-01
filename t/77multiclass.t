# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.9.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use File::DataClass::IO;
use File::DataClass::Schema;

my $json   = catfile( qw(t default.json) );
my $xml    = catfile( qw(t default_en.xml) );
my $schema = File::DataClass::Schema->new( storage_class => q(MultiClass),
                                           tempdir       => q(t) );

isa_ok $schema, 'File::DataClass::Schema';
isa_ok $schema->storage, 'File::DataClass::Storage::MultiClass';

my $data = $schema->load( $json, $xml );

is $data->{ '_cvs_default' },
   '@(#)$Id: default.xml 474 2008-09-01 22:48:04Z pjf$', 'Json file';
is $data->{ '_cvs_lang_default' },
   '@(#)$Id$', 'XML File';

# Cleanup

io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catfile( qw(t file-dataclass-schema.dat) ) )->unlink;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
