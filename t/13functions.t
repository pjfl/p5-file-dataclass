# @(#)Ident: 13functions.t 2013-12-31 00:06 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' ), catdir( $Bin, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Module::Build;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";
use English                    qw( -no_match_vars );
use File::DataClass::Functions qw( :all );
use Unexpected::Functions      qw( is_class_loaded );

my $result_class = 'File::DataClass::Result';

ensure_class_loaded( $result_class, { ignore_loaded => 1 } );

ok is_class_loaded( $result_class ), 'Ensure class loaded with options';

eval { ensure_class_loaded( 'TestTypo' ) };

like $EVAL_ERROR, qr{ package \s undefined }mx,
   'Class loaded package undefined';

ok !is_arrayref(), 'Is array ref without an argument';
ok !is_coderef(),  'Is code  ref without an argument';
ok !is_hashref(),  'Is hash  ref without an argument';
is  is_member( undef ), undef, 'Is member without argument';
is  is_member( 'x', [] ), 0, 'Is member with array ref';
is  is_member( 'x', qw( x y ) ), 1, 'Is member with list';
ok  is_stale( {}, 0, 1 ), 'Is stale - true';
ok !is_stale( {}, 1, 0 ), 'Is stale - false';

my $dest = { }; my $src = {  x => 'y' };

merge_attributes $dest, $src, [ 'x' ];

is $dest->{x}, 'y', 'Merge attributes';

$dest = {  x => undef }; merge_file_data( $dest, {  x => { z => 'y' } });

is $dest->{x}->{z}, undef, 'Merge file data';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
