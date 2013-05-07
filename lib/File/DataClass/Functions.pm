# @(#)$Ident: Functions.pm 2013-04-30 01:31 pjf ;

package File::DataClass::Functions;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.20.%d', q$Rev: 0 $ =~ /\d+/gmx );

use Class::MOP;
use File::DataClass::Constants;
use English      qw(-no_match_vars);
use Hash::Merge  qw(merge);
use List::Util   qw(first);
use Scalar::Util qw(blessed);
use Try::Tiny;

my $osname = lc $OSNAME;
my $ntfs   = $osname eq EVIL || $osname eq CYGWIN ? TRUE : FALSE;
my @_functions;

BEGIN {
   @_functions = ( qw(ensure_class_loaded is_arrayref is_coderef is_hashref
                      is_member is_stale merge_attributes
                      merge_hash_data throw) );
}

use Sub::Exporter::Progressive -setup => {
   exports => [ @_functions ], groups => { default => [], },
};

# Private functions

sub ensure_class_loaded ($;$) {
   my ($class, $opts) = @_; $opts ||= {};

   my $package_defined = sub { Class::MOP::is_class_loaded( $class ) };

   not $opts->{ignore_loaded} and $package_defined->() and return 1;

   try   { Class::MOP::load_class( $class ) } catch { throw( $_ ) };

   $package_defined->()
      or throw( error => 'Class [_1] loaded but package undefined',
                args  => [ $class ] );

   return 1;
}

sub is_arrayref (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq q(ARRAY) ? 1 : 0;
}

sub is_coderef (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq q(CODE) ? 1 : 0;
}

sub is_hashref (;$) {
   return $_[ 0 ] && ref $_[ 0 ] eq q(HASH) ? 1 : 0;
}

sub is_member (;@) {
   my ($candidate, @rest) = @_; $candidate or return;

   is_arrayref $rest[ 0 ] and @rest = @{ $rest[ 0 ] };

   return (first { $_ eq $candidate } @rest) ? 1 : 0;
}

sub is_stale (;$$$) {
   my ($data, $cache_mtime, $path_mtime) = @_;

   $ntfs and return 1; # Assume NTFS does not support mtime

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

sub merge_hash_data ($$) {
   my ($existing, $new) = @_;

   for (keys %{ $new }) {
      $existing->{ $_ } = exists $existing->{ $_ }
                        ? merge( $existing->{ $_ }, $new->{ $_ } )
                        : $new->{ $_ };
   }

   return;
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

This document describes version v0.20.$Rev: 0 $

=head1 Synopsis

   use File::DataClass::Functions qw(list of functions to import);

=head1 Description

Common functions used in this distribution

=head1 Subroutines/Methods

=head2 ensure_class_loaded

   ensure_class_loaded( $some_class, \%options );

Require the requested class, throw an error if it doesn't load

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

=head2 merge_hash_data

   merge_hash_data $existing, $new;

Uses L<Hash::Merge> to merge data from the new hash ref in with the existing

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

=item L<Class::MOP>

=item L<Hash::Merge>

=item L<List::Util>

=item L<Scalar::Util>

=item L<Sub::Exporter>

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
