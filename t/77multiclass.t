# @(#)$Ident: 77multiclass.t 2013-06-08 18:05 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.23.%d', q$Rev: 1 $ =~ /\d+/gmx );
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

done_testing;

# Cleanup
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catfile( qw(t file-dataclass-schema.dat) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
