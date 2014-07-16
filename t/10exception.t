use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

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
use English      qw( -no_match_vars );
use Scalar::Util qw( blessed );

use_ok 'File::DataClass::Exception';

my $class = 'File::DataClass::Exception'; $EVAL_ERROR = undef;

eval { $class->throw_on_error }; my $e = $EVAL_ERROR; $EVAL_ERROR = undef;

ok ! $e, 'No throw without error';

eval { $class->throw( 'PracticeKill' ) };

$e = $EVAL_ERROR; $EVAL_ERROR = undef;

is blessed $e, $class, 'Good class';
is $e->class, 'File::DataClass::Exception', 'Default exception class';
like $e, qr{ PracticeKill \s* \z   }mx, 'Throws error message';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
