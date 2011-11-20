# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use File::DataClass::IO;
use Module::Build;
use Test::More;
use Text::Diff;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};

   plan tests => 15;
}

sub test {
   my ($obj, $method, @args) = @_; local $EVAL_ERROR;

   my $wantarray = wantarray; my $res;

   eval {
      if ($wantarray) { @{ $res } = $obj->$method( @args ) }
      else { $res = $obj->$method( @args ) }
   };

   my $e = $EVAL_ERROR; $e and return $e;

   return $wantarray ? @{ $res } : $res;
}

use_ok( q(File::DataClass::Schema) );
use_ok( q(File::DataClass::ResultSource::WithLanguage) );
use_ok( q(File::Gettext) );

my $default = catfile( qw(t default.xml) );
my $schema  = File::DataClass::Schema->new
   ( path => $default,
     result_source_attributes => {
        pages => {
           attributes => [ qw(columns heading) ],
           lang       => q(en),
           lang_dep   => { qw(heading 1) }, }, },
     result_source_class => q(File::DataClass::ResultSource::WithLanguage),
     tempdir => q(t) );

isa_ok( $schema, q(File::DataClass::Schema) );

my $source = $schema->source( q(pages) );

is( $source->lang, q(en), 'Has language attribute' );

my $rs = $source->resultset; my $args = {};

$args->{name  }  = q(dummy);
$args->{columns} = 3;
$args->{heading} = q(This is a heading);

my $res = test( $rs, q(create), $args );

is( $res, q(dummy), 'Creates dummy element and inserts' );

$args->{columns} = q(2);
$args->{heading} = q(This is a heading also);

$res = test( $rs, q(update), $args );

is( $res, q(dummy), 'Can update' );

delete $args->{columns};
delete $args->{heading};
$res = test( $rs, q(find), $args );

is( $res->columns, 2, 'Can find' );

my $e = test( $rs, q(create), $args );

ok( $e =~ m{ already \s+ exists }mx, 'Detects already existing element' );

$res = test( $rs, q(delete), $args );

is( $res, q(dummy), 'Deletes dummy element' );

$e = test( $rs, q(delete), $args );

ok( $e =~ m{ does \s+ not \s+ exist }mx, 'Detects non existing element' );

$source->lang( q(de) );

is( $source->storage->lang, q(de), 'Triggers storage language change' );

$args->{name  }  = q(dummy);
$args->{columns} = 3;
$args->{heading} = q(This is a heading);

$res = test( $rs, q(create), $args );

is( $res, q(dummy), 'Creates dummy element and inserts 2' );

my $data   = $schema->load;
my $dumped = catfile( qw(t dumped.xml)   );
my $pofile = catfile( qw(t dumped_de.po) );

$schema->dump( { data => $data, path => $dumped } );

my $gettext = File::Gettext->new( path => $pofile ); $data = $gettext->load;

my $text = $data->{ 'po' }->{ 'pages.heading.dummy' }->{ 'msgstr' }->[ 0 ];

ok( $text eq 'This is a heading', 'Dumps' );

$res = test( $rs, q(delete), $args );

is( $res, q(dummy), 'Deletes dummy element 2' );

# Cleanup

io( $dumped )->unlink;
io( $pofile )->unlink;
io( catfile( qw(t default_de.po)  ) )->unlink;
io( catfile( qw(t default_en.po)  ) )->unlink;
io( catfile( qw(t ipc_srlock.lck) ) )->unlink;
io( catfile( qw(t ipc_srlock.shm) ) )->unlink;
io( catfile( qw(t file-dataclass-schema.dat) ) )->unlink;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
