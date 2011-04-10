# @(#)$Id$

package File::DataClass::IO;

use strict;
use namespace::clean -except => 'meta';
use overload '""' => sub { shift->pathname }, fallback => 1;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use File::DataClass::Exception;
use English      qw( -no_match_vars );
use Fcntl        qw( :flock :seek );
use List::Util   qw( first );
use File::Basename ();
use File::Path     ();
use File::Spec     ();
use File::Temp     ();
use IO::Dir;
use IO::File;
use Moose;
use Moose::Util::TypeConstraints;
use Scalar::Util qw( blessed );

use Sub::Exporter -setup => {
   exports => [ qw(io) ], groups => { default => [ qw(io) ], },
};

enum 'F_DC_IO_Mode'    => qw(a a+ r r+ w w+);
enum 'F_DC_IO_Type'    => qw(dir file);

has 'autoclose'        => is => 'rw', isa => 'Bool',      default    => TRUE  ;
has 'io_handle'        => is => 'rw', isa => 'Maybe[Object]'                  ;
has 'is_open'          => is => 'rw', isa => 'Bool',      default    => FALSE ;
has 'is_utf8'          => is => 'rw', isa => 'Bool',      default    => FALSE ;
has 'mode'             => is => 'rw', isa => 'F_DC_IO_Mode', default => q(r)  ;
has 'name'             => is => 'rw', isa => 'Str',       default    => NUL   ;
has 'sort'             => is => 'rw', isa => 'Bool',      default    => TRUE  ;
has 'type'             => is => 'rw', isa => 'Maybe[F_DC_IO_Type]'            ;
has '_assert'          => is => 'rw', isa => 'Bool',      default    => FALSE ;
has '_atomic'          => is => 'rw', isa => 'Bool',      default    => FALSE ;
has '_atomic_infix'    => is => 'rw', isa => 'Str',       default    => q(B_*);
has '_binary'          => is => 'rw', isa => 'Bool',      default    => FALSE ;
has '_binmode'         => is => 'rw', isa => 'Str',       default    => NUL   ;
has '_block_size'      => is => 'rw', isa => 'Int',       default    => 1024  ;
has '_chomp'           => is => 'rw', isa => 'Bool',      default    => FALSE ;
has '_deep'            => is => 'rw', isa => 'Bool',      default    => FALSE ;
has '_dir_pattern'     => is => 'ro', isa => 'RegexpRef', lazy_build => TRUE  ;
has '_encoding'        => is => 'rw', isa => 'Str',       default    => NUL   ;
has '_exception_class' => is => 'rw', isa => 'ClassName',
   default             => q(File::DataClass::Exception),
   writer              => 'exception_class';
has '_filter'          => is => 'rw', isa => 'Maybe[CodeRef]'                 ;
has '_lock'            => is => 'rw', isa => 'Bool',      default    => FALSE ;
has '_lock_obj'        => is => 'rw', isa => 'Maybe[Object]',
   writer              => 'lock_obj';
has '_perms'           => is => 'rw', isa => 'Num',       default    => PERMS ;
has '_separator'       => is => 'rw', isa => 'Str',       default    => $RS   ;
has '_umask'           => is => 'rw', isa => 'ArrayRef[Num]',
   default             => sub { return [] }                                   ;

around BUILDARGS => sub {
   my ($orig, $class, $car, @cdr) = @_; my $attrs = {};

   $car or return $attrs; my $is_blessed = blessed $car;

   $is_blessed and $car->isa( __PACKAGE__ ) and return $car;
   $is_blessed and $car .= NUL; # Stringify path object

   my $type = ref $car; $type eq HASH and return $car;

   $attrs->{name} = $type eq ARRAY ? File::Spec->catfile( @{ $car } ) : $car;
   $cdr[ 0 ] and $attrs->{mode  } = $cdr[ 0 ];
   $cdr[ 1 ] and $attrs->{_perms} = $cdr[ 1 ];

   return $attrs;
};

sub abs2rel {
   my ($self, $base) = @_; return File::Spec->abs2rel( $self->name, $base );
}

sub absolute {
   my $self = shift; $self->name( $self->rel2abs ); return $self;
}

