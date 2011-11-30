# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.7.%d', q$Rev$ =~ /\d+/gmx );
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

   plan tests => 96;
}

use_ok( q(File::DataClass::IO) );

isa_ok( io( $PROGRAM_NAME ), q(File::DataClass::IO) );

# Error

eval { io( 'quack' )->slurp };

like( $EVAL_ERROR, qr{ File \s+ \S+ \s+ cannot \s+ open }mx,
      'Cannot open file' );

eval { io( catdir( qw(t xxxxx) ) )->next };

like( $EVAL_ERROR, qr{ Directory \s+ \S+ \s+ cannot \s+ open }mx,
      'Cannot open directory' );

eval { io( 'qwerty' )->empty };

like( $EVAL_ERROR, qr{ Path \s+ \S+ \s+ not \s+ found }mx, 'No test empty' );

# File Spec

is( io( '././t/default.xml' )->canonpath, f( catfile( qw(t default.xml) ) ),
    'Canonpath' );
is( io( '././t/bogus'       )->canonpath, f( catfile( qw(t bogus) ) ),
    'Bogus canonpath' );
ok( io( catfile( q(), qw(foo bar) ) )->is_absolute, 'Is absolute' );

my ($v, $d, $f) = io( catdir( qw(foo bar) ) )->splitpath;

is( $d.q(x), catdir( q(foo), q(x) ), 'Splitpath directory' );
is( $f, q(bar), 'Splitpath file' );

my @dirs = io( catdir( qw(foo bar baz) ) )->splitdir;

is( scalar @dirs, 3, 'Splitdir count' );
is( (join q(+), @dirs), q(foo+bar+baz), 'Splitdir string' );
is( io( catdir( q(), qw(foo bar baz) ) )->abs2rel( catdir( q(), q(foo) ) ),
    f( catdir( qw(bar baz) ) ), 'Can abs2rel' );
is( io( catdir( qw(foo bar baz) ) )->rel2abs( catdir( q(), q(moo) ) ),
    f( catdir( q(), qw(moo foo bar baz) ) ), 'Can rel2abs' );
is( io()->dir( catdir( qw(doo foo) ) )->catdir( qw(goo hoo) ),
    f( catdir( qw(doo foo goo hoo) ) ), 'Catdir 1' );
is( io()->dir->catdir( qw(goo hoo) ), f( catdir( qw(goo hoo) ) ), 'Catdir 2' );
is( io()->catdir( qw(goo hoo) ), f( catdir( qw(goo hoo) ) ), 'Catdir 3' );
is( io()->file( catdir( qw(doo foo) ) )->catfile( qw(goo hoo) ),
    f( catfile( qw(doo foo goo hoo) ) ), 'Catfile 1' );
is( io()->file->catfile( qw(goo hoo) ), f( catfile( qw(goo hoo) ) ),
    'Catfile 2' );
is( io()->catfile( qw(goo hoo) ), f( catfile( qw(goo hoo) ) ), 'Catfile 3' );

# Absolute/relative

my $io = io( $PROGRAM_NAME )->absolute;

is( "$io", File::Spec->rel2abs( $PROGRAM_NAME ), 'Absolute' );

$io->relative;

is( "$io", File::Spec->abs2rel( $PROGRAM_NAME ), 'Relative' );
ok( io( q(t) )->absolute->next->is_absolute, 'Absolute directory paths' );

my $tmp = File::Spec->tmpdir;

is( io( $PROGRAM_NAME )->absolute( $tmp ),
    File::Spec->rel2abs( $PROGRAM_NAME, $tmp ), 'Absolute with base' );

# Stat

