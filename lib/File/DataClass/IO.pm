package File::DataClass::IO;

use 5.010001;

use File::DataClass::Constants qw( EXCEPTION_CLASS FALSE LOCK_BLOCKING
                                   LOCK_NONBLOCKING NO_UMASK_STACK NUL
                                   PERMS STAT_FIELDS TILDE TRUE );
use File::DataClass::Functions qw( ensure_class_loaded first_char is_member
                                   is_mswin is_ntfs thread_id throw );
use Cwd                        qw( );
use English                    qw( -no_match_vars );
use Fcntl                      qw( :flock :seek );
use File::Basename               ( );
use File::Copy                   ( );
use File::Spec                   ( );
use File::Spec::Functions      qw( curdir updir );
use IO::Dir;
use IO::File;
use IO::Handle;
use List::Util                 qw( first );
use Ref::Util                  qw( is_arrayref is_coderef is_hashref );
use Scalar::Util               qw( blessed );
use Sub::Install               qw( install_sub );
use Type::Utils                qw( enum );
use Unexpected::Functions      qw( InvocantUndefined PathNotFound Unspecified );
use Unexpected::Types          qw( ArrayRef Bool CodeRef Int Maybe Object
                                   PositiveInt RegexpRef SimpleStr Str );
use Moo;

use namespace::clean -except => [ 'meta' ];
use overload '""'       => sub { $_[ 0 ]->as_string  },
             'bool'     => sub { $_[ 0 ]->as_boolean },
             'fallback' => TRUE;

my $IO_LOCK = enum 'IO_Lock' => [ FALSE, LOCK_BLOCKING, LOCK_NONBLOCKING ];
my $IO_MODE = enum 'IO_Mode' => [ qw( a a+ r r+ w w+ ) ];
my $IO_TYPE = enum 'IO_Type' => [ qw( dir file ) ];

# Public attributes
has 'autoclose'     => is => 'lazy', isa => Bool,           default => TRUE  ;
has 'have_lock'     => is => 'rwp',  isa => Bool,           default => FALSE ;
has 'io_handle'     => is => 'rwp',  isa => Maybe[Object]                    ;
has 'is_open'       => is => 'rwp',  isa => Bool,           default => FALSE ;
has 'mode'          => is => 'rwp',  isa => $IO_MODE | PositiveInt,
   default          => 'r'                                                   ;
has 'name'          => is => 'rwp',  isa => SimpleStr,      default => NUL,
   coerce           => \&_coerce_name,                      lazy    => TRUE  ;
has '_perms'        => is => 'rwp',  isa => PositiveInt,    default => PERMS,
   init_arg         => 'perms'                                               ;
has 'reverse'       => is => 'lazy', isa => Bool,           default => FALSE ;
has 'sort'          => is => 'lazy', isa => Bool,           default => TRUE  ;
has 'type'          => is => 'rwp',  isa => Maybe[$IO_TYPE]                  ;

# Private attributes
has '_assert'       => is => 'rw',   isa => Bool,           default => FALSE ;
has '_atomic'       => is => 'rw',   isa => Bool,           default => FALSE ;
has '_atomic_infix' => is => 'rw',   isa => SimpleStr,      default => 'B_*' ;
has '_backwards'    => is => 'rw',   isa => Bool,           default => FALSE ;
has '_block_size'   => is => 'rw',   isa => PositiveInt,    default => 1024  ;
has '_chomp'        => is => 'rw',   isa => Bool,           default => FALSE ;
has '_deep'         => is => 'rw',   isa => Bool,           default => FALSE ;
has '_dir_pattern'  => is => 'lazy', isa => RegexpRef,
   builder          => '_build_dir_pattern'                                  ;
has '_filter'       => is => 'rw',   isa => Maybe[CodeRef]                   ;
has '_layers'       => is => 'ro',   isa => ArrayRef[SimpleStr],
   builder          => sub { [] }                                            ;
has '_lock'         => is => 'rw',   isa => $IO_LOCK,       default => FALSE ;
has '_no_follow'    => is => 'rw',   isa => Bool,           default => FALSE ;
has '_separator'    => is => 'rw',   isa => Str,            default => $RS   ;
has '_umask'        => is => 'ro',   isa => ArrayRef[Int],
   builder          => sub { [] }                                            ;

sub BUILDARGS { # Differentiate constructor method signatures
   my $class = shift;
   my $n     = 0;

   $n++ while (defined $_[$n]);

   return            ( $n == 0 ) ? { io_handle => IO::Handle->new }
        : _is_one_of_us( $_[0] ) ? _clone_one_of_us(@_)
        :    is_hashref( $_[0] ) ? { %{$_[0]} }
        :            ( $n == 1 ) ? { _inline_args(1, @_) }
        :    is_hashref( $_[1] ) ? { name => $_[0], %{$_[1]} }
        :            ( $n == 2 ) ? { _inline_args(2, @_) }
        :            ( $n == 3 ) ? { _inline_args(3, @_) }
                                 : { @_ };
}

sub BUILD {
   my $self   = shift;
   my $handle = $self->io_handle;

   $self->_set_is_open($handle->opened) if !$self->name && $handle;

   return;
}

sub DEMOLISH {
   my ($self, $gd) = @_;

   return if $gd; # uncoverable branch true

   $self->_atomic ? $self->delete : $self->close;

   return;
}

sub import {
   my ($class, @wanted) = @_;

   my $package = caller;

   install_sub { into => $package, as => 'io', code => sub (;@) {
      return $class->new(@_);
   } } if not defined $wanted[0] or $wanted[0] eq 'io';

   return;
}

# Public methods
sub abs2rel {
   my ($self, $base) = @_;

   return File::Spec->abs2rel($self->name, $base);
}

sub absolute {
   my ($self, $base) = @_;

   $base = _coerce_name($base) if $base;

   $self->_set_name(CORE::length($self->name) ? $self->rel2abs($base) : $base);

   return $self;
}

sub all {
   my ($self, $level) = @_;

   return $self->_find(TRUE, TRUE, $level) if $self->is_dir;

   return $self->_all_file_contents;
}

sub all_dirs {
   return $_[0]->_find(FALSE, TRUE, $_[1]);
}

sub all_files {
   return $_[0]->_find(TRUE, FALSE, $_[1]);
}

sub append {
   my ($self, @args) = @_;

   if ($self->is_open && !$self->is_reading) { $self->seek(0, SEEK_END) }
   else { $self->assert_open('a') }

   return $self->_print(@args);
}

sub appendln {
   my ($self, @args) = @_;

   if ($self->is_open && !$self->is_reading) { $self->seek(0, SEEK_END) }
   else { $self->assert_open('a') }

   return $self->_println(@args);
}

sub as_boolean {
   return (CORE::length($_[0]->name) || $_[0]->io_handle) ? TRUE : FALSE;
}

sub as_string {
   my $self = shift;

   return $self->name if CORE::length $self->name;

   return defined $self->io_handle ? $self->io_handle.NUL : NUL;
}

sub assert {
   my ($self, $cb) = @_;

   if ($cb) {
      local $_ = $self;
      throw 'Path [_1] assertion failure', [ $self->name ] unless $cb->();
   }
   else { $self->_assert(TRUE) }

   return $self;
}

sub assert_dirpath {
   my ($self, $dir_name) = @_;

   return unless $dir_name;
   return $dir_name if -d $dir_name;

   my $perms = $self->_mkdir_perms;

   $self->_umask_push(oct '07777');

   unless (CORE::mkdir($dir_name, $perms)) {
      ensure_class_loaded 'File::Path';
      File::Path::make_path($dir_name, { mode => $perms });
   }

   $self->_umask_pop;

   # uncoverable branch true
   $self->_throw('Path [_1] cannot create: [_2]', [$dir_name, $OS_ERROR])
      unless -d $dir_name;

   return $dir_name;
}

sub assert_filepath {
   my $self = shift;

   $self->_throw(Unspecified, ['path name']) unless CORE::length $self->name;

   my (undef, $dir) = File::Spec->splitpath($self->name);

   $self->assert_dirpath($dir);

   return $self;
}

sub assert_open {
   return $_[0]->open($_[1] // 'r', $_[2]);
}

sub atomic {
   my $self = shift;

   $self->_atomic(TRUE);

   return $self;
}

sub atomic_infix {
   my ($self, $infix) = @_;

   $self->_atomic_infix($infix) if defined $infix;

   return $self;
}

sub atomic_suffix {
   my ($self, $suffix) = @_;

   $self->_atomic_infix($suffix) if defined $suffix;

   return $self;
}

sub backwards {
   my $self = shift;

   $self->_backwards(TRUE);

   return $self;
}

sub basename {
   my ($self, @suffixes) = @_;

   return unless CORE::length $self->name;

   return File::Basename::basename($self->name, @suffixes);
}

sub binary {
   my $self = shift;

   $self->_sane_binmode if $self->_push_layer(':raw') && $self->is_open;

   return $self;
}

sub binmode {
   my ($self, $layer) = @_;

   $self->_sane_binmode($layer) if $self->_push_layer($layer) && $self->is_open;

   return $self;
}

sub block_size {
   my ($self, $size) = @_;

   $self->_block_size($size) if defined $size;

   return $self;
}

sub buffer {
   my $self = shift;

   if (@_) {
      my $buffer_ref  = ref $_[0] ? $_[0] : \$_[0];

      ${$buffer_ref} = NUL unless defined ${$buffer_ref};

      $self->{buffer} = $buffer_ref;
      return $self;
   }

   $self->{buffer} = do { my $x = NUL; \$x } unless exists $self->{buffer};

   return $self->{buffer};
}

sub canonpath {
   return File::Spec->canonpath( $_[0]->name );
}

sub catdir {
   my ($self, @args) = @_;

   return $self->child(@args)->dir;
}

sub catfile {
   my ($self, @args) = @_;

   return $self->child(@args)->file;
}

sub child {
   my ($self, @args) = @_;

   my $params = (is_hashref $args[-1]) ? pop @args : {};
   my $args   = [ grep { defined && CORE::length } $self->name, @args ];

   return $self->_constructor($args, $params);
}

sub chmod {
   my ($self, $perms) = @_;

   $perms //= $self->_perms; # uncoverable condition false
   CORE::chmod $perms, $self->name;
   return $self;
}

sub chomp {
   my $self = shift;

   $self->_chomp(TRUE);

   return $self;
}

sub chown {
   my ($self, $uid, $gid) = @_;

   $self->_throw(Unspecified, ['user or group id'])
      unless defined $uid and defined $gid;

   $self->_throw(
      'Path [_1 chown failed to [_2]/[_3]', [$self->name, $uid, $gid]
   ) unless 1 == CORE::chown $uid, $gid, $self->name;

   return $self;
}

sub clear {
   my $self = shift;

   ${$self->buffer} = NUL;

   return $self;
}

sub clone {
   my ($self, @args) = @_;

   throw 'Clone is an object method' unless blessed $self;

   return $self->_constructor($self, @args);
}

sub close {
   my $self = shift;

   return $self unless $self->is_open;

   if (is_ntfs) { # uncoverable branch true
      $self->_close_and_rename; # uncoverable statement
   } else { $self->_rename_and_close }

   $self->_set_io_handle(undef);
   $self->_set_is_open(FALSE);
   $self->_set_mode('r');

   return $self;
}

sub copy {
   my ($self, $to) = @_;

   $self->_throw(Unspecified, ['copy to']) unless $to;

   $to = $self->_constructor($to) unless blessed $to and $to->isa(__PACKAGE__);

   $self->_throw(
      'Cannot copy [_1] to [_2]', [$self->name, $to->pathname]
   ) unless File::Copy::copy($self->name, $to->pathname);

   return $to;
}

sub cwd {
   my ($self, @args) = @_;

   return $self->_constructor(Cwd::getcwd(), @args);
}

sub deep {
   my $self = shift;

   $self->_deep(TRUE);

   return $self;
}

sub delete {
   my $self = shift;
   my $path = $self->_get_atomic_path;

   unlink $path if $self->_atomic && -f $path;

   return $self->close;
}

sub delete_tmp_files {
   my ($self, $tmplt) = @_;

   $tmplt //= '%6.6d....';

   my $pat = sprintf $tmplt, $PID;

   while (my $entry = $self->next) {
      unlink $entry->pathname if $entry->filename =~ m{ \A $pat \z }mx;
   }

   return $self->close;
}

sub digest { # Robbed from Path::Tiny
   my ($self, @args) = @_;

   my $n = 0;

   $n++ while (defined $args[$n]);

   my $args = (            $n == 0) ? { algorithm => 'SHA-256'  }
            : (is_hashref $args[0]) ? { algorithm => 'SHA-256', %{$args[0]} }
            : (            $n == 1) ? { algorithm => $args[0] }
                                    : { algorithm => $args[0], %{$args[1]} };

   ensure_class_loaded 'Digest';

   my $digest = Digest->new($args->{algorithm});

   if ($args->{block_size}) {
      $self->binmode(':unix')->lock->block_size($args->{block_size});

      while ($self->read) {
         $digest->add(${$self->buffer});
         $self->clear;
      }
   }
   else { $digest->add($self->binmode(':unix')->lock->all) }

   return $digest;
}

sub dir {
   return shift->_init('dir', @_);
}

sub dirname {
   return CORE::length $_[0]->name ? File::Basename::dirname($_[0]->name) : NUL;
}

sub encoding {
   my ($self, $encoding) = @_;

   $self->_throw(Unspecified, ['encoding value']) unless $encoding;

   $self->_sane_binmode(":encoding($encoding)")
      if $self->_push_layer(":encoding($encoding)") && $self->is_open;

   return $self;
}

sub error_check {
   my $self = shift;

   $self->_throw('IO error: [_1]', [$OS_ERROR])
      if $self->io_handle->can('error') && $self->io_handle->error;

   return $self;
}

sub exists {
   return (CORE::length $_[0]->name && -e $_[0]->name) ? TRUE : FALSE;
}

sub extension {
   my $self = shift;

   my ($extension) = $self->filename =~ m{ \. ([^\.]+) \z }mx;

   return $extension;
}

sub fdopen {
   my ($self, $fd, $mode) = @_;

   $self->io_handle->fdopen($fd, $mode);
   $self->_set_is_open($self->io_handle->opened);
   $self->_set_mode($mode);
   $self->_set_name(NUL);
   $self->_set_type(undef);

   return $self;
}

sub file {
   return shift->_init('file', @_);
}

sub filename {
   my $self = shift;

   my (undef, undef, $file) = File::Spec->splitpath($self->name);

   return $file;
}

sub filepath {
   my $self = shift;

   my ($volume, $dir) = File::Spec->splitpath($self->name);

   return File::Spec->catpath($volume, $dir, NUL);
}

sub filter {
   my ($self, $filter) = @_;

   $self->_filter($filter) if defined $filter;

   return $self;
}

sub getline {
   my ($self, $separator) = @_;

   return $self->_getline_backwards if $self->_backwards;

   my $line;

   $self->assert_open;

   {  local $RS = $separator // $self->_separator; # uncoverable condition false
      $line = $self->io_handle->getline;
      CORE::chomp $line if defined $line and $self->_chomp;
   }

   $self->error_check;

   return $line if defined $line;

   $self->close if $self->autoclose;

   return;
}

sub getlines {
   my ($self, $separator) = @_;

   return $self->_getlines_backwards if $self->_backwards;

   my @lines;

   $self->assert_open;

   {  local $RS = $separator // $self->_separator; # uncoverable condition false
      @lines = $self->io_handle->getlines;

      if ($self->_chomp) { CORE::chomp for @lines }
   }

   $self->error_check;

   return (@lines) if scalar @lines;

   $self->close if $self->autoclose;

   return ();
}

sub head {
   my ($self, $lines) = @_;

   $lines //= 10;
   $self->close;

   my @res;

   while ($lines--) {
      defined (my $l = $self->getline) or last;
      push @res, $l;
   }

   $self->close;

   return wantarray ? @res : join NUL, @res;
}

sub hexdigest {
   my ($self, @args) = @_;

   return $self->digest(@args)->hexdigest;
}

sub is_absolute {
   return File::Spec->file_name_is_absolute($_[0]->name);
}

sub is_dir {
   my $self = shift;

   return FALSE unless CORE::length $self->name;

   return FALSE unless $self->type || $self->_init_type_from_fs;

   return $self->type eq 'dir' ? TRUE : FALSE;
}

sub is_empty {
   my $self = shift;
   my $name = $self->name;
   my $empty;

   $self->_throw(PathNotFound, [$name]) unless $self->exists;

   return -z $name ? TRUE : FALSE if $self->is_file;

   $empty = $self->next ? FALSE : TRUE;
   $self->close;
   return $empty;
}

*empty = \&is_empty; # Deprecated

sub is_executable {
   return (CORE::length $_[0]->name) && -x $_[0]->name ? TRUE : FALSE;
}

sub is_file {
   my $self = shift;

   return FALSE unless CORE::length $self->name;

   return FALSE unless $self->type || $self->_init_type_from_fs;

   return $self->type eq 'file' ? TRUE : FALSE;
}

sub is_link {
   return (CORE::length $_[0]->name) && -l $_[0]->name ? TRUE : FALSE;
}

sub is_readable {
   return (CORE::length $_[0]->name) && -r $_[0]->name ? TRUE : FALSE;
}

sub is_reading {
   my $mode = $_[1] // $_[0]->mode;

   return first { $_ eq $mode } qw( r r+ );
}

sub is_writable {
   return (CORE::length $_[0]->name) && -w $_[0]->name ? TRUE : FALSE;
}

sub is_writing {
   my $mode = $_[1] // $_[0]->mode;

   return first { $_ eq $mode } qw( a a+ w w+ );
}

sub iterator {
   my ($self, $args) = @_;

   $self->_throw("Path [_1] is not a directory", [$self->name])
      unless $self->is_dir;

   my @dirs   = ($self);
   my $filter = $self->_filter;
   my $deep   = $args->{recurse} // $self->_deep;
   my $follow = $args->{follow_symlinks} // not $self->_no_follow;

   return sub {
      while (@dirs) {
         while (defined (my $path = $dirs[0]->next)) {
            unshift @dirs, $path
               if $deep && $path->is_dir && ($follow || !$path->is_link);

            return $path if _should_include_path($filter, $path);
         }

         shift @dirs;
      }

      return;
   };
}

sub length {
   return CORE::length ${$_[0]->buffer};
}

sub lock {
   my ($self, $io_lock) = @_;

   $self->_lock($io_lock // LOCK_BLOCKING);

   return $self;
}

sub mkdir {
   my ($self, $perms) = @_;

   $perms ||= $self->_mkdir_perms;
   $self->_umask_push(oct '07777');
   CORE::mkdir($self->name, $perms);
   $self->_umask_pop;

   $self->_throw('Path [_1] cannot create: [_2]', [$self->name, $OS_ERROR])
      unless -d $self->name;

   return $self;
}

sub mkpath {
   my ($self, $perms) = @_;

   $perms ||= $self->_mkdir_perms;

   $self->_umask_push(oct '07777');
   ensure_class_loaded 'File::Path';
   File::Path::make_path($self->name, { mode => $perms });
   $self->_umask_pop;

   $self->_throw('Path [_1] cannot create: [_2]', [ $self->name, $OS_ERROR])
      unless -d $self->name;

   return $self;
}

sub move {
   my ($self, $to) = @_;

   $self->_throw(Unspecified, ['move to']) unless $to;

   $to = $self->_constructor($to) unless blessed $to and $to->isa(__PACKAGE__);

   $self->_throw('Cannot move [_1] to [_2]', [$self->name, $to->pathname])
      unless File::Copy::move($self->name, $to->pathname);

   return $to;
}

sub next {
   my $self = shift;
   my $name = $self->read_dir;

   return unless defined $name;

   my $io = $self->_constructor([$self->name, $name], {
      reverse => $self->reverse,
      sort    => $self->sort,
   });

   $io->filter($self->_filter) if defined $self->_filter;

   return $io;
}

sub no_follow {
   my $self = shift;

   $self->_no_follow(TRUE);

   return $self;
}

sub open {
   my ($self, $mode, $perms) = @_;

   $mode //= $self->mode;

   return $self if $self->is_open
      and first_char $mode eq first_char $self->mode;

   return $self if $self->is_open
      and 'r' eq first_char $mode
      and '+' eq (substr $self->mode, 1, 1) || NUL
      and $self->seek(0, SEEK_SET);

   $self->_init_type_from_fs unless $self->type;
   $self->file unless $self->type;
   $self->close if $self->is_open;

   return $self->is_dir
        ? $self->_open_dir ($self->_open_args($mode, $perms))
        : $self->_open_file($self->_open_args($mode, $perms));
}

sub parent {
   my ($self, $count) = @_;

   my $parent = $self;

   $count ||= 1;

   $parent = $self->_constructor($parent->dirname) while ($count--);

   return $parent;
}

sub pathname {
   return $_[0]->name;
}

sub perms {
   my ($self, $perms) = @_;

   $self->_set__perms($perms) if defined $perms;

   return $self;
}

sub print {
   return shift->assert_open('w')->_print(@_);
}

sub println {
   return shift->assert_open('w')->_println(@_);
}

sub read {
   my ($self, @args) = @_;

   $self->assert_open;

   my $length = @args || $self->is_dir
              ? $self->io_handle->read(@args)
              : $self->io_handle->read(
                   ${$self->buffer}, $self->_block_size, $self->length
                );

   $self->error_check;

   return $length || $self->autoclose && $self->close && 0;
}

sub read_dir {
   my $self = shift;

   $self->dir unless $self->type;

   $self->assert_open;

   return if $self->is_link && $self->_no_follow && $self->close;

   my $dir_pat = $self->_dir_pattern;
   my $name;

   if (wantarray) {
      my @names = grep { $_ !~ $dir_pat } $self->io_handle->read;

      $self->close;
      return @names;
   }

   while (not defined $name or $name =~ $dir_pat) {
      unless (defined ($name = $self->io_handle->read)) {
         $self->close;
         return;
      }
   }

   return $name;
}

sub rel2abs {
   my ($self, $base) = @_;

   return File::Spec->rel2abs($self->name, defined $base ? "${base}" : undef);
}

sub relative {
   my ($self, $base) = @_;

   $self->_set_name($self->abs2rel($base));

   return $self;
}

sub reset {
   my $self = shift;

   $self->close;
   $self->_assert(FALSE);
   $self->_atomic(FALSE);
   $self->_chomp(FALSE);
   $self->_deep(FALSE);
   $self->_lock(FALSE);
   $self->_no_follow(FALSE);

   return $self;
}

sub rmdir {
   my $self = shift;

   $self->_throw('Path [_1] not removed: [_2]', [$self->name, $OS_ERROR])
      unless CORE::rmdir $self->name;

   return $self;
}

sub rmtree {
   my ($self, @args) = @_;

   ensure_class_loaded 'File::Path';

   return File::Path::remove_tree($self->name, @args);
}

sub seek {
   my ($self, $posn, $whence) = @_;

   $self->assert_open(is_mswin ? 'r' : 'r+') unless $self->is_open;

   CORE::seek $self->io_handle, $posn, $whence;
   $self->error_check;
   return $self;
}

sub separator {
   my ($self, $sep) = @_;

   $self->_separator($sep) if $sep;

   return $self;
}

sub set_binmode {
   my $self = shift;

   $self->_push_layer() if is_ntfs; # uncoverable branch true

   $self->_sane_binmode($_) for (@{$self->_layers});

   return $self;
}

sub set_lock {
   my $self = shift;

   return unless $self->_lock;

   my $async = $self->_lock == LOCK_NONBLOCKING ? TRUE : FALSE;
   my $mode  = $self->mode eq 'r' ? LOCK_SH : LOCK_EX;

   $mode |= LOCK_NB if $async;

   $self->_set_have_lock((flock $self->io_handle, $mode) ? TRUE : FALSE);

   return $self;
}

sub sibling {
   my $self = shift; return $self->parent->child(@_);
}

sub slurp {
   my $self  = shift;
   my $slurp = $self->all;

   return $slurp unless wantarray;

   local $RS = $self->_separator;

   return split m{ (?<=\Q$RS\E) }mx, $slurp unless $self->_chomp;

   return map { CORE::chomp; $_ } split m{ (?<=\Q$RS\E) }mx, $slurp;
}

sub splitdir {
   return File::Spec->splitdir( $_[0]->name );
}

sub splitpath {
   return File::Spec->splitpath( $_[0]->name );
}

sub stat {
   my $self   = shift;
   my $exists = my @fields = stat($self->name);

   return unless $exists || $self->is_open;

   my %stat_hash = (id => $self->filename);

   @stat_hash{STAT_FIELDS()} = $exists ? @fields : stat($self->io_handle);

   return \%stat_hash;
}

sub substitute {
   my ($self, $search, $replace) = @_;

   $replace //= NUL;

   return $self unless defined $search and CORE::length $search;

   my $perms = $self->_untainted_perms;
   my $wtr   = $self->_constructor($self->name)->atomic;

   $wtr->perms($perms) if $perms;

   for ($self->getlines) {
      s{ $search }{$replace}gmx;
      $wtr->print($_);
   }

   $self->close;
   $wtr->close;
   return $self;
}

sub suffix {
   return shift->extension;
}

sub tail {
   my ($self, $lines, @args) = @_;

   $lines //= 10; $self->close;

   my @res;

   while ($lines--) {
      unshift @res, ($self->_getline_backwards(@args) or last);
   }

   $self->close;

   return wantarray ? @res : join NUL, @res;
}

sub tell {
   my $self = shift;

   $self->assert_open(is_mswin ? 'r' : 'r+') unless $self->is_open;

   return CORE::tell $self->io_handle;
}

sub tempfile {
   my ($self, $tmplt) = @_;

   $tmplt ||= '%6.6dXXXX';

   ensure_class_loaded 'File::Temp';

   my $tempdir = $self->name;

   $tempdir = File::Spec->tmpdir unless $tempdir && -d $tempdir;

   my $tmpfh = File::Temp->new(
      DIR => $tempdir, TEMPLATE => (sprintf $tmplt, $PID),
   );
   my $t = $self->_constructor($tmpfh->filename)->file;

   $t->_set_io_handle($tmpfh);
   $t->_set_is_open(TRUE);
   $t->_set_mode('w+');

   return $t;
}

sub touch {
   my ($self, $time) = @_;

   return unless CORE::length $self->name;

   $time //= time;

   $self->_open_file($self->_open_args('w'))->close unless -e $self->name;

   utime $time, $time, $self->name;
   return $self;
}

sub unlink {
   return unlink $_[0]->name;
}

sub unlock {
   my $self = shift;

   return unless $self->_lock;

   my $handle = $self->io_handle;

   flock $handle, LOCK_UN if $handle && $handle->opened;

   $self->_set_have_lock(FALSE);

   return $self;
}

sub utf8 {
   my $self = shift;

   $self->encoding('UTF-8');

   return $self;
}

sub visit {
   my ($self, $cb, $args) = @_;

   my $iter  = $self->iterator($args);
   my $state = {};

   while (defined (my $entry = $iter->())) {
      local $_ = $entry;
      my $r = $cb->($entry, $state);

      last if ref $r and not ${$r};
   }

   return $state;
}

sub write {
   my ($self, @args) = @_;

   $self->assert_open('w');

   my $length = @args
              ? $self->io_handle->write(@args)
              : $self->io_handle->write(${$self->buffer}, $self->length);

   $self->error_check;

   $self->clear unless scalar @args;

   return $length;
}

# Method installer
sub _proxy { # Methods handled by the IO::Handle object
   my ($proxy, $chain, $mode) = @_;

   my $package = caller;

   return if $package->can($proxy);

   install_sub { into => $package, as => $proxy, code => sub {
      my $self = shift;

      $self->assert_open($mode) if defined $mode;

      throw InvocantUndefined, [$proxy] unless defined $self->io_handle;

      my @results = $self->io_handle->$proxy(@_); # Mustn't copy stack args

      $self->error_check;

      return $self if $chain;

      return wantarray ? @results : $results[0];
   } };
}

_proxy( 'autoflush', TRUE );
_proxy( 'eof'             );
_proxy( 'fileno'          );
_proxy( 'flush',     TRUE );
_proxy( 'getc',      FALSE, 'r' );
_proxy( 'sysread',   FALSE, O_RDONLY );
_proxy( 'syswrite',  FALSE, O_CREAT | O_WRONLY );
_proxy( 'truncate',  TRUE );

# Attribute constructors
sub _build_dir_pattern {
   my $cd = curdir;
   my $ud = updir;

   return qr{ \A (?: \Q${cd}\E | \Q${ud}\E ) \z }mx;
}

# Private methods
sub _all_file_contents {
   my $self = shift;

   $self->assert_open unless $self->is_open;

   local $RS = undef;

   my $content = $self->io_handle->getline;

   $self->error_check;

   $self->close if $self->autoclose;

   return $content;
}

sub _assert_open_backwards {
   my ($self, @args) = @_;

   return if $self->is_open;

   ensure_class_loaded 'File::ReadBackwards';

   $self->_throw(
      'File [_1] cannot open backwards: [_2]', [$self->name, $OS_ERROR]
   ) unless $self->_set_io_handle(File::ReadBackwards->new($self->name, @args));

   $self->_set_is_open(TRUE);
   $self->_set_mode('r');
   $self->set_lock;
   $self->set_binmode;
   return;
}

sub _clone_one_of_us {
   my ($self, $params) = @_;

   $self->autoclose; $self->reverse; $self->sort; # Force evaluation

   my $clone = { %{$self}, %{$params // {}} };
   my $perms = delete $clone->{_perms};

   $clone->{perms} //= $perms;

   return $clone;
}

sub _close_and_rename { # This creates a race condition
   # uncoverable subroutine
   my $self = shift; # uncoverable statement
   my $handle;

   $self->unlock;

   if ($handle = $self->io_handle) {
      $handle->close;
      delete $self->{io_handle};
   }

   $self->_rename_atomic if $self->_atomic;

   return $self;
}

sub _constructor {
   my $self = shift;

   return (blessed $self)->new(@_);
}

sub _find {
   my ($self, $files, $dirs, $level) = @_;

   $level = $self->_deep ? 0 : 1 unless defined $level;

   my $filter = $self->_filter;
   my $follow = !$self->_no_follow;

   my (@all, $io);

   while ($io = $self->next) {
      my $is_dir = $io->is_dir;

      next unless defined $is_dir;

      push @all, $io if (($files && !$is_dir) || ($dirs && $is_dir))
         && _should_include_path($filter, $io);

      push @all, $io->_find($files, $dirs, $level ? $level - 1 : 0)
         if $is_dir && ($follow || !$io->is_link) && ($level != 1);
   }

   return @all unless $self->sort;

   return $self->reverse ? sort { $b->name cmp $a->name } @all
                         : sort { $a->name cmp $b->name } @all;
}

sub _get_atomic_path {
   my $self  = shift;
   my $path  = $self->filepath;
   my $infix = $self->_atomic_infix;
   my $tid   = thread_id;

   $infix =~ s{ \%P }{$PID}gmx if $infix =~ m{ \%P }mx;
   $infix =~ s{ \%T }{$tid}gmx if $infix =~ m{ \%T }mx;

   my $file;

   if ($infix =~ m{ \* }mx) {
      my $name = $self->filename;

      ($file = $infix) =~ s{ \* }{$name}mx;
   }
   else { $file = $self->filename.$infix }

   return $path ? _catfile($path, $file) : $file;
}

sub _getline_backwards {
   my ($self, @args) = @_;

   $self->_assert_open_backwards(@args);

   return $self->io_handle->readline;
}

sub _getlines_backwards {
   my $self = shift;

   my (@lines, $line);

   while (defined ($line = $self->_getline_backwards)) { push @lines, $line }

   return @lines;
}

sub _init {
   my ($self, $type, $name) = @_;

   $self->_set_io_handle(undef);
   $self->_set_is_open(FALSE);
   $self->_set_name($name) if ($name);
   $self->_set_mode('r');
   $self->_set_type($type);

   return $self;
}

sub _init_type_from_fs {
   my $self = shift;

   $self->_throw(Unspecified, ['path name']) unless CORE::length $self->name;

   return -f $self->name ? $self->file : -d _ ? $self->dir : undef;
}

sub _is_one_of_us {
   return (blessed $_[0]) && $_[0]->isa(__PACKAGE__);
}

sub _mkdir_perms { # Take file perms and add execute if read is true
   my ($self, $perms) = @_;

   $perms //= $self->_perms;

   return (($perms & oct '0444') >> 2) | $perms;
}

sub _open_args {
   my ($self, $mode, $perms) = @_;

   $self->_throw(Unspecified, ['path name']) unless CORE::length $self->name;

   my $pathname = $self->_atomic && !$self->is_reading($mode)
                ? $self->_get_atomic_path : $self->name;

   $perms = $self->_untainted_perms || $perms || $self->_perms;

   return ($pathname, $self->_set_mode($mode), $self->_set__perms($perms));
}

sub _open_dir {
   my ($self, $path) = @_;

   $self->assert_dirpath($path) if $self->_assert;

   $self->_throw('Directory [_1] cannot open', [$path])
      unless $self->_set_io_handle(IO::Dir->new($path));

   $self->_set_is_open(TRUE);

   return $self;
}

sub _open_file {
   my ($self, $path, $mode, $perms) = @_;

   $self->assert_filepath if $self->_assert;

   $self->_umask_push($perms);

   unless ($self->_set_io_handle(IO::File->new($path, $mode))) {
      $self->_umask_pop;
      $self->_throw('File [_1] cannot open', [$path]);
   }

   $self->_umask_pop;
   # TODO: Not necessary on normal systems
   CORE::chmod $perms, $path if $self->is_writing;

   $self->_set_is_open(TRUE);
   $self->set_lock;
   $self->set_binmode;

   return $self;
}

sub _print {
   my ($self, @args) = @_;

   for (@args) {
      $self->_throw('IO error: [_1]', [$OS_ERROR])
         unless print {$self->io_handle} $_;
   }

   return $self;
}

sub _println {
   my ($self, @args) = @_;

   return $self->_print(map { m{ [\n] \z }mx ? ($_) : ($_, "\n") } @args);
}

sub _push_layer {
   my ($self, $layer) = @_;

   $layer //= NUL;

   return FALSE if is_member $layer, $self->_layers;

   push @{$self->_layers}, $layer;

   return TRUE;
}

sub _rename_and_close { # This does not create a race condition
   my $self = shift;
   my $handle;

   $self->_rename_atomic if $self->_atomic;

   $self->unlock;

   if ($handle = $self->io_handle) {
      $handle->close;
      delete $self->{io_handle};
   }

   return $self;
}

sub _rename_atomic {
   my $self = shift;
   my $path = $self->_get_atomic_path;

   return unless -f $path;

   return if File::Copy::move($path, $self->name);

   $self->_throw(
      'Path [_1] move to [_2] failed: [_3]', [$path, $self->name, $OS_ERROR]
   ) unless is_ntfs;

   # Try this instead on ntfs
   warn 'NTFS: Path '.$self->name." move failure: ${OS_ERROR}\n";
   eval { CORE::unlink $self->name };

   my $os_error;

   $os_error = $OS_ERROR unless File::Copy::copy($path, $self->name);

   eval { CORE::unlink $path };

   $self->_throw(
      'Path [_1] copy to [_2] failed: [_3]', [$path, $self->name, $os_error]
   ) if $os_error;

   return;
}

sub _sane_binmode {
   my ($self, $layer) = @_;

   return if blessed $self->io_handle eq 'File::ReadBackwards';

   return $layer ? CORE::binmode($self->io_handle, $layer)
                 : CORE::binmode($self->io_handle);
}

sub _throw {
   my ($self, @args) = @_;

   eval { $self->unlock };

   throw @args;
}

sub _umask_pop {
   my $self  = shift;
   my $perms = $self->_umask->[-1];

   return umask unless (defined $perms and $perms != NO_UMASK_STACK);

   umask pop @{$self->_umask};

   return $perms;
}

sub _umask_push {
   my ($self, $perms) = @_;

   return umask unless $perms;

   my $first = $self->_umask->[0];

   return umask if defined $first and $first == NO_UMASK_STACK;

   $perms ^= oct '0777';
   push @{$self->_umask}, umask $perms;

   return $perms;
}

sub _untainted_perms {
   my $self = shift;

   return unless $self->exists;

   my $stat  = $self->stat // {};
   my $mode  = $stat->{mode} // NUL;
   my $perms = $mode =~ m{ \A (\d+) \z }mx ? $1 : 0;

   return $perms & oct '07777';
}

# Private functions
sub _catfile {
   return File::Spec->catfile( map { defined($_) ? $_ : NUL } @_ );
}

sub _coerce_name {
   my $name = shift;

   return unless defined $name;

   $name =  $name->()            if is_coderef   $name;
   $name =  "${name}"            if blessed      $name;
   $name =  $name->{name}        if is_hashref   $name;
   $name =  _catfile(@{$name})   if is_arrayref  $name;
   $name =  _expand_tilde($name) if first_char   $name eq TILDE;
   $name =  Cwd::getcwd()        if curdir eq    $name;
   $name =~ s{ [/\\] \z }{}mx    if CORE::length $name > 1;

   return $name;
}

sub _expand_tilde {
   my $path = shift;

   $path =~ m{ \A ([~] [^/\\]*) .* }mx;

   my ($dir) = glob($1);

   $path =~ s{ \A ([~] [^/\\]*) }{$dir}mx;

   return $path;
}

my @ARG_NAMES = qw( name mode perms );

sub _inline_args {
   my $n = shift;

   return (map { $ARG_NAMES[$_] => $_[$_] } 0 .. $n - 1);
}

sub _should_include_path {
   my ($filter, $path) = @_;

   return (!defined $filter || (map { $filter->() } ($path))[0]) ? TRUE : FALSE;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

File::DataClass::IO - A powerful and concise API to do as much file IO as possible

=head1 Synopsis

   use File::DataClass::IO;

   # Read the first line of a file and chomp the result
   my $line = io( 'path_name' )->chomp->getline;

   # Write the line to file set permissions, atomic update and fcntl locking
   io( 'path_name' )->perms( oct '0644' )->atomic->lock->print( $line );

   # Constructor methods signatures
   my $obj = io( $obj );            # clone
   my $obj = io( $obj, $hash_ref ); # clone and merge
   my $obj = io( $hash_ref );
   my $obj = io( $name );           # coderef, object ref, arrayref or string
   my $obj = io( $name, $hash_ref );
   my $obj = io( $name, $mode );
   my $obj = io( $name, $mode, $perms );
   my $obj = io( name => $name, mode => $mode, ... );

=head1 Description

This is a simplified re-write of L<IO::All> with additional functionality
from L<IO::AtomicFile>. Provides the same minimalist API but without the
heavy OO overloading. Only has methods for files and directories

=head1 Configuration and Environment

By default exports the C<io> function which calls the constructor and returns
the new L<File::DataClass::IO> object

L<File::DataClass::Constants> has a class attribute C<Exception_Class> which
defaults to L<File::DataClass::Exception>. Set this attribute to the
classname used by the L</_throw> method

Defines the following attributes;

=over 3

=item C<autoclose>

Defaults to true. Attempts to read past end of file will cause the
object to be closed

=item C<have_lock>

Defaults to false. Tracks the state of the lock on the underlying file

=item C<io_handle>

Defaults to undef. This is set when the object is actually opened

=item C<is_open>

Defaults to false. Set to true when the object is opened

=item C<mode>

File open mode. Defaults to 'r' for reading. Can any one of; 'a',
'a+', 'r', 'r+', 'w', or 'w+'

=item C<name>

Defaults to undef. This must be set in the call to the constructor or
soon after. Can be a C<coderef>, an C<objectref>, an C<arrayref>, or
a scalar. After coercion to a scalar leading tilde expansion takes place

=item C<reverse>

Boolean defaults to false. Reverse the direction of the sort on the output
of the directory listings

=item C<sort>

Boolean defaults to true. If the IO object is a directory then sort
the listings

=item C<type>

Defaults to undefined. Set by the L</dir> and L</file> methods to C<dir> and
C<file> respectively. The L</dir> method is called by the L</next>
method. The L</file> method is called by the L</assert_open> method if
the C<type> attribute is undefined

=back

=head1 Subroutines/Methods

If any errors occur the C<throw> method in the
L<File::DataClass::Constants/EXCEPTION_CLASS> is called

Methods beginning with an _ (underscore) are deemed private and should not
be called from outside this package

=head2 BUILDARGS

Constructs the attribute hash passed to the constructor method. The
constructor can be called with these method signatures:

=over 3

=item $io = File::DataClass::IO->new( { name => $pathname, ... } )

A hash ref containing a list of key value pairs which are the object's
attributes (where C<name> is the pathname, C<mode> the read/write/append flag,
and C<perms> the permissions on the file)

=item $io = File::DataClass::IO->new( $pathname, [ $mode, $perms ] )

A list of values which are taken as the pathname, mode and
permissions. The pathname can be an array ref, a coderef, a scalar,
or an object that stringifies to a scalar path

=item $io = File::DataClass::IO->new( $object_ref )

An object which is a L<File::DataClass::IO>

=back

=head2 BUILD

Open the file handle if it is closed and was supplied without a file name

=head2 clone

This object method returns a clone of the invocant

=head2 DEMOLISH

If this is an atomic file update calls the L</delete> method. If the
object is still open it calls the L</close> method

=head2 import

Exports the constructor function C<io> into the callers namespace

=head2 abs2rel

   $path = io( 'path_to_file' )->abs2rel( 'optional_base_path' );

Makes the pathname relative via a call to
L<abs2rel|File::Spec/abs2rel>. Returns a path

=head2 absolute

   $io = io( 'relative_path_to_file' )->absolute( 'optional_base_path' );

Calls L</rel2abs> without an optional base path. Returns an IO object ref

=head2 all

   $lines = io( 'path_to_file' )->all;

For a file read all the lines and return them as a single scalar

   @entries = io( 'path_to_directory' )->all( $level );

For directories returns a list of IO objects for all files and
subdirectories. Excludes L<File::Spec/curdir> and L<File::Spec/updir>

Takes an optional argument telling how many directories deep to
search. The default is 1. Zero (0) means search as deep as possible
The default can be changed to zero by calling the L</deep> method

The filter method can be used to limit the results

The items returned are sorted by name unless L</sort>(0) is used

=head2 all_dirs

   @entries = io( 'path_to_directory' )->all_dirs( $level );

Like C<< ->all( $level ) >> but returns only directories

=head2 all_files

   @entries = io( 'path_to_directory' )->all_files( $level );

Like C<< ->all( $level ) >> but returns only files

=head2 append

   io( 'path_to_file' )->append( $line1, $line2, ... );

Opens the file in append mode and calls L</print> with the passed args

=head2 appendln

   io( 'path_to_file' )->appendln( $line, $line2, ... );

Opens the file in append mode and calls L</println> with the passed args

=head2 as_boolean

   $bool = io( 'path_to_file' )->as_boolean;

Returns true if the pathname has been set or the file handle is open, returns
false otherwise. The boolean overload calls this

=head2 as_string

   $path_to_file = io( 'path_to_file' )->as_string;

Returns the pathname of the IO object. Overload stringifies to this

=head2 assert

   $io = io( 'path_to_file' )->assert;

Sets the private attribute C<_assert> to true. Causes the open methods
to create the path to the directory before the file/directory is
opened

   $io = io( 'path_to_file' )->assert( sub { $_->exists } );

When called with a code reference it sets C<$_> to self and asserts that
the code reference returns true. Throws otherwise. This feature was copied
from L<Path::Tiny>

=head2 assert_dirpath

   $dir_name = io( 'path_to_file' )->assert_dirpath;

Create the given directory if it doesn't already exist

=head2 assert_filepath

   $io = io( 'path_to_file' )->assert_filepath;

Calls L</assert_dirpath> on the directory part of the full pathname

=head2 assert_open

   $io = io( 'path_to_file' )->assert_open( $mode, $perms );

Calls L</file> to default the type if its not already set and then
calls L</open> passing in the optional arguments

=head2 atomic

   $io = io( 'path_to_file' )->atomic;

Implements atomic file updates by writing to a temporary file and then
renaming it on closure. This method uses the pattern in the
C<_atomic_infix> attribute to compute the temporary pathname

=head2 atomic_suffix

   $io = io( 'path_to_file' )->atomic_suffix( '.tmp' );

Syntactic sugar. See L</atomix_infix>

=head2 atomic_infix

   $io = io( 'path_to_file' )->atomic_infix( 'B_*' );

Defaults to C<B_*> (prefix). The C<*> is replaced by the filename to
create a temporary file for atomic updates. If the value does not
contain a C<*> then the value is appended to the filename instead
(suffix). Attribute name C<_atomic_infix>

If the value contains C<%P> it will be replaced with the process id

If the value contains C<%T> it will be replaces with the thread id

=head2 autoflush

   $io->autoflush( $bool );

Turns autoflush on or off on the file handle. Proxy method implemented by
L<IO::Handle>

=head2 backwards

   $io = io( 'path_to_file' )->backwards;

Causes L</getline> and L</getlines> to read the file backwards

=head2 basename

   $dirname = io( 'path_to_file' )->basename( @suffixes );

Returns the L<File::Basename> C<basename> of the passed path

=head2 binary

   $io = io( 'path_to_file' )->binary;

Sets binary mode

=head2 binmode

   $io = io( 'path_to_file' )->binmode( $layer );

Sets binmode to the given layer

=head2 block_size

   $io = io( 'path_to_file' )->block_size( 1024 );

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

   $io = io( 'path_to_directory' )->catdir( 'additional_directory_path' );

Create a new IO directory object by concatenating this objects pathname
with the one that is supplied

=head2 catfile

   $io = io( 'path_to_directory' )->catfile( 'additional_file_path' );

Create a new IO file object by concatenating this objects pathname
with the one that is supplied

=head2 child

   $io = io( 'path_to_directory' )->child( 'additional_file_path' );

Like L</catdir> and L</catfile> but does not set the object type

=head2 chmod

   $io = io( 'path_to_file' )->chmod( '0644' );

Changes the permission on the file to the selected value. Permission values
can be either octal or string

=head2 chomp

   $io = io( 'path_to_file' )->chomp;

Causes input lines to be chomped when L</getline> or L</getlines> are called

=head2 chown

   $io = io( 'path_to_file' )->chown( $uid, $gid );

Changes user and group ownership

=head2 clear

   $io->clear

Set the contents of the internal buffer to the null string

=head2 close

   $io->close;

Close the file or directory handle depending on type

If the temporary atomic file exists, renames it to the original
filename. Unlocks the file if it was locked. Closes the file handle

=head2 copy

   $dest_obj = io( 'path_to_file' )->copy( $destination_path_or_object );

Copies the file to the destination. The destination can be either a path or
and IO object. Returns the destination object

=head2 cwd

   $current_working_directory = io()->cwd;

Returns the current working directory wrapped in a L<File::DataClass::IO>
object

=head2 deep

   @files = io( 'path_to_root_of_tree' )->deep->all_files

Changes the default level for the L</all> methods to zero so
that the whole directory tree is searched

=head2 delete

Deletes the atomic update temporary file if it exists. Then calls
L</close>

=head2 delete_tmp_files

   $io = io( $tempdir )->delete_tmp_files( $template );

Delete temporary files for this process (temporary file names include
the process id). Temporary files are stored in the C<$tempdir>. Can override
the template filename pattern if required

=head2 digest

   $digest_object = io( 'path_to_file' )->digest( $algorithm, $options );

Returns a L<Digest> object which is calculated from the contents of the
specified file. The arguments are optional. The algorithm defaults to
C<SHA-256>. The C<$options> hash reference takes the C<block_size> parameter
which causes the file to read through the buffer C<block_size> bytes at a
time

This was robbed from L<Path::Tiny>

=head2 dir

Initialises the current object as a directory

=head2 dirname

   $dirname = io( 'path_to_file' )->dirname;

Returns the L<File::Basename> C<dirname> of the passed path

=head2 empty

   $bool = io( 'path_to_file' )->empty;

Deprecated in favour of L</is_empty>

=head2 encoding

   $io = io( 'path_to_file' )->encoding( $encoding );

Apply the given encoding to the open file handle and store it on the
C<_encoding> attribute

=head2 eof

   $bool = $io->eof;

Returns true if the file handle is at end of file. Proxy method implemented by
L<IO::Handle>

=head2 error_check

Tests to see if the open file handle is showing an error and if it is
it L</throw>s an C<eIOError>

=head2 extension

Returns the part of the filename after the last dot

=head2 exists

   $bool = io( 'path_to_file' )->exists;

Returns true if the pathname exists

=head2 fdopen

   $io = io()->fdopen( $fd, $mode );

Opens the internal file handle on the supplied file descriptor

=head2 file

Initialises the current object as a file

=head2 filename

   $filename = io( 'path_to_file' )->filename;

Returns the filename part of pathname

=head2 fileno

   $fileno = $io->fileno

Return the C<fileno> of the file handle. Proxy method implemented by
L<IO::Handle>

=head2 filepath

   $dirname = io( 'path_to_file' )->filepath;

Returns the directory part of pathname

=head2 filter

   $io = io( 'path_to_directory' )->filter( sub { m{ \A A_ }msx } );

Takes a subroutine reference that is used by the L</all> methods to
filter which entries are returned. Called with C<$_> set to each
pathname in turn. It should return true if the entry is wanted

=head2 flush

   $io->flush;

Flush the file handle. Proxy method implemented by L<IO::Handle>

=head2 getline

   $line = io( 'path_to_file' )->getline;

Asserts the file open for reading. Get one line from the file
handle. Chomp the line if the C<_chomp> attribute is true. Check for
errors. Close the file if the C<autoclose> attribute is true and end
of file has been read past

=head2 getc

   $one_character = $io->getc;

Reads one character from the file handle. Proxy method implemented by
L<IO::Handle>

=head2 getlines

   @lines = io( 'path_to_file' )->getlines;

Like L</getline> but calls L</getlines> on the file handle and returns
an array of lines

=head2 head

   @lines = io( 'path_to_file' )->head( $no_of_lines );

Returns the first I<n> lines from the file where the number of lines
returned defaults to 10. Returns the lines joined with null in a
scalar context

=head2 hexdigest

   $hex_digest = io( 'path_to_file' )->hexdigest( $algorithm, $options );

Returns a hexadecimal string which is calculated from the L</digest> object

=head2 _init

Sets default values for some attributes, takes two optional arguments;
C<type> and C<name>

=head2 is_absolute

   $bool = io( 'path_to_file' )->is_absolute;

Return true if the pathname is absolute

=head2 is_dir

   $bool = io( 'path_to_file' )->is_dir;

Tests to see if the IO object is a directory

=head2 is_empty

   $bool = io( 'path_to_file' )->is_empty;

Returns true if the pathname exists and is zero bytes in size

=head2 is_executable

   $bool = io( 'path_to_file' )->is_executable;

Tests to see if the IO object is executable

=head2 is_file

   $bool = io( 'path_to_file' )->is_file;

Tests to see if the IO object is a file

=head2 is_link

   $bool = io( 'path_to_file' )->is_link;

Returns true if the IO object is a symbolic link

=head2 is_readable

   $bool = io( 'path_to_file' )->is_readable;

Tests to see if the IO object is readable

=head2 is_reading

   $bool = io( 'path_to_file' )->is_reading;

Returns true if this IO object is in one of the read modes

=head2 is_writable

   $bool = io( 'path_to_file' )->is_writable;

Tests to see if the C<IO> object is writable

=head2 is_writing

   $bool = io( 'path_to_file' )->is_writing;

Returns true if this IO object is in one of the write modes

=head2 iterator

   $code_ref = io( 'path_to_directory' )->iterator( $options );

When called the coderef iterates over the directory listing. If C<deep> is true
then the iterator will visit all subdirectories. If C<no_follow> is true then
symbolic links to directories will not be followed. A L</filter> may also be
applied. The options hash takes C<recurse> which is used in preference to
C<deep>, and C<follow_symlinks> should be defined or C<no_follow> will be used

=head2 length

   $positive_int = io( 'path_to_file' )->length;

Returns the length of the internal buffer

=head2 lock

   $io = io( 'path_to_file' )->lock( $type );

Causes L</_open_file> to set a shared flock if its a read and an exclusive
flock for any other mode. The type is an enumerated value; C<FALSE> - no
locking, C<LOCK_BLOCKING> - blocking C<flock> call (the default), and
C<LOCK_NONBLOCKING> - non-blocking C<flock> call

=head2 mkdir

   io( 'path_to_directory' )->mkdir;

Create the specified directory

=head2 mkpath

   io( 'path_to_directory' )->mkpath;

Create the specified path

=head2 move

   $dest_obj = io( 'path_to_file' )->move( $destination_path_or_object );

Moves the file to the destination. The destination can be either a path or
and IO object. Returns the destination object

=head2 next

   $io = io( 'path_to_directory' )->next;

Calls L</dir> if the C<type> is not already set. Asserts the directory
open for reading and then calls L</read_dir> to get the first/next
entry. It returns an IO object for that entry

=head2 no_follow

   $io = io( 'path_to_directory' )->no_follow;

Defaults to false. If set to true do not follow symbolic links when
performing recursive directory searches

=head2 open

   $io = io( 'path_to_file' )->open( $mode, $perms );

Calls either L</_open_dir> or L</_open_file> depending on type. You do not
usually need to call this method directly. It is called as required by
L</assert_open>

=head2 _open_dir

If the C<_assert> attribute is true calls L</assert_dirpath> to create the
directory path if it does not exist. Opens the directory and stores the
handle on the C<io_handle> attribute

=head2 _open_file

Opens the pathname with the given mode and permissions. Calls
L</assert_filepath> if C<assert> is true. Mode defaults to the C<mode>
attribute value which defaults to C<r>. Permissions defaults to the
C<_perms> attribute value. Throws C<eCannotOpen> on error. If the open
succeeds L</set_lock> and L</set_binmode> are called

=head2 parent

   $parent_io_object = io( 'path_to_file_or_directory' )->parent( $count );

Return L</dirname> as an IO object. Repeat C<$count> times

=head2 pathname

   $pathname = io( 'path_to_file' )->pathname;

Returns then C<name> attribute

=head2 perms

   $io = io( 'path_to_file' )->perms( $perms );

Stores the given permissions on the C<_perms> attribute

=head2 print

   $io = io( 'path_to_file' )->print( $line1, $line2, ... );

Asserts that the file is open for writing and then prints passed list
of args to the open file handle. Throws C<ePrintError> if the C<print>
statement fails

=head2 println

   $io = io( 'path_to_file' )->println( $line1, $line2, ... );

Calls L</print> appending a newline to each of the passed list args
that doesn't already have one

=head2 read

   $bytes_read = io( 'path_to_file' )->read( $buffer, $length );

Asserts that the pathname is open for reading then calls L</read> on
the open file handle. If called with args then these are passed to the
L</read>. If called with no args then the internal buffer is used
instead. Returns the number of bytes read

=head2 read_dir

   @io_object_refs = io( 'path_to_directory' )->read_dir;
   $io = io( 'path_to_directory' )->read_dir;

If called in an array context returns a list of all the entries in the
directory. If called in a scalar context returns the first/next entry
in the directory

=head2 rel2abs

   $path = io( 'relative_path_to_file' )->rel2abs( 'optional_base_path' );

Makes the pathname absolute. Returns a path

=head2 relative

   $relative_path = io( 'path_to_file' )->relative( 'path_to_base' );

Calls L</abs2rel> with an optional base path

=head2 reset

   $io = io( 'path_to_file' )->reset;

Calls L</close> and resets C<chomp> to false

=head2 rmdir

   $io = io( 'path_to_directory' )->rmdir;

Remove the directory

=head2 rmtree

   $number_of_files_deleted = io( 'path_to_directory' )->rmtree;

Remove the directory tree

=head2 seek

   $io = io( 'path_to_file' )->seek( $position, $whence );

Seeks to the selected point in the file

=head2 separator

   $io = io( 'path_to_file' )->separator( $RS );

Set the record separator used in calls to getlines and chomp

=head2 set_binmode

   $io = io( 'path_to_file' )->set_binmode;

Sets the currently selected binmode on the open file handle

=head2 set_lock

   $io = io( 'path_to_file' )->set_lock;

Calls L</flock> on the open file handle

=head2 sibling

   $io = io( 'path_to_directory' )->sibling( 'additional_relative_path' );

A shortcut for calling C<< $io->parent->child >>. This feature was copied
from L<Path::Tiny>

=head2 slurp

   $lines = io( 'path_to_file' )->slurp;
   @lines = io( 'path_to_file' )->slurp;

In a scalar context calls L</all> and returns its value. In an array
context returns the list created by splitting the scalar return value
on the system record separator. Will chomp each line if required

=head2 splitdir

   @directories = io( 'path_to_directory' )->splitdir;

Proxy for L<File::Spec/splitdir>

=head2 splitpath

   ($volume, $directories, $file) = io( 'path_to_file' )->splitpath;

Proxy for L<File::Spec/splitpath>

=head2 stat

   $stat_hash_ref = io( 'path_to_file' )->stat;

Returns a hash of the values returned by a L</stat> call on the pathname.
Returns undefined if the file does not exist or the file handle is not open

=head2 substitute

   $io = io( 'path_to_file' )->substitute( $search, $replace );

Substitutes C<$search> regular expression for C<$replace> string on each
line of the given file

=head2 suffix

Returns the part of the filename after the last dot

=head2 sysread

   $red = $io->sysread( $buffer, $length, $offset );

Raw read bypasses the line buffering. Proxy method implemented by L<IO::Handle>

=head2 syswrite

   $wrote = $io->syswrite( $buffer, $length, $offset );

Write the buffer to the file by-passing the line buffering. Proxy method
implemented by L<IO::Handle>

=head2 tail

   @lines = io( 'path_to_file' )->tail( $no_of_lines );

Returns the last I<n> lines from the file where the number of lines
returned defaults to 10. Returns the lines joined with null in a
scalar context

=head2 tell

   $byte_offset = io( 'path_to_file' )->tell;

Returns the byte offset into the file

=head2 tempfile

   $io = io( 'path_to_temp_directory' )->tempfile( $template );

Create a randomly named temporary file in the C<name>
directory. The file name is prefixed with the creating processes id
and the temporary directory defaults to F</tmp>

=head2 _throw

   io( 'path_to_file' )->_throw( 'message', [] );

Exposes the C<throw> method in the exception class

=head2 touch

   $io = io( 'path_to_file' )->touch( $time );

Create a zero length file if one does not already exist with given
file system permissions which default to 0644 octal. If the file
already exists update it's last modified datetime stamp. If a value
for C<$time> is provided use that instead if the C<CORE::time>

=head2 truncate

   $io->truncate( $length );

Truncate the file at the specified length.  Proxy method implemented by
L<IO::Handle>

=head2 unlink

   $bool = io( 'path_to_file' )->unlink;

Delete the specified file. Returns true if successful

=head2 unlock

   $io = io( 'path_to_file' )->unlock;

Calls C<flock> on the open file handle with the C<LOCK_UN> option to
release the L<Fcntl> lock if one was set. Called by the L</close> method

=head2 utf8

   $io = io( 'path_to_file' )->utf8;

Sets the current encoding to utf8

=head2 visit

   $state = io( 'path_to_directory' )->visit( \&callback, $options );

Wrapper around a call to L</iterator>, calls the callback subroutine for
each entry. The options hash takes C<recurse> to set L</deep> to true and
C<follow_symlinks> should be true or L</no_follow> will be called.  The
callback subroutine is passed the io object reference and a hash reference
in which to accumulate state. In the callback subroutine C<$_> is also
localised to the current entry. The state hash reference is returned by
the method call. If the callback subroutine return a reference to a false
scalar value the loop around the call to L</iterator> terminates and the
state hash reference is returned. This feature was copied from L<Path::Tiny>

=head2 write

   $bytes_written = io( 'pathname' )->write( $buffer, $length );

Asserts that the file is open for writing then write the C<$length> bytes
from C<$buffer>. Checks for errors and returns the number of bytes
written. If C<$buffer> and C<$length> are omitted the internal buffer is
used. In this case the buffer contents are nulled out after the write

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::clean>

=item L<overload>

=item L<File::DataClass::Constants>

=item L<Moo>

=item L<Type::Utils>

=item L<Unexpected>

=back

=head1 Incompatibilities

On C<MSWin32> and C<Cygwin> platforms there is a race condition when the atomic
write option is used. This is caused by the filesystem which does not allow
an open file to be renamed

On C<MSWin32> and C<Cygwin> platforms if the move in atomic write option fails
a copy and delete is attempted. This will throw if the copy fails. These
platforms deny rename rights on newly created files by default

On C<MSWin32> and C<Cygwin> platforms C<binmode> is automatically enabled

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to the
address below. Patches are welcome

=head1 Acknowledgements

=over 3

=item Larry Wall

For the Perl programming language

=item Ingy döt Net <ingy@cpan.org>

For L<IO::All> from which I took the API and some tests

=item L<Path::Tiny>

Lifted the following features; iterator, tilde expansion, thread id in atomic
file name, not following symlinks, visit, sibling and some tests

=back

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2021 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# coding: utf-8
# mode: perl
# tab-width: 3
# End:
