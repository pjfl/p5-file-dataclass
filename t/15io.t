# @(#)$Ident: 15io.t 2013-12-31 16:59 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.29.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir catfile curdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );
use utf8;

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
use Config;
use Cwd;
use English      qw( -no_match_vars );
use File::pushd  qw( tempd );
use Path::Tiny   qw( );
use Scalar::Util qw( blessed );
use Test::Deep   qw( cmp_deeply );
use File::DataClass::Constants;

use_ok 'File::DataClass::IO';
isa_ok( io( $PROGRAM_NAME ), 'File::DataClass::IO' );

my $io; my $osname = lc $OSNAME;

sub p { join ';', grep { not m{ \.svn }mx } @_ }
sub f { my $s = shift; $osname eq 'mswin32' and $s =~ s/\//\\/g; return $s }

subtest 'Deliberate errors' => sub {
   eval { io( 'quack' )->slurp };

   like $EVAL_ERROR, qr{ File \s+ \S+ \s+ cannot \s+ open }mx,
      'Cannot open file';

   eval { io( [ qw( non_existant file ) ] )->println( 'x' ) };

   like $EVAL_ERROR, qr{ File \s+ \S+ \s+ cannot \s+ open }mx,
      'Cannot create file in non existant directory';

   eval { io( catdir( qw( t xxxxx ) ) )->next };

   like $EVAL_ERROR, qr{ Directory \s+ \S+ \s+ cannot \s+ open }mx,
      'Cannot open directory';

   eval { io( 'qwerty' )->empty };

   like $EVAL_ERROR, qr{ File \s+ \S+ \s+ not \s+ found }mx, 'No test empty';

   eval { io( 'qwerty' )->encoding };

   like $EVAL_ERROR, qr{ \Qnot specified\E }imx, 'Encoding requires a value';

   ok ! io( 'qwerty' )->exists, 'Non existant file';

   eval { io( 'qwerty' )->rmdir };

   like $EVAL_ERROR, qr{ Path \s+ \S+ \s+ not \s+ removed }mx,
      'Cannot remove non existant directory';
};

subtest 'Polymorphic Constructor' => sub {
   sub _filename { [ qw( t mydir file1 ) ] }

   ok io( catfile( qw( t mydir file1 ) ) )->exists, 'Constructs from path';
   ok io( [ qw( t mydir file1 ) ] )->exists, 'Constructs from arrayref';
   ok io( \&_filename )->exists, 'Constructs from coderef';
   ok io( { name => catfile( qw( t mydir file1 ) ) } )->exists,
      'Constructs from hashref';
   $io = io( [ qw( t mydir file1 ) ], 'r', oct '400' ); $io = io( $io );
   ok $io->exists, 'Constructs from object';
   $io = io( [ qw( t mydir file1 ) ], { perms => oct '400' } );
   ok $io->exists && (sprintf "%o", $io->_perms & 07777) eq '400',
      'Constructs from name and hashref';
   is( (sprintf "%o", $io->_perms & 07777), '400',
      'Duplicates permissions from original object' );

   my ($homedir) = glob( '~' );

   is io( '~' ), $homedir, 'Expands tilde';
   is io( '~/' ), $homedir, 'Expands tilde with trailing "/"';
   is io( '~/foo/bar' ), "${homedir}/foo/bar", 'Expands tilde with longer path';
   $io = io( '~/foo/bar/' );
   is $io, "${homedir}/foo/bar", 'Expands tilde, longer path and trailing "/"';
   is io( CURDIR ), Cwd::getcwd, 'Constructs from "."';

   my $ptt = Path::Tiny::path( 't' );

   is io( $ptt )->name, 't', 'Constructs from foreign object';
   ok io( [ qw( t mydir file1 ) ], 'r' )->exists,
    'Constructs from name and mode';
   ok io( name => [ qw( t mydir file1 ) ], mode => 'r' )->exists,
    'Constructs from list of keys and values';
};

# Stringifies
$io = io( $PROGRAM_NAME ); is "${io}", $PROGRAM_NAME, 'Stringifies';

subtest 'File::Spec::Functions' => sub {
   is( io( '././t/default.xml' )->canonpath, f( catfile( qw( t default.xml ) )),
       'Canonpath' );
   is( io( '././t/bogus'       )->canonpath, f( catfile( qw( t bogus ) ) ),
       'Bogus canonpath' );
   ok( io( catfile( q(), qw( foo bar ) ) )->is_absolute, 'Is absolute' );

   my ($v, $d, $f) = io( catdir( qw( foo bar ) ) )->splitpath;

   is( $d.q(x), catdir( q(foo), q(x) ), 'Splitpath directory' );
   is( $f, q(bar), 'Splitpath file' );

   my @dirs = io( catdir( qw( foo bar baz ) ) )->splitdir;

   is scalar @dirs, 3, 'Splitdir count';
   is( (join q(+), @dirs), q(foo+bar+baz), 'Splitdir string' );
   is io( catdir( q(), qw(foo bar baz) ) )->abs2rel( catdir( q(), q(foo) ) ),
      f( catdir( qw(bar baz) ) ), 'Can abs2rel';
   is io( catdir( qw(foo bar baz) ) )->rel2abs( catdir( q(), q(moo) ) ),
      f( catdir( q(), qw(moo foo bar baz) ) ), 'Can rel2abs';
   is io()->dir( catdir( qw(doo foo) ) )->catdir( qw(goo hoo) ),
      f( catdir( qw(doo foo goo hoo) ) ), 'Catdir 1';
   is io()->dir->catdir( qw(goo hoo) ), f( catdir( qw(goo hoo) ) ), 'Catdir 2';
   is io()->catdir( qw(goo hoo) ), f( catdir( qw(goo hoo) ) ), 'Catdir 3';
   is io()->file( catdir( qw(doo foo) ) )->catfile( qw(goo hoo) ),
       f( catfile( qw(doo foo goo hoo) ) ), 'Catfile 1';
   is io()->file->catfile( qw(goo hoo) ), f( catfile( qw(goo hoo) ) ),
       'Catfile 2';
   is io()->catfile( qw(goo hoo) ), f( catfile( qw(goo hoo) ) ), 'Catfile 3';
   is io( [ qw(t mydir dir1) ] )->dirname, catdir( qw(t mydir) ), 'Dirname';
   ok io( [ qw(t mydir dir1) ] )->parent->is_dir, 'Parent';
   is io( [ qw(t mydir dir1) ] )->parent( 2 ), 't', 'Parent with count';
   is io( [ qw( t output print.t ) ] )->basename, 'print.t', 'Basename';
};

subtest 'Absolute/relative pathname conversions' => sub {
   $io = io( $PROGRAM_NAME )->absolute;
   is "${io}", File::Spec->rel2abs( $PROGRAM_NAME ), 'Absolute';
   $io->relative;
   is "${io}", File::Spec->abs2rel( $PROGRAM_NAME ), 'Relative';
   ok io( q(t) )->absolute->next->is_absolute, 'Absolute directory paths';

   my $tmp = File::Spec->tmpdir;

   is io( $PROGRAM_NAME )->absolute( $tmp ),
      File::Spec->rel2abs( $PROGRAM_NAME, $tmp ), 'Absolute with base';
};

my ($device, $inode, $mode, $nlink, $uid, $gid, $device_id, $size,
    $atime, $mtime, $ctime, $blksize, $blocks) = stat( $PROGRAM_NAME );
my $stat = $io->stat;

subtest 'Retrieves inode status fields' => sub {
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
};

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

my $dir = catdir( qw(t mydir) );

subtest 'List all files and directories' => sub {
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
};

subtest 'Filters matching patterns from directory listing' => sub {
   is p( io( $dir )->filter( sub { m{ dira }mx } )->deep->all_dirs ),
      f( $exp_filt1 ), 'Filter 1';
   is p( io( $dir )->filter( sub { m{ x }mx    } )->deep->all_dirs ),
      f( $exp_filt2 ), 'Filter 2';
};

subtest 'Chomp newlines and record separators' => sub {
   $io = io( $PROGRAM_NAME )->chomp; my $seen = 0;

   for ($io->slurp) { $seen = 1 if (m{ [\n] }mx) }

   ok !$seen, 'Slurp chomps newlines'; $io->close; $seen = 0;

   for ($io->chomp->separator( 'io' )->getlines) { $seen = 1 if (m{ io }mx) }

   ok !$seen, 'Getlines chomps record separators';
};

subtest 'Create and remove a directory subtree' => sub {
   $dir = catdir( qw(t output subtree) );
   io( $dir )->mkpath; ok   -e $dir, 'Make path';
   $dir = catdir( qw(t output) );
   io( $dir )->rmtree; ok ! -e $dir, 'Remove tree';
   io( $dir )->mkdir;  ok   -e $dir, 'Make directory';
   io( $dir )->rmdir;  ok ! -e $dir, 'Remove directory';
};

subtest 'Setting assert creates path to file' => sub {
   $dir = catdir( qw(t output newpath ) );
   ok ! -e catfile( $dir, q(hello.txt) ), 'Non existant file';
   ok ! -e $dir, 'Non existant directory';
   $io = io( [ $dir, q(hello.txt) ] )->assert;
   ok ! -e $dir, 'Assert does not create directory';
   $io->println( 'Hello' );
   ok -d $dir, 'Writing file creates directory';
};

subtest 'Prints with and without newlines' => sub {
   $io = io( [ qw( t output print.t ) ] );
   is $io->print( 'one' )->print( 'two' )->close->slurp, 'onetwo', 'Print 1';
   $io = io( [ qw( t output print.t ) ] );
   is $io->print( "one\n" )->print( "two\n" )->close->slurp, "one\ntwo\n",
      'Print 2';
   $io = io( [ qw( t output print.t ) ] );
   is $io->println( 'one' )->println( 'two' )->close->slurp, "one\ntwo\n",
      'Print 3';
};

subtest 'Appends with and without newlines' => sub {
   $io = io( [ qw( t output print.t ) ] );
   is $io->append( 'three' )->close->slurp, "one\ntwo\nthree", 'Append';
   is $io->appendln( 'four' )->close->slurp, "one\ntwo\nthreefour\n",
      'Append with line feed';
   is $io->close->assert_open( 'r' )->append( 'five' )->close->slurp,
      "one\ntwo\nthreefour\nfive", 'Append when file open for reading';
   is $io->close->assert_open( 'w' )->append( 'six' )->close->slurp,
      "six", 'Append when file open for writing';
   is $io->close->assert_open( 'r' )->appendln( 'seven' )->close->slurp,
      "sixseven\n", 'Append when file open for reading';
   is $io->close->assert_open( 'w' )->appendln( 'eight' )->close->slurp,
      "eight\n", 'Append when file open for writing';
};

subtest 'Gets a single line' => sub {
   $io = io( [ qw( t output print.t ) ] );
   $io->binary->utf8->print( 'öne' );
   is $io->getline, 'öne', 'Getline utf8';
   $io->reset->binmode( ':raw' )->print( 'öne' );
   is $io->getline( $RS ), 'öne', 'Getline utf8 - raw';
};

subtest 'Create and detect empty subdirectories and files' => sub {
   $io = io( catdir( qw(t output empty) ) );
   ok $io->mkdir, 'Make a directory';
   ok $io->empty, 'The directory is empty';

   my $path = catfile( qw(t output file) ); $io = io( $path ); $io->touch( 0 );

   ok -e $path, 'Touch a file into existance';
   $osname eq q(mswin32)
      or is $io->stat->{mtime}, 0, 'Sets modidification date/time';
   ok $io->empty, 'The file is empty';
};

# Cwd
$io = io()->cwd;

is "${io}", Cwd::getcwd(), 'Current working directory';

subtest 'Tempfile/seek' => sub {
   my @lines = io( $PROGRAM_NAME )->chomp->slurp; $io = io( 't' );
   my $temp  = $io->tempfile;

   $temp->println( @lines ); $temp->seek( 0, 0 );

   my $text = $temp->slurp || q();

   ok length $text == $size,
      'Creates a tempfile seeks to the start and slurps content';

   is blessed( $io->delete_tmp_files ), 'File::DataClass::IO',
      'Delete tmp files';
   is blessed( $io->delete_tmp_files( '%6.6d....' ) ), 'File::DataClass::IO',
      'Delete tmp files - non default template';
};

subtest 'Buffered reading/writing' => sub {
   my $outfile = catfile( qw( t output out.pm ) );

   ok ! -f $outfile,   'Non existant output file';

   my $input = io( [ qw(lib File DataClass IO.pm) ] )->open->block_size( 4096 );

   ok ref $input,      'Open input';

   my $output = io( $outfile )->open( 'w' );

   ok ref $output,     'Open output';

   if ($osname eq 'mswin32') { $input->binary; $output->binary; }

   my $buffer; $input->buffer( $buffer ); $output->buffer( $buffer );

   ok defined $buffer, 'Define buffer';

   $output->write while ($input->read);

   ok !length $buffer, 'Empty buffer';
   ok $output->close,  'Close output';
   ok -s $outfile,     'Exists output file';
   ok $input->stat->{size} == $output->stat->{size}, 'File sizes match';
};

subtest 'Creates a file using atomic write' => sub {
   my $atomic_file = catfile( qw( t output B_atomic ) );
   my $outfile     = catfile( qw( t output atomic ) );

   $io = io( $outfile )->atomic->lock->println( 'x' );
   ok  -f $atomic_file, 'Atomic file exists';
   ok !-e $outfile,     'Atomic outfile does not exist'; $io->close;
   ok !-e $atomic_file, 'Renames atomic file';
   ok  -f $outfile,     'Writes atomic file';

   $atomic_file = catfile( qw( t output X_atomic ) );
   $io = io( $outfile )->atomic->atomic_infix( 'X_*' )->print( 'x' );
   ok  -f $atomic_file, 'Atomic file exists - infix'; $io->close;
   ok !-e $atomic_file, 'Renames atomic file - infix';

   $atomic_file = catfile( qw( t output atomic.tmp) );
   $io = io( $outfile )->atomic->atomic_suffix( '.tmp' )->print( 'x' );
   ok  -f $atomic_file, 'Atomic file exists - suffix'; $io->close;
   ok !-f $atomic_file, 'Renames atomic file - suffix';

   io( $outfile )->delete;
   $io = io( $outfile )->atomic->lock->println( 'x' );
   io( $outfile )->close;
};

# Substitution
$io = io( [ qw( t output substitute ) ] );
$io->println( qw( line1 line2 line3 ) );
$io->substitute( 'line2', 'changed' );
is( ($io->chomp->getlines( $RS ))[ 1 ], 'changed',
    'Substitutes one value for another' );

subtest 'Copy' => sub {
   my $to = io( [ qw( t output copy ) ] );

   $io->close; $io->copy( $to );
   is $io->all, $to->all, 'Copies a file - object target';
   $to->unlink; $io->copy( [ qw( t output copy ) ] );
   is $io->all, $to->all, 'Copies a file - constructs target';
   $to->unlink; $io->copy( Path::Tiny::path( "${to}" ) );
   is $io->all, $to->all, 'Copies a file - foreign object target';
};

SKIP: {
   ($osname eq 'mswin32' or $osname eq 'cygwin')
      and skip 'Unix ownership and permissions not applicable', 1;

   subtest 'Ownership' => sub {
      $io = io( [ qw( t output print.t ) ] );

      my $uid = $io->stat->{uid}; my $gid = $io->stat->{gid};

      eval { $io->chown( undef, $gid ) };
      like $EVAL_ERROR, qr{ \Qnot specified\E }mx,
         'Uid must be defined in chown';
      eval { $io->chown( $uid, undef ) };
      like $EVAL_ERROR, qr{ \Qnot specified\E }mx,
         'Gid must be defined in chown';
      is blessed( $io->chown( $uid, $gid ) ), 'File::DataClass::IO', 'Chown';
   };

   subtest 'Permissions' => sub {
      $io = io();
      ok !$io->is_executable, 'Not executable - no name';
      ok !$io->is_link, 'Not a link - no name';
      ok !$io->is_readable, 'Not readable - no name';
      ok !$io->is_writable, 'Not writable - no name';
      $io = io( [ qw( t output print.t ) ] ); $io->print( 'one' );
      ok  $io->is_readable,   'Readable';
      ok  $io->is_writable,   'Writable';
      ok !$io->is_executable, 'Not executable';
   };

   subtest 'Changes permissions of existing file' => sub {
      $io->chmod( 0400 );
      is( (sprintf "%o", $io->stat->{mode} & 07777), '400', 'Chmod 400' );
      $io->chmod();
      is( (sprintf "%o", $io->stat->{mode} & 07777), '660', 'Chmod default' );
      $io->chmod( 0777 );
      is( (sprintf "%o", $io->stat->{mode} & 07777), '777', 'Chmod 777' );
   };

   subtest 'More permissions' => sub {
      ok $io->is_executable, 'Executable';
   };

   subtest 'Creates files with specified permissions' => sub {
      my $path = catfile( qw( t output print.pl ) );

      $io = io( $path, 'w', oct q(0400) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(400), 'Create 400' );
      $io->unlink;
      $io = io( $path, 'w', oct q(0440) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(440), 'Create 440' );
      $io->unlink;
      $io = io( $path, 'w', oct q(0600) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(600), 'Create 600' );
      $io->unlink;
      $io = io( $path, 'w', oct q(0640) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(640), 'Create 640' );
      $io->unlink;
      $io = io( $path, 'w', oct q(0644) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(644), 'Create 644' );
      $io->unlink;
      $io = io( $path, 'w', oct q(0664) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(664), 'Create 664' );
      $io->unlink;
      $io = io( $path, 'w', oct q(0666) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(666), 'Create 666' );
      $io->unlink;
      $io = io( $path )->perms( oct q(0640) )->println( 'x' );
      is( (sprintf "%o", $io->stat->{mode} & 07777), q(640),
          'Create using prefered syntax' );
      $io->unlink;
   };
}

SKIP: {
   $Config{d_symlink} or skip 'No symlink support', 1;

   subtest 'Iterators and follow / not follow symlinks' => sub {
      my $wd       = tempd;
      my @tree     = qw( aaaa.txt bbbb.txt cccc/dddd.txt cccc/eeee/ffff.txt
                         gggg.txt );
      my @shallow  = qw( aaaa.txt bbbb.txt cccc gggg.txt pppp qqqq.txt );
      my @follow   = qw( aaaa.txt bbbb.txt cccc gggg.txt pppp qqqq.txt
                         cccc/dddd.txt cccc/eeee cccc/eeee/ffff.txt
                         pppp/ffff.txt );
      my @nofollow = qw( aaaa.txt bbbb.txt cccc gggg.txt pppp qqqq.txt
                         cccc/dddd.txt cccc/eeee cccc/eeee/ffff.txt );

      $_->touch for (map { io( $_ )->assert_filepath } @tree);

      symlink io( [ 'cccc', 'eeee' ] ), io( 'pppp' );
      symlink io( [ 'aaaa.txt'     ] ), io( 'qqqq.txt' );

      subtest 'Follow' => sub {
         my $dir = io( '.' )->deep; my @files = ();

         for my $f (map { $_->relative( $dir ) } $dir->all) {
            push @files, "${f}";
         }

         cmp_deeply( [ sort @files ], [ sort @follow ],
                     'Follow symlinks - deep' ) or diag explain \@files;
      };

      subtest 'No follow' => sub {
         my $dir = io( '.' )->deep->no_follow; my @files;

         for my $f (map { $_->relative( $dir ) } $dir->all) {
            push @files, "${f}";
         }

         cmp_deeply( [ sort @files ], [ sort @nofollow ],
                     "Don't follow symlinks" ) or diag explain \@files;
      };

      subtest 'Follow - iterator' => sub {
         my $io = io( '.' ); my $iter = $io->iterator; my @files;

         while (my $f = $iter->()) { push @files, $f->relative( $io )->name }

         cmp_deeply( [ sort @files ], [ sort @shallow ],
                     'Follow symlinks - shallow' ) or diag explain \@files;

         $io = io( '.' )->deep; $iter = $io->iterator; @files = ();

         while (my $f = $iter->()) { push @files, $f->relative( $io )->name }

         cmp_deeply( [ sort @files ], [ sort @follow ],
                     'Follow symlinks - deep' ) or diag explain \@files;
      };

      subtest 'No Follow - iterator' => sub {
         my $io = io( '.' )->deep->no_follow; my $iter = $io->iterator;
         my @files;

         while (my $f = $iter->()) { push @files, $f->relative( $io )->name }

         cmp_deeply( [ sort @files ], [ sort @nofollow ],
                     "Don't follow symlinks" ) or diag explain \@files;
      };

      subtest 'Follow - iterator with filter' => sub {
         my $io = io( '.' )->deep->filter( sub { m{ ffff.txt }mx } );

         my $iter = $io->iterator; my @files;

         while (my $f = $iter->()) { push @files, $f->relative( $io )->name }

         cmp_deeply( [ sort @files ],
                     [ 'cccc/eeee/ffff.txt', 'pppp/ffff.txt', ],
                       'Follow symlinks with filter' ) or diag explain \@files;
      };
   };
}

# Cleanup
io( catdir( qw( t output ) ) )->rmtree;

done_testing;

# Local Variables:
# coding: utf-8
# mode: perl
# tab-width: 3
# End:
