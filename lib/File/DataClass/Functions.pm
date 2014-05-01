package File::DataClass::Functions;

use 5.010001;
use strict;
use warnings;
use feature 'state';

use English               qw( -no_match_vars );
use Exporter 5.57         qw( import );
use File::DataClass::Constants;
use Hash::Merge           qw( merge );
use List::Util            qw( first );
use Module::Pluggable::Object;
use Module::Runtime       qw( require_module );
use Scalar::Util          qw( blessed );
use Try::Tiny;
use Unexpected::Functions qw( is_class_loaded );

our @EXPORT_OK    = qw( ensure_class_loaded extension_map first_char
                        is_arrayref is_coderef is_hashref is_member
                        is_stale qualify_storage_class map_extension2class
                        merge_attributes merge_file_data supported_extensions
                        thread_id throw );
our %EXPORT_TAGS  =   ( all => [ @EXPORT_OK ], );

my $LC_OSNAME     = lc $OSNAME;
my $NTFS          = $LC_OSNAME eq EVIL || $LC_OSNAME eq CYGWIN ? 1 : 0;

# Public functions
sub ensure_class_loaded ($;$) {
   my ($class, $opts) = @_; $opts ||= {};

   not $opts->{ignore_loaded} and is_class_loaded( $class ) and return 1;

   try { require_module( $class ) } catch { throw( $_ ) };

   is_class_loaded( $class )
      or throw( error => 'Class [_1] loaded but package undefined',
                args  => [ $class ] );

   return 1;
}

sub extension_map (;$$) {
   my ($class, $extensions) = @_; state $map //= { '_map_loaded' => 0 };

   if (defined $class) {
      if (defined $extensions) {
         is_arrayref( $extensions ) or $extensions = [ $extensions ];

         for my $extn (@{ $extensions }) {
            $map->{ $extn } //= []; is_member( $class, $map->{ $extn } )
               or push @{ $map->{ $extn } }, $class;
         }
      }

      return;
   }

   $map->{ '_map_loaded' } and return $map;

   my $base       = STORAGE_BASE;
   my $exceptions = STORAGE_EXCEPTIONS;
   my $finder     = Module::Pluggable::Object->new
      ( except => [ $exceptions ], search_path => [ $base ], require => 1, );

   $finder->plugins; $map->{ '_map_loaded' } = 1;

   return $map;
}

sub first_char ($) {
   return substr $_[ 0 ], 0, 1;
}

sub is_arrayref (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq 'ARRAY' ? 1 : 0;
}

sub is_coderef (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq 'CODE' ? 1 : 0;
}

sub is_hashref (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq 'HASH' ? 1 : 0;
}

sub is_member (;@) {
   my ($candidate, @args) = @_; $candidate or return;

   is_arrayref $args[ 0 ] and @args = @{ $args[ 0 ] };

   return (first { $_ eq $candidate } @args) ? 1 : 0;
}

sub is_stale (;$$$) {
   my ($data, $cache_mtime, $path_mtime) = @_;

   # Assume NTFS does not support mtime
   $NTFS and return 1; # uncoverable branch true

   my $is_def = defined $data && defined $path_mtime && defined $cache_mtime;

   return !$is_def || $path_mtime > $cache_mtime ? 1 : 0;
}

sub map_extension2class ($) {
   my $map = extension_map();

   return exists $map->{ $_[ 0 ] } ? $map->{ $_[ 0 ] } : undef;
}

sub merge_attributes ($$;$) {
   my ($dest, $src, $attrs) = @_; my $class = blessed $src;

   for (grep { not exists $dest->{ $_ } or not defined $dest->{ $_ } }
        @{ $attrs || [] }) {
      my $v = $class ? ($src->can( $_ ) ? $src->$_() : undef) : $src->{ $_ };

      defined $v and $dest->{ $_ } = $v;
   }

   return $dest;
}

sub merge_file_data ($$) {
   my ($existing, $new) = @_;

   for (keys %{ $new }) {
      $existing->{ $_ } = exists $existing->{ $_ }
                        ? merge( $existing->{ $_ }, $new->{ $_ } )
                        : $new->{ $_ };
   }

   return;
}

sub qualify_storage_class ($) {
   return STORAGE_BASE.'::'.$_[ 0 ];
}

sub supported_extensions () {
   return grep { not m{ \A _ }mx } keys %{ extension_map() };
}

sub thread_id () {
   # uncoverable branch true
   return exists $INC{ 'threads.pm' } ? threads->tid() : 0;
}

sub throw (;@) {
   EXCEPTION_CLASS->throw( @_ );
}

1;

__END__

=pod

=head1 Name

File::DataClass::Functions - Common functions used in this distribution

=head1 Synopsis

   use File::DataClass::Functions qw(list of functions to import);

=head1 Description

Common functions used in this distribution

=head1 Subroutines/Methods

=head2 ensure_class_loaded

   ensure_class_loaded( $some_class, \%options );

Require the requested class, throw an error if it doesn't load

=head2 extension_map

   $map   = extension_map;                     # Accessor
   $value = extension_map $class, $extensions; # Mutator

An accessor / mutator for the stateful hash reference that maps filename
extensions onto storage classes. Calling the accessor populates the
extension map on first use. Storage subclasses call the mutator to
register the extensions that they handle. If the C<$extensions>
parameter is an array reference then the storage subclass can
"claim ownership" of more than one extension in a single call

=head2 first_char

   $single_char = first_char $some_string;

Returns the first character of C<$string>

=head2 is_arrayref

   $bool = is_arrayref $scalar_variable

Tests to see if the scalar variable is an array ref

=head2 is_coderef

   $bool = is_coderef $scalar_variable

Tests to see if the scalar variable is a code ref

=head2 is_hashref

   $bool = is_hashref $scalar_variable

Tests to see if the scalar variable is a hash ref

=head2 is_member

   $bool = is_member q(test_value), qw(a_value test_value b_value);

Tests to see if the first parameter is present in the list of
remaining parameters

=head2 is_stale

   $bool = is_stale $data, $cache_mtime, $path_mtime;

Returns true if there is no data or the cache mtime is older than the
path mtime

=head2 map_extension2class

   $array_ref_of_class_name = map_extension2class $extension;

Maps a filename extensions to a storage classes

=head2 merge_attributes

   $dest = merge_attributes $dest, $src, $attr_list_ref;

Merges attribute hashes. The C<$dest> hash is updated and
returned. The C<$dest> hash values take precedence over the C<$src>
hash values. The C<$src> hash may be an object in which case its
accessor methods are called

=head2 merge_file_data

   merge_file_data $existing, $new;

Uses L<Hash::Merge> to merge data from the new hash ref in with the existing

=head2 qualify_storage_class

   $storage_classname = qualify_storage_class $class_suffix;

Prepends the C<STORAGE_BASE> classname to the supplied suffix

=head2 supported_extensions

   @list_of_extension_names = supported_extensions;

Returns a list of supported filename extensions

=head2 thread_id

   $thread_id = thread_id;

Returns the current thread id or zero if the the L<threads> module has
not been loaded

=head2 throw

   throw error => q(error_key), args => [ q(error_arg) ];

Expose L<CatalystX::Usul::Exception/throw>. C<CX::Usul::Functions> has a
class attribute I<Exception_Class> which can be set via a call to
C<set_inherited>

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Exporter>

=item L<Hash::Merge>

=item L<Module::Runtime>

=item L<Try::Tiny>

=item L<Unexpected>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
