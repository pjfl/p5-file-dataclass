# @(#)$Ident: 77multiclass.t 2013-08-16 22:12 pjf ;

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

use_ok 'File::DataClass::IO';
use_ok ' File::DataClass::Schema';

my $json   = catfile( qw( t default.json ) );
my $xml    = catfile( qw( t default_en.xml ) );
my $schema = File::DataClass::Schema->new( storage_class => 'Any',
                                           tempdir       => 't' );

isa_ok $schema, 'File::DataClass::Schema';
isa_ok $schema->storage, 'File::DataClass::Storage::Any';

my $data = $schema->load( $json, $xml );

like $data->{ '_cvs_default' }, qr{ default.xml \s 474 }mx, 'Json file';
like $data->{ '_cvs_lang_default' }, qr{ default_en.xml \s 572 }mx, 'XML File';

done_testing;

# Cleanup
io( catfile( qw( t ipc_srlock.lck ) ) )->unlink;
io( catfile( qw( t ipc_srlock.shm ) ) )->unlink;
io( catfile( qw( t file-dataclass-schema.dat ) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
