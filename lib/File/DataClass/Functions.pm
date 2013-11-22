# @(#)$Ident: Functions.pm 2013-09-25 12:28 pjf ;

package File::DataClass::Functions;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.27.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Load    qw( is_class_loaded load_class );
use English        qw( -no_match_vars );
use Exporter 5.57  qw( import );
use File::DataClass::Constants;
use Hash::Merge    qw( merge );
use List::Util     qw( first );
use Scalar::Util   qw( blessed );
use Try::Tiny;

our @EXPORT_OK   = qw( ensure_class_loaded first_char is_arrayref is_coderef
                       is_hashref is_member is_stale merge_attributes
                       merge_file_data thread_id throw );
our %EXPORT_TAGS =   ( all => [ @EXPORT_OK ], );

my $LC_OSNAME    = lc $OSNAME;
my $NTFS         = $LC_OSNAME eq EVIL || $LC_OSNAME eq CYGWIN ? TRUE : FALSE;

# Public functions
sub ensure_class_loaded ($;$) {
   my ($class, $opts) = @_; $opts ||= {};

   my $package_defined = sub { is_class_loaded( $class ) };

   not $opts->{ignore_loaded} and $package_defined->() and return 1;

   try { load_class( $class ) } catch { throw( $_ ) };

   $package_defined->()
      or throw( error => 'Class [_1] loaded but package undefined',
                args  => [ $class ] );

   return 1;
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
   my ($candidate, @rest) = @_; $candidate or return;

   is_arrayref $rest[ 0 ] and @rest = @{ $rest[ 0 ] };

   return (first { $_ eq $candidate } @rest) ? 1 : 0;
}

sub is_stale (;$$$) {
   my ($data, $cache_mtime, $path_mtime) = @_;

   $NTFS and return 1; # Assume NTFS does not support mtime

   return ! defined $data || ! defined $path_mtime || ! defined $cache_mtime
         || $path_mtime > $cache_mtime
          ? 1 : 0;
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

sub thread_id {
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

=head1 Version

This document describes version v0.27.$Rev: 1 $

=head1 Synopsis

   use File::DataClass::Functions qw(list of functions to import);

=head1 Description

Common functions used in this distribution

=head1 Subroutines/Methods

=head2 ensure_class_loaded

   ensure_class_loaded( $some_class, \%options );

Require the requested class, throw an error if it doesn't load

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

=head2 merge_attributes

   $dest = merge_attributes $dest, $src, $attr_list_ref;

Merges attribute hashes. The C<$dest> hash is updated and
returned. The C<$dest> hash values take precedence over the C<$src>
hash values. The C<$src> hash may be an object in which case its
accessor methods are called

=head2 merge_file_data

   merge_file_data $existing, $new;

Uses L<Hash::Merge> to merge data from the new hash ref in with the existing

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

=item L<Class::Load>

=item L<Exporter>

=item L<Hash::Merge>

=item L<Try::Tiny>

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

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
