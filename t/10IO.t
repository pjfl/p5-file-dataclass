# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   if ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
       || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) {
      plan skip_all => q(CPAN Testing stopped);
   }

   plan tests => 37;
   use_ok( q(File::DataClass::IO) );
}

sub test {
   my ($obj, $method, @args) = @_; local $EVAL_ERROR;

   my $wantarray = wantarray; my ($e, $res);

   eval {
      if ($wantarray) { @{ $res } = $obj->$method( @args ) }
      else { $res = $obj->$method( @args ) }
   };

   return $e if ($e = $EVAL_ERROR);

   return $wantarray ? @{ $res } : $res;
}

sub io {
   return File::DataClass::IO->new( @_ );
}

my $io = io( $PROGRAM_NAME );

isa_ok( $io, q(File::DataClass::IO) );

# Absolute

$io->absolute;

is( "$io", File::Spec->rel2abs( $PROGRAM_NAME ), 'Stringifies' );

$io->relative;

is( $io->pathname, File::Spec->abs2rel( $PROGRAM_NAME ), 'Relative paths' );

ok( io( q(t) )->absolute->next->is_absolute, 'Absolute directory paths' );

# All

my $exp1 = 't/mydir/dir1;t/mydir/dir2;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp2 = 't/mydir/dir1;t/mydir/dir1/dira;t/mydir/dir1/file1;t/mydir/dir2;t/mydir/dir2/file1;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp3 = 't/mydir/dir1;t/mydir/dir1/dira;t/mydir/dir1/dira/dirx;t/mydir/dir1/file1;t/mydir/dir2;t/mydir/dir2/file1;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp4 = 't/mydir/dir1;t/mydir/dir1/dira;t/mydir/dir1/dira/dirx;t/mydir/dir1/dira/dirx/file1;t/mydir/dir1/file1;t/mydir/dir2;t/mydir/dir2/file1;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp_files1 = 't/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp_files2 = 't/mydir/dir1/file1;t/mydir/dir2/file1;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp_files4 = 't/mydir/dir1/dira/dirx/file1;t/mydir/dir1/file1;t/mydir/dir2/file1;t/mydir/file1;t/mydir/file2;t/mydir/file3';
my $exp_dirs1 = 't/mydir/dir1;t/mydir/dir2';
my $exp_dirs2 = 't/mydir/dir1;t/mydir/dir1/dira;t/mydir/dir2';
my $exp_dirs3 = 't/mydir/dir1;t/mydir/dir1/dira;t/mydir/dir1/dira/dirx;t/mydir/dir2';
my $exp_filt1 = 't/mydir/dir1/dira;t/mydir/dir1/dira/dirx';
my $exp_filt2 = 't/mydir/dir1/dira/dirx';

sub p { join q(;), grep { not m{ \.svn }mx } @_ }
sub f { my $s = shift; $s =~ s/\//\\/g if ($^O =~ /^mswin32$/i); return $s }

is( p( io( 't/mydir' )->all       ), f( $exp1 ), 'All default'       );
is( p( io( 't/mydir' )->all(1)    ), f( $exp1 ), 'All level 1'       );
is( p( io( 't/mydir' )->all(2)    ), f( $exp2 ), 'All level 2'       );
is( p( io( 't/mydir' )->all(3)    ), f( $exp3 ), 'All level 3'       );
is( p( io( 't/mydir' )->all(4)    ), f( $exp4 ), 'All level 4'       );
is( p( io( 't/mydir' )->all(5)    ), f( $exp4 ), 'All level 5'       );
is( p( io( 't/mydir' )->all(0)    ), f( $exp4 ), 'All level 0'       );
is( p( io( 't/mydir' )->deep->all ), f( $exp4 ), 'All default deep'  );

is( p( io( 't/mydir' )->all_files       ), f( $exp_files1 ), 'All files'     );
is( p( io( 't/mydir' )->all_files(1)    ), f( $exp_files1 ), 'All files 1'   );
is( p( io( 't/mydir' )->all_files(2)    ), f( $exp_files2 ), 'All files 2'   );
is( p( io( 't/mydir' )->all_files(3)    ), f( $exp_files2 ), 'All files 3'   );
is( p( io( 't/mydir' )->all_files(4)    ), f( $exp_files4 ), 'All files 4'   );
is( p( io( 't/mydir' )->all_files(5)    ), f( $exp_files4 ), 'All files 5'   );
is( p( io( 't/mydir' )->all_files(0)    ), f( $exp_files4 ), 'All files 0'   );
is( p( io( 't/mydir' )->deep->all_files ), f( $exp_files4 ), 'All files deep');

is( p( io( 't/mydir' )->all_dirs       ), f( $exp_dirs1 ), 'All dirs'      );
is( p( io( 't/mydir' )->all_dirs(1)    ), f( $exp_dirs1 ), 'All dirs 1'    );
is( p( io( 't/mydir' )->all_dirs(2)    ), f( $exp_dirs2 ), 'All dirs 2'    );
is( p( io( 't/mydir' )->all_dirs(3)    ), f( $exp_dirs3 ), 'All dirs 3'    );
is( p( io( 't/mydir' )->all_dirs(4)    ), f( $exp_dirs3 ), 'All dirs 4'    );
is( p( io( 't/mydir' )->all_dirs(5)    ), f( $exp_dirs3 ), 'All dirs 5'    );
is( p( io( 't/mydir' )->all_dirs(0)    ), f( $exp_dirs3 ), 'All dirs 0'    );
is( p( io( 't/mydir' )->deep->all_dirs ), f( $exp_dirs3 ), 'All dirs deep' );

is( p( io( 't/mydir' )->filter( sub { m{ dira }mx } )->deep->all_dirs ),
    f( $exp_filt1 ), 'Filter 1' );
is( p( io( 't/mydir' )->filter( sub { m{ x }mx    } )->deep->all_dirs ),
    f( $exp_filt2 ), 'Filter 2' );

# Assert

ok( !-e 't/output/newpath/hello.txt', 'Non existant file' );
ok( !-e 't/output/newpath', 'Non existant directory' );

$io = io( 't/output/newpath/hello.txt' )->assert;

ok( !-e 't/output/newpath', 'Assert does not create directory' );

$io->println( 'Hello' );

ok( -f 't/output/newpath/hello.txt', 'Writing file creates directory' );

io( 't/output' )->rmtree;

# Chomp

$io = io( $PROGRAM_NAME )->chomp; my $seen = 0;

for ($io->slurp) { $seen = 1 if (m{ [\n] }mx) }

ok( !$seen, 'Slurp chomps newlines' );

$io->close;

for ($io->chomp->separator( 'io' )->getlines) { $seen = 1 if (m { io }mx) }

ok( !$seen, 'Getlines chomps record separators' );

#unlink( q(t/ipc_srlock.lck) );
#unlink( q(t/ipc_srlock.shm) );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
