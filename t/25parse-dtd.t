# @(#)$Ident: 25parse-dtd.t 2013-04-30 01:34 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.19.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};

   plan tests => 5;
}

use File::DataClass::IO;
use Text::Diff;

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

use_ok( q(File::DataClass::Schema) );

my $path   = catfile( qw(t dtd_test.xml) );
my $dumped = catfile( qw(t dumped.xml) );
my $schema = File::DataClass::Schema->new
   ( cache_class => q(none), path => [ qw(t dtd_test.xml) ], tempdir => q(t) );

isa_ok( $schema, q(File::DataClass::Schema) );

my $data = $schema->load;

ok( $data->{ '_cvs_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 1' );

ok( ref $data->{levels}->{entrance}->{acl} eq q(ARRAY), 'Detects arrays' );

$schema = File::DataClass::Schema->new
   ( cache_class        => q(none),
     path               => [ qw(t dtd_test.xml) ],
     storage_attributes => { force_array => [ qw(fields) ] },
     tempdir            => q(t) );

$data = $schema->load;

ok( ref $data->{fields}->{ 'app_closed.passwd' } eq q(HASH), 'Force array' );

# Cleanup

io( $dumped )->unlink;
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catfile( qw(t file-dataclass-schema.dat) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
