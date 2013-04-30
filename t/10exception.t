# @(#)Ident: 10exception.t 2013-04-30 21:43 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.18.%d', q$Rev: 4 $ =~ /\d+/gmx );
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
}

use Class::Null;

use_ok 'File::DataClass::Exception::Simple';

my $class = 'File::DataClass::Exception::Simple'; $EVAL_ERROR = undef;

eval { $class->throw_on_error }; my $e = $EVAL_ERROR; $EVAL_ERROR = undef;

ok ! $e, 'No throw without error';

eval { $class->throw( 'PracticeKill' ) };

$e = $EVAL_ERROR; $EVAL_ERROR = undef; my $min_level = $e->level;

is ref $e, $class, 'Good class';
like $e, qr{ \A main \[\d+ / $min_level \] }mx, 'Package and default level';
like $e, qr{ PracticeKill \s* \z   }mx, 'Throws error message';
is $e->class, 'File::DataClass::Exception', 'Default error class';

my ($line1, $line2, $line3);

sub test_throw { $class->throw( 'PracticeKill' ) }; $line1 = __LINE__;

sub test_throw1 { test_throw() }; $line2 = __LINE__;

eval { test_throw1() }; $line3 = __LINE__;

$e = $EVAL_ERROR; $EVAL_ERROR = undef; my @lines = $e->stacktrace;

like $e, qr{ \A main \[ $line2 / \d+ \] }mx, 'Package and line number';
is $lines[ 0 ], "main::test_throw line ${line1}", 'Stactrace line 1';
is $lines[ 1 ], "main::test_throw1 line ${line2}", 'Stactrace line 2';
is $lines[ 2 ], "main line ${line3}", 'Stactrace line 3';

my $level = $min_level + 1;

sub test_throw2 { $class->throw( error => 'PracticeKill', level => $level ) };

sub test_throw3 { test_throw2() }

sub test_throw4 { test_throw3() }; $line1 = __LINE__;

eval { test_throw4() }; $e = $EVAL_ERROR; $EVAL_ERROR = undef;

like $e, qr{ \A main \[ $line1 / $level \] }mx, 'Specific leader level';

$line1 = __LINE__; eval {
   $class->throw( args  => [ 'flap' ],
                  class => 'nonDefault',
                  error => 'cat: [_1] cannot open: [_2]', ) };

$e = $EVAL_ERROR; $EVAL_ERROR = undef;

is $e->class, 'nonDefault', 'Specific error class';

like $e, qr{ main\[ $line1 / 1 \]:\scat:\sflap\scannot\sopen:\s\[\?\] }mx,
   'Placeholer substitution';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
