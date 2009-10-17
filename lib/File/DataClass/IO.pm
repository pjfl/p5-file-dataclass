# @(#)$Id$

package File::DataClass::IO;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use English      qw( -no_match_vars );
use Fcntl        qw( :flock );
use File::Basename ();
use File::Path     ();
use File::Spec     ();
use File::Temp     ();
use IO::Dir;
use IO::File;
use Moose;

my @STAT_FIELDS = (
   qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks) );

has 'atomic_pref' => is => q(rw), isa => q(Str),       default    => q(B_);
has 'autoclose'   => is => q(rw), isa => q(Bool),      default    => TRUE ;
has 'block_size'  => is => q(rw), isa => q(Int),       default    => 1024 ;
has 'dir_pattern' => is => q(ro), isa => q(RegexpRef), lazy_build => TRUE ;

has 'exception_class' =>
   is => q(rw), isa => q(Str), default => q(File::DataClass::Exception);

has 'io_handle'   => is => q(rw), isa => q(Maybe[Object])                ;
has 'is_open'     => is => q(rw), isa => q(Bool), default  => FALSE      ;
has 'lock_obj'    => is => q(rw), isa => q(Object)                       ;
has 'mode'        => is => q(rw), isa => q(Maybe[Str])                   ;
has 'name'        => is => q(rw), isa => q(Str),  required => TRUE       ;
has 'type'        => is => q(rw), isa => q(Maybe[Str])                   ;
has '_assert'     => is => q(rw), isa => q(Bool), default  => FALSE      ;
has '_atomic'     => is => q(rw), isa => q(Maybe[Str])                   ;
has '_binary'     => is => q(rw), isa => q(Bool), default  => FALSE      ;
has '_binmode'    => is => q(rw), isa => q(Str),  default  => NUL        ;
has '_chomp'      => is => q(rw), isa => q(Bool), default  => FALSE      ;
has '_encoding'   => is => q(rw), isa => q(Str),  default  => NUL        ;
has '_lock'       => is => q(rw), isa => q(Bool), default  => FALSE      ;
has '_perms'      => is => q(rw), isa => q(Num),  default  => oct q(0644);
has '_utf8'       => is => q(rw), isa => q(Bool), default  => FALSE      ;

around BUILDARGS => sub {
   my ($orig, $class, @rest) = @_; my $attrs;

   return $class->$orig( @rest ) unless ($attrs = $rest[0]);

   unless (ref $attrs eq HASH) {
      $attrs = { name => $rest[0] };
      $attrs->{mode  } = $rest[1] if ($rest[1]);
      $attrs->{_perms} = $rest[2] if ($rest[2]);
   }

   return $class->$orig( $attrs );
};

sub absolute {
   my $self = shift;

   $self->is_absolute
      || $self->pathname( File::Spec->rel2abs( $self->pathname ) );
   return $self;
}

sub all {
   my $self = shift;

   $self->assert_open( q(r) );

   local $RS = undef; my $all = $self->io_handle->getline;

   $self->error_check;
   $self->autoclose && $self->close;
   return $all;
}

sub append {
   my ($self, @rest ) = @_;

   $self->assert_open( q(a) );
   $self->print( @rest );
   return;
}

sub appendln {
   my ($self, @rest ) = @_;

   $self->assert_open( q(a) );
   $self->println( @rest );
   return;
}

sub assert {
   my $self = shift; $self->_assert( TRUE ); return $self;
}

sub assert_dirpath {
   my ($self, $dir_name) = @_; my $perms = $self->_perms || oct q(0775);

   return $dir_name if (-d $dir_name
                        or CORE::mkdir( $self->pathname, $perms )
                        or File::Path::mkpath( $dir_name )
                        or $self->throw( error => 'Path [_1] cannot create',
                                         args  => [ $dir_name ] ));
   return;
}

sub assert_filepath {
   my $self = shift;
   my $name = $self->pathname or return;
   my $directory;

   (undef, $directory) = File::Spec->splitpath( $name );
   return $self->assert_dirpath( $directory );
}

sub assert_open {
   my ($self, @rest) = @_;

   $self->is_open && return $self;
   $self->type || $self->file;
   return $self->open( @rest );
}

sub atomic {
   my $self = shift;
   my $file = $self->atomic_pref.$self->filename;
   my $path = $self->filepath
            ? File::Spec->catfile( $self->filepath, $file ) : $file;

   $self->_atomic( $path );
   return $self;
}

sub basename {
   my ($self, @suffixes ) = @_;

   return unless ($self->pathname);

   return File::Basename::basename( $self->pathname, @suffixes );
}

sub binary {
   my $self = shift;

   $self->is_open && CORE::binmode( $self->io_handle );
   $self->_binary( TRUE );
   return $self;
}

sub binmode {
   my ($self, $layer) = @_;

   if ($self->is_open) {
      $layer ? CORE::binmode( $self->io_handle, $layer )
             : CORE::binmode( $self->io_handle );
   }

   $self->_binmode( $layer );
   return $self;
}

sub buffer {
   my ($self, @rest) = @_;

   if (not @rest) {
      unless (exists *$self->{buffer}) {
         *$self->{buffer} = do { my $x = NUL; \$x };
      }

      return *$self->{buffer};
   }

   my $buffer_ref   = ref $rest[0] ? $rest[0] : \$rest[0];
   ${ $buffer_ref } = NUL unless defined ${ $buffer_ref };
   *$self->{buffer} = $buffer_ref;
   return $self;
}

sub _build_dir_pattern {
   my $self = shift; my ($curdir, $pat, $updir);

   $pat  = "\Q$curdir\E" if ($curdir = File::Spec->curdir);
   $pat .= q(|)          if ($updir  = File::Spec->updir and $pat);
   $pat .= "\Q$updir\E"  if ($updir);

   return qr{ \A $pat \z }mx;
}

sub chomp {
   my $self = shift; $self->_chomp( TRUE ); return $self;
}

sub clear {
   my $self = shift; ${ $self->buffer } = NUL; return $self;
}

sub close {
   my $self = shift;

   $self->is_dir  && return $self->_close_dir;
   $self->is_file && return $self->_close_file;
   return;
}

sub _close {
   my $self = shift;

   $self->io_handle && $self->io_handle->close;
   $self->io_handle( undef );
   $self->mode( undef );
   $self->is_open( FALSE );
   return $self;
}

sub _close_dir {
   my $self = shift; return $self->is_open ? $self->_close : undef;
}

sub _close_file {
   my $self = shift;

   if ($self->_atomic and -f $self->_atomic) {
      rename $self->_atomic, $self->pathname
         or $self->throw( error => 'Cannot rename [_1] to [_2]',
                          args  => [ $self->_atomic, $self->pathname ] );
   }

   $self->_atomic( undef );
   $self->is_open || return;
   $self->unlock;
   return $self->_close;
}

sub delete {
   my $self = shift;

   $self->_atomic && -f $self->_atomic && unlink $self->_atomic;
   return $self->_close_file;
}

sub delete_tmp_files {
   my ($self, $tmplt) = @_;

   $tmplt ||= q(%6.6d....); my $pat = sprintf $tmplt, $PID;

   while (my $entry = $self->next) {
      unlink $entry->pathname if ($entry->filename =~ m{ \A $pat \z }mx);
   }

   $self->_close_dir;
   return;
}

sub DEMOLISH {
   my $self = shift;

   $self->_atomic && $self->delete;
   $self->is_open && $self->close;
   return;
}

sub dir {
   my ($self, @rest) = @_; return $self->_init( q(dir), @rest );
}

sub dirname {
   my $self = shift;

   return unless ($self->pathname);

   return File::Basename::dirname( $self->pathname );
}

sub empty {
   my $self = shift; return -z $self->pathname;
}

sub encoding {
   my ($self, $encoding) = @_;

   unless ($encoding) {
      $self->throw( 'No encoding value passed to '.__PACKAGE__.'::encoding' );
   }

   $self->is_open && CORE::binmode( $self->io_handle, ":$encoding" );
   $self->_encoding( $encoding );
   return $self;
}

sub error_check {
   my $self = shift;

   $self->io_handle->can( q(error) ) || return;
   $self->io_handle->error || return;
   $self->throw( error => 'IO error [_1]', args => [ $ERRNO ] );
   return;
}

sub exists {
   my $self = shift; return -e $self->pathname;
}

sub file {
   my ($self, @rest) = @_; return $self->_init( q(file), @rest );
}

sub filename {
   my $self = shift; my $file;

   (undef, undef, $file) = File::Spec->splitpath( $self->pathname );
   return $file;
}

sub filepath {
   my $self = shift;
   my ($volume, $path) = File::Spec->splitpath( $self->pathname );

   return File::Spec->catpath( $volume, $path, NUL );
}

sub getline {
   my ($self, @rest) = @_; my $line;

   $self->assert_open( q(r) );

   {
      $rest[0] and local $RS = $rest[0];
      $line = $self->io_handle->getline;
      CORE::chomp $line if ($self->_chomp && defined $line);
   }

   $self->error_check;
   return $line if (defined $line);
   $self->autoclose && $self->close;
   return;
}

sub getlines {
   my ($self, @rest) = @_; my @lines;

   $self->assert_open( q(r) );

   {
      $rest[0] and local $RS = $rest[0];
      @lines = $self->io_handle->getlines;

      if ($self->_chomp) { CORE::chomp for @lines }
   }

   $self->error_check;
   return (@lines) if (scalar @lines);
   $self->autoclose && $self->close;
   return ();
}

sub _init {
   my ($self, $type, $name) = @_;

   $self->atomic_pref( q(B_) );
   $self->autoclose  ( TRUE  );
   $self->block_size ( 1024  );
   $self->io_handle  ( undef );
   $self->is_open    ( FALSE );
   $self->name       ( $name ) if ($name);
   $self->type       ( $type );

   return $self;
}

sub is_absolute {
   my $self = shift;

   return File::Spec->file_name_is_absolute( $self->pathname );
}

sub is_dir {
   my $self = shift;

   $self->type && return $self->type eq q(dir) ? TRUE : FALSE;
   return $self->pathname and -d $self->pathname ? TRUE : FALSE;
}

sub is_file {
   my $self = shift;

   $self->type && return $self->type eq q(file) ? TRUE : FALSE;
   return $self->pathname and -f $self->pathname ? TRUE : FALSE;
}

sub length {
   my $self = shift; return length ${ $self->buffer };
}

sub lock {
   my $self = shift; $self->_lock( TRUE ); return $self;
}

sub next {
   my $self = shift; my ($io, $name);

   $self->type || $self->dir;
   $self->assert_open;
   return unless defined ($name = $self->read_dir);
   $io = $self->new( File::Spec->catfile( $self->pathname, $name ) );
   return $io;
}

sub open {
   my ($self, @rest) = @_;

   $self->is_dir  && return $self->_open_dir(  @rest );
   $self->is_file && return $self->_open_file( @rest );
   return;
}

sub _open_dir {
   my ($self, @rest) = @_; my $io;

   $self->is_open && return $self;
   $self->_assert
      && $self->pathname && $self->assert_dirpath( $self->pathname );

   unless ($io = IO::Dir->new( $self->pathname )) {
      $self->throw( error => 'Cannot open [_1]', args => [ $self->pathname ] );
   }

   $self->io_handle( $io );
   $self->is_open( TRUE );
   return $self;
}

sub _open_file {
   my ($self, @rest) = @_; my ($mode, $perms) = @rest; my (@args, $io);

   return $self if ($self->is_open);

   $self->_assert && $self->assert_filepath;
   @args = ( $self->mode( $mode || $self->mode ) );
   $self->_perms( $perms )   if (defined $perms);
   push @args, $self->_perms if (defined $self->_perms);

   if (defined $self->pathname) {
      my $pathname = $self->_atomic ? $self->_atomic : $self->pathname;

      unless ($io = IO::File->new( $pathname, @args )) {
         $self->throw( error => 'Cannot open [_1]', args => [ $pathname ] );
      }

      $self->io_handle( $io );
      $self->is_open( TRUE );
   }

   $self->is_open && $self->set_lock;
   $self->is_open && $self->set_binmode;
   return $self;
}

sub pathname {
   my ($self, @rest) = @_; return $self->name( @rest );
}

sub perms {
   my ($self, $perms) = @_; $self->_perms( $perms ); return $self;
}

sub print {
   my ($self, @rest) = @_;

   $self->assert_open( q(w) );

   for (@rest) {
      print {$self->io_handle} $_
         or $self->throw( error => 'IO error [_1]', args  => [ $ERRNO ] );
   }

   return;
}

sub println {
   my ($self, @rest) = @_;

   return $self->print( map { m{ [\n] \z }mx ? ($_) : ($_, "\n") } @rest );
}

sub read {
   my ($self, @rest) = @_;

   $self->assert_open( q(r) );
   my $length = (@rest or $self->is_dir)
              ? $self->io_handle->read( @rest )
              : $self->io_handle->read( ${ $self->buffer },
                                        $self->block_size, $self->length );
   $self->error_check;
   return $length || $self->autoclose && $self->close && 0;
}

sub read_dir {
   my $self = shift; my $dir_pat = $self->dir_pattern; my ($name, @names);

   $self->type || $self->dir;
   $self->assert_open;

   if (wantarray) {
      @names = grep { $_ !~ $dir_pat } $self->io_handle->read;
      $self->_close_dir;
      return @names;
   }

   while (not $name or $name =~ $dir_pat) {
      unless (defined ($name = $self->io_handle->read)) {
         $self->_close_dir;
         return;
      }
   }

   return $name;
}

sub set_binmode {
   my $self = shift;

   if (my $encoding = $self->_encoding) {
      CORE::binmode( $self->io_handle, ":encoding($encoding)" );
   }
   elsif ($self->_binary) {
      CORE::binmode( $self->io_handle );
   }
   elsif ($self->_binmode) {
      CORE::binmode( $self->io_handle, $self->_binmode );
   }

   return $self;
}

sub set_lock {
   my $self = shift;

   return unless ($self->_lock);

   return $self->lock_obj->set( k => $self->pathname ) if ($self->lock_obj);

   my $flag = $self->mode =~ m{ \A [r] \z }mx ? LOCK_SH : LOCK_EX;

   return flock $self->io_handle, $flag;
}

sub slurp {
   my $self = shift; my $slurp = $self->all;

   wantarray || return $slurp;

   if ($self->_chomp) {
      return map { CORE::chomp; $_ } split m{ (?<=\Q$RS\E) }mx, $slurp;
   }

   return split m{ (?<=\Q$RS\E) }mx, $slurp;
}

sub stat {
   my $self = shift;

   $self->pathname || return {};

   my %stat_hash = ( id => $self->filename );

   @stat_hash{ @STAT_FIELDS } = stat $self->pathname;
   return \%stat_hash;
}

sub tempfile {
   my ($self, $tmplt) = @_; my ($tempdir, $tmpfh);

   unless ($tempdir = $self->pathname and -d $tempdir) {
      $tempdir = File::Spec->tmpdir;
   }

   $tmplt ||= q(%6.6dXXXX);
   $tmpfh   = File::Temp->new( DIR      => $tempdir,
                               TEMPLATE => (sprintf $tmplt, $PID) );
   $self->_init( q(file), $tmpfh->filename );
   $self->io_handle( $tmpfh );
   $self->is_open( TRUE );
   return $self;
}

sub throw {
   my ($self, @rest) = @_;

   eval { $self->unlock; };

   $self->exception_class->throw( @rest );
   return; # Never reached
}

sub touch {
   my ($self, @rest) = @_;

   $self->pathname || return;

   if (-e $self->pathname) {
      my $now = time; utime $now, $now, $self->pathname;
   }
   else { $self->_open_file( q(w), $self->_perms || oct q(0664) )->close }

   return $self;
}

sub unlock {
   my $self = shift; $self->_lock || return;

   if ($self->lock_obj) { $self->lock_obj->reset( k => $self->pathname ) }
   else { flock $self->io_handle, LOCK_UN }

   return $self;
}

sub utf8 {
   my $self = shift;

   $self->encoding( q(utf8) );
   $self->_utf8( TRUE );
   return $self;
}

sub write {
   my ($self, @rest) = @_;

   $self->assert_open( q(w) );
   my $length = @rest
              ? $self->io_handle->write( @rest )
              : $self->io_handle->write( ${ $self->buffer }, $self->length );
   $self->error_check;
   $self->clear unless (@rest);
   return $length;
}

__PACKAGE__->meta->make_immutable;

no Moose; no Moose::Util::TypeConstraints;

1;

__END__

=pod

=head1 Name

File::DataClass::IO - Better IO syntax

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use YourExceptionClass;
   use File::DataClass::IO;

   sub io {
      my ($self, @rest) = @_;

      my $io = File::DataClass::IO->new( @rest );

      $io->exception_class( q(YourExceptionClass) );

      return $io;
   }

   # Read the first line of a file and chomp the result
   my $line = $self->io( q(path_name) )->chomp->getline;

   # Write the line to file set permissions, atomic update and fcntl locking
   $self->io( q(path_name), q(w), q(0644) )->atomic->lock->print( $line );

=head1 Description

This is a simplified re-write of L<IO::All> with additional functionality
from L<IO::AtomicFile>. Provides the same minimalist API but without the
heavy OO overloading. Only has methods for files and directories

=head1 Subroutines/Methods

If any errors occur the L</throw> method in the B<exception_class> is
called. If that is not defined the module throws an L<Exception::Class>
of its own

Methods beginning with an _ (underscore) are deemed private and should not
be called from outside this package

=head2 new

   my $io = File::DataClass::IO->new( $pathname, [ $mode, $perms ] );

Called with either a single hash ref containing a list of key value
pairs which are the object's attributes (where I<name> is the
pathname) or a list of values which are taken as the pathname, mode and
permissions. Returns the value from the call to L</_init> which it
makes without any options

=head2 absolute

   my $io = $self->io( q(path_to_file) )->absolute;

Makes the pathname absolute

=head2 all

   my $lines = $self->io( q(path_to_file) )->all;

Read all the lines from the file. Returns them as a single scalar

=head2 append

   $self->io( q(path_to_file) )->append( $line1, $line2, ... );

Opens the file in append mode and calls L</print> with the passed args

=head2 appendln

   $self->io( q(path_to_file) )->appendln( $line, $line2, ... );

Opens the file in append mode and calls L</println> with the passed args

=head2 assert

   my $io = $self->io( q(path_to_file) )->assert;

Sets the private attribute B<_assert> to true. Causes the open methods
to create the path to the directory before the file/directory is
opened

=head2 assert_dirpath

   $self->io( q(path_to_file) )->assert_dirpath;

Create the given directory if it doesn't already exist

=head2 assert_filepath

   $self->io( q(path_to_file) )->assert_filepath;

Calls L</assert_dirpath> on the directory part of the full pathname

=head2 assert_open

   my $io = $self->io( q(path_to_file) )->assert_open( $mode, $perms );

Calls L</file> to default the type if its not already set and then
calls L</open> passing in the optional arguments

=head2 atomic

   my $io = $self->io( q(path_to_file) )->atomic;

Implements atomic file updates by writing to a temporary file and then
renaming it on closure. This method stores the temporary pathname in the
B<_atomic> attribute

=head2 basename

   $dirname = $self->io( q(path_to_file) )->basename( @suffixes );

Returns the L<File::Basename> C<basename> of the passed path

=head2 binary

   my $io = $self->io( q(path_to_file) )->binary;

Sets binary mode

=head2 binmode

   my $io = $self->io( q(path_to_file) )->binmode( $layer );

Sets binmode to the given layer

=head2 buffer

The internal buffer used by L</read> and L</write>

=head2 chomp

   my $io = $self->io( q(path_to_file) )->chomp;

Causes input lines to be chomped when L</getline> or L</getlines> are called

=head2 clear

Set the contents of the internal buffer to the null string

=head2 close

   $io->close;

Close the file or directory handle depending on type

=head2 _close_dir

Closes the open directory handle.

=head2 _close_file

If the temporary atomic file exists, renames it to the original
filename. Unlocks the file if it was locked. Closes the file handle

=head2 delete

Deletes the atomic update temporary file if it exists. Then calls
L</_close_file>

=head2 delete_tmp_files

   $self->io( $tempdir )->delete_tmp_files( $template );

Delete temporary files for this process (temporary file names include
the process id). Temporary files are stored in the C<$tempdir>. Can override
the template filename pattern if required

=head2 DEMOLISH

If this is an atomic file update calls the L</delete> method. If the
object is still open it calls the L</close> method

=head2 dir

Initialises the current object as a directory

=head2 dir_pattern

Returns the pattern that will match against the current or parent
directory

=head2 dirname

   $dirname = $self->io( q(path_to_file) )->dirname;

Returns the L<File::Basename> C<dirname> of the passed path

=head2 empty

Returns true if the pathname exists and is zero bytes in size

=head2 encoding

   my $io = $self->io( q(path_to_file) )->encoding( $encoding );

Apply the given encoding to the open file handle and store it on the
B<_encoding> attribute

=head2 error_check

Tests to see if the open file handle is showing an error and if it is
it L</throw>s an I<eIOError>

=head2 exists

Returns true if the pathname exists

=head2 file

Initializes the current object as a file

=head2 filename

Returns the filename part of pathname

=head2 filepath

Returns the directory part of pathname

=head2 getline

Asserts the file open for reading. Get one line from the file
handle. Chomp the line if the I<_chomp> attribute is true. Check for
errors. Close the file if the I<autoclose> attribute is true and end
of file has been read past

=head2 getlines

Like L</getline> but calls L</getlines> on the file handle and returns
an array of lines

=head2 _init

Sets default values for some attributes, takes two optional arguments;
I<type> and I<name>

=over 3

=item atomic_pref

Defaults to I<B_>. It is prepended to the filename to create a
temporary file for atomic updates

=item autoclose

Defaults to true. Attempts to read past end of file will cause the
object to be closed

=item block_size

Defaults to 1024. The default block size used by the L</read> method

=item exception_class

Defaults to undef. Can be set to the name of an class that provides
the L</throw> method

=item io_handle

Defaults to undef. This is set when the object is actually opened

=item is_open

Defaults to false. Set to true when the object is opened

=item name

Defaults to undef. This must be set in the call to the constructor or
soon after

=item type

Defaults to false. Set by the L</dir> and L</file> methods to I<dir> and
I<file> respectively. The L</dir> method is called by the L</next>
method. The L</file> method is called by the L</assert_open> method if
the I<type> attribute is false

=back

=head2 is_absolute

Return true if the pathname is absolute

=head2 is_dir

   my $bool = $self->io( q(path_to_file) )->is_dir;

Tests to see if the I<IO> object is a directory

=head2 is_file

   my $bool = $self->io( q(path_to_file) )->is_file;

Tests to see if the I<IO> object is a file

=head2 length

Returns the length of the internal buffer

=head2 lock

   my $io = $self->io( q(path_to_file) )->lock;

Causes L</_open_file> to set a shared flock if its a read an exclusive
flock for any other mode

=head2 next

Calls L</dir> if the I<type> is not already set. Asserts the directory
open for reading and then calls L</read_dir> to get the first/next
entry. It returns an IO object for that entry

=head2 open

   my $io = $self->io( q(path_to_file) )->open( $mode, $perms );

Calls either L</_open_dir> or L</_open_file> depending on type. You do not
usually need to call this method directly. It is called as required by
L</assert_open>

=head2 _open_dir

If the I<_assert> attribute is true calls L</assert_dirpath> to create the
directory path if it does not exist. Opens the directory and stores the
handle on the I<io_handle> attribute

=head2 _open_file

Opens the pathname with the given mode and permissions. Calls
L</assert_filepath> if I<assert> is true. Mode defaults to the I<mode>
attribute value which defaults to I<r>. Permissions defaults to the
I<_perms> attribute value. Throws B<eCannotOpen> on error. If the open
succeeds L</set_lock> and L</set_binmode> are called

=head2 pathname

   my $pathname = $io->pathname( $pathname );

Sets and returns then I<name> attribute

=head2 perms

   my $io = $self->io( q(path_to_file) )->perms( $perms );

Stores the given permissions on the I<_perms> attribute

=head2 print

Asserts that the file is open for writing and then prints passed list
of args to the open file handle. Throws I<ePrintError> if the C<print>
statement fails

=head2 println

   $self->io( q(path_to_file) )->println( $line1, $line2, ... );

Calls L</print> appending a newline to each of the passed list args
that doesn't already have one

=head2 read

   my $bytes_read = $self->io( q(path_to_file) )->read( $buffer, $length );

Asserts that the pathname is open for reading then calls L</read> on
the open file handle. If called with args then these are passed to the
L</read>. If called with no args then the internal buffer is used
instead. Returns the number of bytes read

=head2 read_dir

Asserts that the file is open for reading. If called in an array context
returns a list of all the entries in the directory. If called in a scalar
context returns the first/next entry in the directory

=head2 set_binmode

Sets the currently selected binmode on the open file handle

=head2 set_lock

Calls L</flock> on the open file handle

=head2 slurp

In a scalar context calls L</all> and returns its value. In an array
context returns the list created by splitting the scalar return value
on the system record separator. Will chomp each line if required

=head2 stat

Returns a hash of the values returned by a L</stat> call on the pathname

=head2 tempfile

Create a randomly named temporary file in the I<name>
directory. The file name is prefixed with the creating processes id
and the temporary directory defaults to F</tmp>

=head2 throw

Exposes the C<throw> method in the class exception class

=head2 touch

Create a zero length file if one does not already exist with given
file system permissions which default to 0664 octal. If the file
already exists update it's last modified datetime stamp

=head2 unlock

Calls C<flock> on the open file handle with the I<LOCK_UN> option to
release the L<Fcntl> lock if one was set. Called by the L</file_close>
method

=head2 utf8

Sets the current encoding to utf8

=head2 write

   my $bytes_written = $self->io( q(pathname) )->write( $buffer, $length );

Asserts that the file is open for writing then write the C<$length> bytes
from C<$buffer>. Checks for errors and returns the number of bytes
written. If C<$buffer> and C<$length> are omitted the internal buffer is
used. In this case the buffer contents are nulled out after the write

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<Class::Accessor::Fast>

=item L<Exception::Class>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2009 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