sub all {
   my ($self, $level) = @_;

   $self->is_dir and return $self->_find( TRUE, TRUE, $level );

   return $self->_all_file_contents;
}

sub all_dirs {
   my ($self, $level) = @_; return $self->_find( FALSE, TRUE, $level );
}

sub all_files {
   my ($self, $level) = @_; return $self->_find( TRUE, FALSE, $level );
}

sub _all_file_contents {
   my $self = shift; $self->assert_open;

   local $RS = undef; my $all = $self->io_handle->getline;

   $self->error_check; $self->autoclose and $self->close;

   return $all;
}

sub append {
   my ($self, @rest) = @_;

   if ($self->is_open and not $self->is_reading) { $self->seek( 0, SEEK_END ) }
   else { $self->assert_open( q(a) ) }

   return $self->_print( @rest );
}

sub appendln {
   my ($self, @rest) = @_;

   if ($self->is_open and not $self->is_reading) { $self->seek( 0, SEEK_END ) }
   else { $self->assert_open( q(a) ) }

   return $self->_println( @rest );
}

sub assert {
   my $self = shift; $self->_assert( TRUE ); return $self;
}

sub assert_dirpath {
   my ($self, $dir_name) = @_;

   $dir_name or return; -d $dir_name and return $dir_name;

   $self->_umask_push;
   CORE::mkdir( $dir_name ) or File::Path::mkpath( $dir_name );
   $self->_umask_pop;

   -d $dir_name or $self->throw( error => 'Path [_1] cannot create',
                                 args  => [ $dir_name ] );
   return $dir_name;
}

sub assert_filepath {
   my $self = shift; my $dir;

   $self->name or $self->throw( 'Path not specified' );

   (undef, $dir) = File::Spec->splitpath( $self->name );

   return $self->assert_dirpath( $dir );
}

sub assert_open {
   my ($self, $mode, $perms) = @_;

   $self->type or $self->file; $mode ||= $self->mode;

   $self->is_open and $mode ne $self->mode and $self->close;

   return $self->is_open ? $self : $self->open( $mode, $perms );
}

sub atomic {
   my $self = shift; $self->_atomic( TRUE ); return $self;
}

*atomic_suffix = \&atomic_infix;

sub atomic_infix {
   my ($self, $value) = @_; $self->_atomic_infix( $value ); return $self;
}

sub basename {
   my ($self, @suffixes) = @_; $self->name or return;

   return File::Basename::basename( $self->name, @suffixes );
}

sub binary {
   my $self = shift;

   $self->is_open and CORE::binmode( $self->io_handle );
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

sub block_size {
   my ($self, $size) = @_; $self->_block_size( $size ); return $self;
}

sub buffer {
   my $self = shift;

   if (@_) {
      my $buffer_ref  = ref $_[0] ? $_[0] : \$_[0];

      defined ${ $buffer_ref } or ${ $buffer_ref } = NUL;
      $self->{buffer} = $buffer_ref;
      return $self;
   }

   exists $self->{buffer} or $self->{buffer} = do { my $x = NUL; \$x };

   return $self->{buffer};
}

sub _build__dir_pattern {
   my $self = shift; my ($curdir, $pat, $updir);

   $pat  = "\Q$curdir\E" if ($curdir = File::Spec->curdir);
   $pat .= q(|)          if ($updir  = File::Spec->updir and $pat);
   $pat .= "\Q$updir\E"  if ($updir);

   return qr{ \A $pat \z }mx;
}

sub canonpath {
   my $self = shift; return File::Spec->canonpath( $self->name );
}

sub catdir {
   my ($self, @rest) = @_;

   my @args = grep { defined and length } $self->name, @rest;

   return $self->_constructor( \@args )->dir;
}

sub catfile {
   my ($self, @rest) = @_;

   my @args = grep { defined and length } $self->name, @rest;

   return $self->_constructor( \@args )->file;
}

sub chomp {
   my $self = shift; $self->_chomp( TRUE ); return $self;
}

sub clear {
   my $self = shift; ${ $self->buffer } = NUL; return $self;
}

sub close {
   my $self = shift;

   $self->is_dir  and return $self->_close_dir;
   $self->is_file and return $self->_close_file;

   return $self;
}

sub _close {
   my $self = shift;

   $self->io_handle and $self->io_handle->close;
   $self->io_handle( undef );
   $self->is_open  ( FALSE );
   $self->mode     ( q(r)  );

   return $self;
}

sub _close_dir {
   my $self = shift; return $self->is_open ? $self->_close : $self;
}

sub _close_file {
   my $self = shift; my $path;

   if ($self->_atomic and $path = $self->_get_atomic_path and -f $path) {
      rename $path, $self->name
         or $self->throw( error => 'Cannot rename [_1] to [_2]',
                          args  => [ $path, $self->name ] );
   }

   $self->is_open or return $self;

   $self->unlock; return $self->_close;
}

sub _constructor {
   my ($self, @rest) = @_; return (blessed $self)->new( @rest );
}

sub deep {
   my $self = shift; $self->_deep( TRUE ); return $self;
}

sub delete {
   my $self = shift; my $path = $self->_get_atomic_path;

   $self->_atomic and -f $path and unlink $path;

   return $self->_close_file;
}

sub delete_tmp_files {
   my ($self, $tmplt) = @_;

   $tmplt ||= q(%6.6d....); my $pat = sprintf $tmplt, $PID;

   while (my $entry = $self->next) {
      $entry->filename =~ m{ \A $pat \z }mx and unlink $entry->pathname;
   }

   return $self->_close_dir;
}

sub DEMOLISH {
   my $self = shift;

   $self->_atomic and $self->delete; $self->is_open and $self->close;

   return;
}

sub dir {
   my ($self, @rest) = @_; return $self->_init( q(dir), @rest );
}

sub dirname {
   my $self = shift; $self->name or return;

   return File::Basename::dirname( $self->name );
}

sub empty {
   my $self = shift;

   $self->is_file and return -z $self->name;
   $self->is_dir  or  $self->throw( error => 'Path [_1] not found',
                                    args  => [ $self->name ] );

   return $self->next ? FALSE : TRUE;
}

sub encoding {
   my ($self, $encoding) = @_;

   $encoding or
      $self->throw( 'No encoding value passed to '.__PACKAGE__.'::encoding' );
   $self->is_open and CORE::binmode( $self->io_handle, ":$encoding" );
   $self->_encoding( $encoding );
   $self->is_utf8( $encoding eq q(utf8) ? TRUE : FALSE );
   return $self;
}

sub error_check {
   my $self = shift;

   $self->io_handle->can( q(error) ) or return;
   $self->io_handle->error or return;
   $self->throw( error => 'IO error [_1]', args => [ $ERRNO ] );
   return;
}

sub exists {
   my $self = shift; return -e $self->name;
}

sub file {
   my ($self, @rest) = @_; return $self->_init( q(file), @rest );
}

sub filename {
   my $self = shift; my $file;

   (undef, undef, $file) = File::Spec->splitpath( $self->name );

   return $file;
}

sub filepath {
   my $self = shift; my ($volume, $dir) = File::Spec->splitpath( $self->name );

   return File::Spec->catpath( $volume, $dir, NUL );
}

sub filter {
   my ($self, $code) = @_; $self->_filter( $code ); return $self;
}

sub _find {
   my ($self, $files, $dirs, $level) = @_;

   my $filter = $self->_filter; my (@all, $io);

   defined $level or $level = $self->_deep ? 0 : 1;

   while ($io = $self->next) {
      if (not defined $filter or map { $filter->() } ($io)) {
         if (($files and $io->is_file) or ($dirs and $io->is_dir)) {
            push @all, $io;
         }
      }

      if ($io->is_dir and $level != 1) {
         push @all, $io->_find( $files, $dirs, $level ? $level - 1 : 0 );
      }
   }

   return $self->sort ? sort { $a->name cmp $b->name } @all : @all;
}

sub _get_atomic_path {
   my $self = shift; my $path = $self->filepath; my $file;

   if ($self->_atomic_infix =~ m{ \* }mx) {
      my $name = $self->filename;

      ($file = $self->_atomic_infix) =~ s{ \* }{$name}mx;
   }
   else { $file = $self->filename.$self->_atomic_infix }

   return $path ? File::Spec->catfile( $path, $file ) : $file;
}

sub getline {
   my ($self, $separator) = @_; my $line; $self->assert_open;

   {  local $RS = $separator || $self->_separator;
      $line = $self->io_handle->getline;
      $self->_chomp and defined $line and CORE::chomp $line;
   }

   $self->error_check;
   defined $line and return $line;
   $self->autoclose and $self->close;
   return;
}

sub getlines {
   my ($self, $separator) = @_; my @lines; $self->assert_open;

   {  local $RS = $separator || $self->_separator;
      @lines = $self->io_handle->getlines;

      if ($self->_chomp) { CORE::chomp for @lines }
   }

   $self->error_check;
   scalar @lines and return (@lines);
   $self->autoclose and $self->close;
   return ();
}

sub _init {
   my ($self, $type, $name) = @_;

   $self->autoclose( TRUE  );
   $self->io_handle( undef );
   $self->is_open  ( FALSE );
   $self->name     ( $name ) if ($name);
   $self->mode     ( q(r)  );
   $self->sort     ( TRUE  );
   $self->type     ( $type );

   return $self;
}

sub io {
   return __PACKAGE__->new( @_ );
}

sub is_absolute {
   my $self = shift; return File::Spec->file_name_is_absolute( $self->name );
}

sub is_dir {
   my $self = shift;

   $self->type and return $self->type eq q(dir) ? TRUE : FALSE;

   return $self->name && -d $self->name ? TRUE : FALSE;
}

sub is_executable {
   my $self = shift; return $self->name && -x $self->name ? TRUE : FALSE;
}

sub is_file {
   my $self = shift;

   $self->type and return $self->type eq q(file) ? TRUE : FALSE;

   return $self->name && -f $self->name ? TRUE : FALSE;
}

sub is_readable {
   my $self = shift; return $self->name && -r $self->name ? TRUE : FALSE;
}

sub is_reading {
   my ($self, $mode) = @_; $mode ||= $self->mode;

   return first { $_ eq $mode } qw(r r+);
}

sub is_writable {
   my $self = shift; return $self->name && -w $self->name ? TRUE : FALSE;
}

sub length {
   my $self = shift; return length ${ $self->buffer };
}

sub lock {
   my $self = shift; $self->_lock( TRUE ); return $self;
}

sub mkdir {
   my ($self, $perms) = @_; $self->_umask_push( $perms );

   my $result = CORE::mkdir( $self->name ); $self->_umask_pop;

   return $result;
}

sub mkpath {
   my ($self, $perms) = @_; $self->_umask_push( $perms );

   my $result = File::Path::mkpath( $self->name ); $self->_umask_pop;

   return $result;
}

sub next {
   my $self = shift; my $name;

   defined ($name = $self->read_dir) or return;

   my $io = $self->_constructor( [ $self->name, $name ] );

   defined $self->_filter and $io->filter( $self->_filter );

   return $io;
}

sub open {
   my ($self, $mode, $perms) = @_; $mode ||= $self->mode;

   $self->is_open and $mode eq $self->mode and return $self;
   $self->is_dir
      and return $self->_open_dir ( $self->_open_args( $mode, $perms ) );
   $self->is_file
      and return $self->_open_file( $self->_open_args( $mode, $perms ) );

   return $self;
}

sub _open_args {
   my ($self, $mode, $perms) = @_;

   $self->name or $self->throw( 'Path not specified' );

   my $pathname = $self->_atomic && !$self->is_reading( $mode )
                ? $self->_get_atomic_path : $self->name;

   $perms = $self->_untainted_perms || $perms || $self->_perms;

   return ($pathname, $self->mode( $mode ), $self->_perms( $perms ));
}

sub _open_dir {
   my ($self, $path) = @_;

   $self->_assert and $self->assert_dirpath( $path );
   $self->io_handle( IO::Dir->new( $path ) )
      or $self->throw( error => 'Directory [_1] cannot open',
                       args  => [ $path ] );
   $self->is_open( TRUE );
   return $self;
}

sub _open_file {
   my ($self, $path, $mode, $perms) = @_;

   $self->_assert and $self->assert_filepath;
   $self->_umask_push( $perms );
   $self->io_handle( IO::File->new( $path, $mode, $perms ) )
      or $self->throw( error => 'File [_1] cannot open', args => [ $path ] );
   $self->_umask_pop;
   $self->is_open( TRUE );
   $self->set_binmode;
   $self->set_lock;
   return $self;
}

sub pathname {
   my ($self, @rest) = @_; return $self->name( @rest );
}

sub perms {
   my ($self, $perms) = @_; $self->_perms( $perms ); return $self;
}

sub print {
   my ($self, @rest) = @_; $self->assert_open( q(w) );

   return $self->_print( @rest );
}

sub _print {
   my ($self, @rest) = @_;

   for (@rest) {
      print {$self->io_handle} $_
         or $self->throw( error => 'IO error [_1]', args  => [ $ERRNO ] );
   }

   return $self;
}

sub println {
   my ($self, @rest) = @_; $self->assert_open( q(w) );

   return $self->_println( @rest );
}

sub _println {
   my ($self, @rest) = @_;

   return $self->_print( map { m{ [\n] \z }mx ? ($_) : ($_, "\n") } @rest );
}

sub read {
   my ($self, @rest) = @_; $self->assert_open;

   my $length = @rest || $self->is_dir
              ? $self->io_handle->read( @rest )
              : $self->io_handle->read( ${ $self->buffer },
                                        $self->_block_size, $self->length );

   $self->error_check;

   return $length || $self->autoclose && $self->close && 0;
}

sub read_dir {
   my $self = shift; my $dir_pat = $self->_dir_pattern; my $name;

   $self->type or $self->dir; $self->assert_open;

   if (wantarray) {
      my @names = grep { $_ !~ $dir_pat } $self->io_handle->read;

      $self->_close_dir; return @names;
   }

   while (not $name or $name =~ $dir_pat) {
      unless (defined ($name = $self->io_handle->read)) {
         $self->_close_dir; return;
      }
   }

   return $name;
}

sub rel2abs {
   my ($self, $base) = @_; return File::Spec->rel2abs( $self->name, $base );
}

sub relative {
   my $self = shift; $self->name( $self->abs2rel ); return $self;
}

sub rmdir {
   my $self = shift; return rmdir $self->name;
}

sub rmtree {
   my ($self, @rest) = @_; return File::Path::rmtree( $self->name, @rest );
}

sub seek {
   my ($self, @rest) = @_;

   $self->assert_open( $OSNAME eq EVIL ? q(r) : q(r+) );

   my @sunk = $self->io_handle->seek( @rest ); $self->error_check;

   return wantarray ? @sunk : $sunk[0];
}

sub separator {
   my ($self, $value) = @_; $self->_separator( $value ); return $self;
}

sub set_binmode {
   my $self = shift;

   if (my $encoding = $self->_encoding) {
      CORE::binmode( $self->io_handle, ":encoding($encoding)" );
   }
   elsif ($self->_binmode) {
      CORE::binmode( $self->io_handle, $self->_binmode );
   }
   elsif ($self->_binary) {
      CORE::binmode( $self->io_handle );
   }

   return $self;
}

sub set_lock {
   my $self = shift; $self->_lock or return;

   $self->_lock_obj and return $self->_lock_obj->set( k => $self->name );

   flock $self->io_handle, $self->mode eq q(r) ? LOCK_SH : LOCK_EX;

   return $self;
}

sub slurp {
   my $self = shift; my $slurp = $self->all;

   wantarray or return $slurp; local $RS = $self->_separator;

   $self->_chomp or return split m{ (?<=\Q$RS\E) }mx, $slurp;

   return map { CORE::chomp; $_ } split m{ (?<=\Q$RS\E) }mx, $slurp;
}

sub splitdir {
   my $self = shift; return File::Spec->splitdir( $self->name );
}

sub splitpath {
   my $self = shift; return File::Spec->splitpath( $self->name );
}

sub stat {
   my $self = shift; $self->name or return {};

   my %stat_hash = ( id => $self->filename );

   @stat_hash{ STAT_FIELDS() } = stat $self->name;

   return \%stat_hash;
}

sub tempfile {
   my ($self, $tmplt) = @_; my ($tempdir, $tmpfh);

   ($tempdir = $self->name and -d $tempdir) or $tempdir = File::Spec->tmpdir;

   $tmplt ||= q(%6.6dXXXX);
   $tmpfh   = File::Temp->new
      ( DIR => $tempdir, TEMPLATE => (sprintf $tmplt, $PID) );
   $self->_init( q(file), $tmpfh->filename );
   $self->io_handle( $tmpfh );
   $self->is_open( TRUE );
   return $self;
}

sub throw {
   my ($self, @rest) = @_;

   eval { $self->unlock; }; $self->_exception_class->throw( @rest );

   return; # Never reached
}

sub touch {
   my ($self, @rest) = @_; $self->name or return;

   if (-e $self->name) { my $now = time; utime $now, $now, $self->name }
   else { $self->_open_file( $self->_open_args( q(w) ) )->close }

   return $self;
}

sub _umask_pop {
   my $self = shift; my $perms = $self->_umask->[-1];

   ($perms and $perms != NO_UMASK_STACK) or return umask;
   umask pop @{ $self->_umask };
   return $perms;
}

sub _umask_push {
   my ($self, $perms) = @_; my $first = $self->_umask->[0];

   $first and $first == NO_UMASK_STACK and return umask;

   unless ($perms) {
      $perms = $self->_perms; $perms = (($perms & oct q(0444)) >> 2) | $perms;
   }

   $perms ^= oct q(0777); push @{ $self->_umask }, umask $perms;
   return $perms;
}

sub unlink {
   my $self = shift; return unlink $self->name;
}

sub unlock {
   my $self = shift; $self->_lock or return;

   if ($self->_lock_obj) { $self->_lock_obj->reset( k => $self->name ) }
   else { flock $self->io_handle, LOCK_UN }

   return $self;
}

sub _untainted_perms {
   my $self = shift; $self->exists or return; my $perms = 0;

   # Taint mode workaround
   $self->stat->{mode} =~ m{ \A (.*) \z }mx and $perms = $1;

   return $perms & oct q(07777);
}

sub utf8 {
   my $self = shift; $self->encoding( q(utf8) ); return $self;
}

sub write {
   my ($self, @rest) = @_; $self->assert_open( q(w) );

   my $length = @rest
              ? $self->io_handle->write( @rest )
              : $self->io_handle->write( ${ $self->buffer }, $self->length );

   $self->error_check;
   scalar @rest or $self->clear;
   return $length;
}

__PACKAGE__->meta->make_immutable;

no Moose::Util::TypeConstraints;
no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::IO - Better IO syntax

=head1 Version

0.3.$Revision$

=head1 Synopsis

   use File::DataClass::IO;

   # Read the first line of a file and chomp the result
   my $line = io( q(path_name) )->chomp->getline;

   # Write the line to file set permissions, atomic update and fcntl locking
   io( q(path_name), q(w), q(0644) )->atomic->lock->print( $line );

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

The constructor can be called with these method signatures:

=over 3

=item $io = File::DataClass::IO->new( { name => $pathname, ... } )

A hash ref containing a list of key value pairs which are the object's
attributes (where I<name> is the pathname)

=item $io = File::DataClass::IO->new( $pathname, [ $mode, $perms ] )

A list of values which are taken as the pathname, mode and
permissions. The pathname can be an array ref, a scalar, or an object
that stringifies to a scalar path

=item $io = File::DataClass::IO->new( $obj )

An object which is a L<File::DataClass::IO>

=back

=head2 abs2rel

   $io = io( q(relative_path_to_file) )->abs2rel( q(optional_base_path) );

Makes the pathname relative

=head2 absolute

Calls L</rel2abs> without an optional base path

=head2 all

   $lines = io( q(path_to_file) )->all;

For a file read all the lines and return them as a single scalar

   @entries = io( q(path_to_directory) )->all( $level );

For directories returns a list of IO objects for all files and
subdirectories. Excludes L<File::Spec/curdir> and L<File::Spec/updir>

Takes an optional argument telling how many directories deep to
search. The default is 1. Zero (0) means search as deep as possible
The default can be changed to zero by calling the L</deep> method

The filter method can be used to limit the results

The items returned are sorted by name unless L</sort>(0) is used

=head2 all_dirs

   @entries = io( q(path_to_directory) )->all_dirs( $level );

Like C<< ->all( $level ) >> but returns only directories

=head2 all_files

   @entries = io( q(path_to_directory) )->all_files( $level );

Like C<< ->all( $level ) >> but returns only files

=head2 append

   io( q(path_to_file) )->append( $line1, $line2, ... );

Opens the file in append mode and calls L</print> with the passed args

=head2 appendln

   io( q(path_to_file) )->appendln( $line, $line2, ... );

Opens the file in append mode and calls L</println> with the passed args

=head2 assert

   $io = io( q(path_to_file) )->assert;

Sets the private attribute B<_assert> to true. Causes the open methods
to create the path to the directory before the file/directory is
opened

=head2 assert_dirpath

   io( q(path_to_file) )->assert_dirpath;

Create the given directory if it doesn't already exist

=head2 assert_filepath

   io( q(path_to_file) )->assert_filepath;

Calls L</assert_dirpath> on the directory part of the full pathname

=head2 assert_open

   $io = io( q(path_to_file) )->assert_open( $mode, $perms );

Calls L</file> to default the type if its not already set and then
calls L</open> passing in the optional arguments

=head2 atomic

   $io = io( q(path_to_file) )->atomic;

Implements atomic file updates by writing to a temporary file and then
renaming it on closure. This method uses the pattern in the
I<_atomic_infix> attribute to compute the temporary pathname

=head2 atomic_suffix

Syntatic sugar. See L</atomix_infix>

=head2 atomic_infix

Defaults to I<B_*> (prefix). The I<*> is replaced by the filename to
create a temporary file for atomic updates. If the value does not
contain a I<*> then it is appended to the filename instead
(suffix). Attribute name I<_atomic_infix>

=head2 basename

   $dirname = io( q(path_to_file) )->basename( @suffixes );

Returns the L<File::Basename> C<basename> of the passed path

=head2 binary

   $io = io( q(path_to_file) )->binary;

Sets binary mode

=head2 binmode

   $io = io( q(path_to_file) )->binmode( $layer );

Sets binmode to the given layer

=head2 block_size

Defaults to 1024. The default block size used by the L</read> method

=head2 buffer

The internal buffer used by L</read> and L</write>

=head2 _build__dir_pattern

Returns the pattern that will match against the current or parent
directory

=head2 canonpath

   $canonpath = io( '././path_to_file' )->canonpath;

Returns the canonical path for the object

=head2 catdir

Create a new C<IO> directory object by concatenating this objects pathname
with the one that is supplied

=head2 catfile

Create a new C<IO> file object by concatenating this objects pathname
with the one that is supplied

=head2 chomp

   $io = io( q(path_to_file) )->chomp;

Causes input lines to be chomped when L</getline> or L</getlines> are called

=head2 clear

   $io->clear

Set the contents of the internal buffer to the null string

=head2 close

   $io->close;

Close the file or directory handle depending on type

=head2 _close_dir

Closes the open directory handle.

=head2 _close_file

If the temporary atomic file exists, renames it to the original
filename. Unlocks the file if it was locked. Closes the file handle

=head2 deep

   @files = io( 'path_to_root_of_tree' )->deep->all_files

Changes the default level for the L</all> methods to zero so
that the whole directory tree is searched

=head2 delete

Deletes the atomic update temporary file if it exists. Then calls
L</_close_file>

=head2 delete_tmp_files

   io( $tempdir )->delete_tmp_files( $template );

Delete temporary files for this process (temporary file names include
the process id). Temporary files are stored in the C<$tempdir>. Can override
the template filename pattern if required

=head2 DEMOLISH

If this is an atomic file update calls the L</delete> method. If the
object is still open it calls the L</close> method

=head2 dir

Initialises the current object as a directory

=head2 dirname

   $dirname = io( q(path_to_file) )->dirname;

Returns the L<File::Basename> C<dirname> of the passed path

=head2 empty

Returns true if the pathname exists and is zero bytes in size

=head2 encoding

   $io = io( q(path_to_file) )->encoding( $encoding );

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

=head2 filter

Takes a subroutine reference that is used by the L</all> methods to
filter which entries are returned. Called with C<$_> set to each
pathname in turn. It should return true if the entry is wanted

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

=item autoclose

Defaults to true. Attempts to read past end of file will cause the
object to be closed

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

=head2 io

Subroutine exported by default. Returns a new IO object

=head2 is_absolute

Return true if the pathname is absolute

=head2 is_dir

   $bool = io( q(path_to_file) )->is_dir;

Tests to see if the I<IO> object is a directory

=head2 is_executable

   $bool = io( q(path_to_file) )->is_executable;

Tests to see if the I<IO> object is executable

=head2 is_file

   $bool = io( q(path_to_file) )->is_file;

Tests to see if the I<IO> object is a file

=head2 is_readable

   $bool = io( q(path_to_file) )->is_readable;

Tests to see if the I<IO> object is readable

=head2 is_reading

Returns true if this I<IO> object is in one of the read modes

=head2 is_writable

   $bool = io( q(path_to_file) )->is_writable;

Tests to see if the I<IO> object is writable

=head2 length

Returns the length of the internal buffer

=head2 lock

   $io = io( q(path_to_file) )->lock;

Causes L</_open_file> to set a shared flock if its a read an exclusive
flock for any other mode

=head2 mkdir

   io( q(path_to_directory) )->mkdir;

Create the specified directory

=head2 mkpath

   io( q(path_to_directory) )->mkpath;

Create the specified path

=head2 next

Calls L</dir> if the I<type> is not already set. Asserts the directory
open for reading and then calls L</read_dir> to get the first/next
entry. It returns an IO object for that entry

=head2 open

   $io = io( q(path_to_file) )->open( $mode, $perms );

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

   $pathname = $io->pathname( $pathname );

Sets and returns then I<name> attribute

=head2 perms

   $io = io( q(path_to_file) )->perms( $perms );

Stores the given permissions on the I<_perms> attribute

=head2 print

Asserts that the file is open for writing and then prints passed list
of args to the open file handle. Throws I<ePrintError> if the C<print>
statement fails

=head2 println

   io( q(path_to_file) )->println( $line1, $line2, ... );

Calls L</print> appending a newline to each of the passed list args
that doesn't already have one

=head2 read

   $bytes_read = io( q(path_to_file) )->read( $buffer, $length );

Asserts that the pathname is open for reading then calls L</read> on
the open file handle. If called with args then these are passed to the
L</read>. If called with no args then the internal buffer is used
instead. Returns the number of bytes read

=head2 read_dir

Asserts that the file is open for reading. If called in an array context
returns a list of all the entries in the directory. If called in a scalar
context returns the first/next entry in the directory

=head2 rel2abs

   $io = io( q(relative_path_to_file) )->rel2abs( q(optional_base_path) );

Makes the pathname absolute

=head2 relative

Calls L</abs2rel> without an optional base path

=head2 rmdir

Remove the director

=head2 rmtree

Remove the directory tree

=head2 seek

Seeks to the selected point in the file

=head2 separator

Set the record separator used in calls to getlines and chomp

=head2 set_binmode

Sets the currently selected binmode on the open file handle

=head2 set_lock

Calls L</flock> on the open file handle

=head2 slurp

In a scalar context calls L</all> and returns its value. In an array
context returns the list created by splitting the scalar return value
on the system record separator. Will chomp each line if required

=head2 splitdir

Proxy for L<File::Spec/splitdir>

=head2 splitpath

Proxy for L<File::Spec/splitpath>

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
file system permissions which default to 0644 octal. If the file
already exists update it's last modified datetime stamp

=head2 unlink

Delete the specified file

=head2 unlock

Calls C<flock> on the open file handle with the I<LOCK_UN> option to
release the L<Fcntl> lock if one was set. Called by the L</file_close>
method

=head2 utf8

Sets the current encoding to utf8

=head2 write

   $bytes_written = io( q(pathname) )->write( $buffer, $length );

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

=item L<namespace::clean>

=item L<overload>

=item L<File::DataClass::Constants>

=item L<File::DataClass::Exception>

=item L<Moose>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

=over 3

=item Larry Wall

For the Perl programming language

=item Ingy döt Net <ingy@cpan.org>

For IO::All from which I took the API and some tests

=back

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2011 Peter Flanigan. All rights reserved

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
