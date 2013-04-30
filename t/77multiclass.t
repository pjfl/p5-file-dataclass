# @(#)$Ident: 77multiclass.t 2013-04-30 01:35 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.18.%d', q$Rev: 1 $ =~ /\d+/gmx );
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
my $schema = File::DataClass::Schema->new( storage_class => q(Any),
                                           tempdir       => q(t) );

isa_ok $schema, 'File::DataClass::Schema';
isa_ok $schema->storage, 'File::DataClass::Storage::Any';

my $data = $schema->load( $json, $xml );

like $data->{ '_cvs_default' }, qr{ default.xml \s 474 }mx, 'Json file';
like $data->{ '_cvs_lang_default' }, qr{ default_en.xml \s 572 }mx, 'XML File';

# Cleanup

io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catfile( qw(t file-dataclass-schema.dat) ) )->unlink;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