my ($device, $inode, $mode, $nlink, $uid, $gid, $device_id,
    $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat( $PROGRAM_NAME );
my $stat = $io->stat;

is( $stat->{device},    $device,       'Stat device'      );
is( $stat->{inode},     $inode,        'Stat inode'       );
is( $stat->{mode},      $mode,         'Stat mode'        );
is( $stat->{nlink},     $nlink,        'Stat nlink'       );
is( $stat->{uid},       $uid,          'Stat uid'         );
is( $stat->{gid},       $gid,          'Stat gid'         );
is( $stat->{device_id}, $device_id,    'Stat device_id'   );
is( $stat->{size},      $size,         'Stat size'        );
ok( ($stat->{atime} ==  $atime)
 || ($stat->{atime} == ($atime + 1)),  'Stat access time' );
is( $stat->{mtime},     $mtime,        'Stat modify time' );
is( $stat->{ctime},     $ctime,        'Stat create time' );
is( $stat->{blksize},   $blksize,      'Stat block size'  );
is( $stat->{blocks},    $blocks,       'Stat blocks'      );

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

my $dir = catdir( qw(t mydir) );

is( p( io( $dir )->all       ), f( $exp1 ), 'All default'      );
is( p( io( $dir )->all(1)    ), f( $exp1 ), 'All level 1'      );
is( p( io( $dir )->all(2)    ), f( $exp2 ), 'All level 2'      );
is( p( io( $dir )->all(3)    ), f( $exp3 ), 'All level 3'      );
is( p( io( $dir )->all(4)    ), f( $exp4 ), 'All level 4'      );
is( p( io( $dir )->all(5)    ), f( $exp4 ), 'All level 5'      );
is( p( io( $dir )->all(0)    ), f( $exp4 ), 'All level 0'      );
is( p( io( $dir )->deep->all ), f( $exp4 ), 'All default deep' );

is( p( io( $dir )->all_files       ), f( $exp_files1 ), 'All files'      );
is( p( io( $dir )->all_files(1)    ), f( $exp_files1 ), 'All files 1'    );
is( p( io( $dir )->all_files(2)    ), f( $exp_files2 ), 'All files 2'    );
is( p( io( $dir )->all_files(3)    ), f( $exp_files2 ), 'All files 3'    );
is( p( io( $dir )->all_files(4)    ), f( $exp_files4 ), 'All files 4'    );
is( p( io( $dir )->all_files(5)    ), f( $exp_files4 ), 'All files 5'    );
is( p( io( $dir )->all_files(0)    ), f( $exp_files4 ), 'All files 0'    );
is( p( io( $dir )->deep->all_files ), f( $exp_files4 ), 'All files deep' );

is( p( io( $dir )->all_dirs       ), f( $exp_dirs1 ), 'All dirs'      );
is( p( io( $dir )->all_dirs(1)    ), f( $exp_dirs1 ), 'All dirs 1'    );
is( p( io( $dir )->all_dirs(2)    ), f( $exp_dirs2 ), 'All dirs 2'    );
is( p( io( $dir )->all_dirs(3)    ), f( $exp_dirs3 ), 'All dirs 3'    );
is( p( io( $dir )->all_dirs(4)    ), f( $exp_dirs3 ), 'All dirs 4'    );
is( p( io( $dir )->all_dirs(5)    ), f( $exp_dirs3 ), 'All dirs 5'    );
is( p( io( $dir )->all_dirs(0)    ), f( $exp_dirs3 ), 'All dirs 0'    );
is( p( io( $dir )->deep->all_dirs ), f( $exp_dirs3 ), 'All dirs deep' );

is( p( io( $dir )->filter( sub { m{ dira }mx } )->deep->all_dirs ),
    f( $exp_filt1 ), 'Filter 1' );
is( p( io( $dir )->filter( sub { m{ x }mx    } )->deep->all_dirs ),
    f( $exp_filt2 ), 'Filter 2' );

# Slurp/Chomp

$io = io( $PROGRAM_NAME )->chomp; my $seen = 0;

for ($io->slurp) { $seen = 1 if (m{ [\n] }mx) }

ok( !$seen, 'Slurp chomps newlines' );

$io->close; $seen = 0;

for ($io->chomp->separator( 'io' )->getlines) { $seen = 1 if (m { io }mx) }

ok( !$seen, 'Getlines chomps record separators' );

# Assert

ok( !-e catfile( qw(t output newpath hello.txt) ), 'Non existant file' );
ok( !-e catdir( qw(t output newpath ) ), 'Non existant directory' );

$io = io( catfile( qw(t output newpath hello.txt) ) )->assert;

ok( !-e catdir( qw(t output newpath) ), 'Assert does not create directory' );

$io->println( 'Hello' );

ok( -d catfile( qw(t output newpath) ), 'Writing file creates directory' );

# Print

$io = io( catfile( qw(t output print.t) ) );

is( $io->print( "one" )->print( "two" )->close->slurp, 'onetwo', 'Print 1' );

$io = io( catfile( qw(t output print.t) ) );

is( $io->print( "one\n" )->print( "two\n" )->close->slurp, "one\ntwo\n",
    'Print 2' );

$io = io( catfile( qw(t output print.t) ) );

is( $io->println( "one" )->println( "two" )->close->slurp, "one\ntwo\n",
    'Print 3' );

# Empty

$io = io( catdir( qw(t output empty) ) );

ok( $io->mkdir, 'Make directories' );
ok( $io->empty, 'Empty directory' );

$io = io( catfile( qw(t output file) ) );

ok( $io->touch, 'Touch' );
ok( $io->empty, 'Empty file' );

# Tempfile/seek

my @lines = io( $PROGRAM_NAME )->chomp->slurp;
my $temp  = io( q(t) )->tempfile;

$temp->println( @lines ); $temp->seek( 0, 0 );

my $text  = $temp->slurp || q();

ok( length $text == $size, 'Tempfile/seek' );

# Read/write

my $outfile = catfile( qw(t output out.pm) );

ok( !-f $outfile,    'Non existant output file' );

my $input   = io( catfile( qw(lib File DataClass IO.pm) ) )->open;

ok( ref $input,      'Open input' );

my $output  = io( $outfile )->open( q(w) );

ok( ref $output,     'Open output' );

my $buffer; $input->buffer( $buffer ); $output->buffer( $buffer );

ok( defined $buffer, 'Define buffer' );

$output->write while ($input->read);

ok( !length $buffer, 'Empty buffer' );
ok( $output->close,  'Close output' );
ok( -s $outfile,     'Exists output file' );

ok( $input->stat->{size} == $output->stat->{size}, 'File sizes match' );

# Substitution

$io = io( catfile( qw(t output substitute) ) );
$io->println( qw(line1 line2 line3) );
$io->substitute( q(line2), q(changed) );
is( ($io->chomp->getlines)[ 1 ], q(changed), 'Substitute values' );

# Copy

my $to = io( catfile( qw(t output copy) ) ); $io->close;

$io->copy( $to );
is( $io->all, $to->all, 'Copy file' );

# Chmod

$io->chmod( 0777 );
$stat = $io->stat;
is( (sprintf "%o", $stat->{mode} & 07777), q(777), 'chmod1' );
$io->chmod( 0400 );
$stat = $io->stat;
is( (sprintf "%o", $stat->{mode} & 07777), q(400), 'chmod2' );

# Permissions

$io = io( catfile( qw(t output print.pl) ), q(w), oct q(0400) )->println( 'x' );
is( (sprintf "%o", $io->stat->{mode} & 07777), q(400), 'Create 400' );
$io->unlink;

$io = io( catfile( qw(t output print.pl) ), q(w), oct q(0440) )->println( 'x' );
is( (sprintf "%o", $io->stat->{mode} & 07777), q(440), 'Create 440' );
$io->unlink;

$io = io( catfile( qw(t output print.pl) ), q(w), oct q(0600) )->println( 'x' );
is( (sprintf "%o", $io->stat->{mode} & 07777), q(600), 'Create 600' );
$io->unlink;

$io = io( catfile( qw(t output print.pl) ), q(w), oct q(0640) )->println( 'x' );
is( (sprintf "%o", $io->stat->{mode} & 07777), q(640), 'Create 640' );
$io->unlink;

$io = io( catfile( qw(t output print.pl) ), q(w), oct q(0644) )->println( 'x' );
is( (sprintf "%o", $io->stat->{mode} & 07777), q(644), 'Create 644' );
$io->unlink;

$io = io( catfile( qw(t output print.pl) ), q(w), oct q(0664) )->println( 'x' );
is( (sprintf "%o", $io->stat->{mode} & 07777), q(664), 'Create 664' );
$io->unlink;

$io = io( catfile( qw(t output print.pl) ), q(w), oct q(0666) )->println( 'x' );
is( (sprintf "%o", $io->stat->{mode} & 07777), q(666), 'Create 666' );
$io->unlink;

# Cleanup

io( catdir( qw(t output) ) )->rmtree;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
