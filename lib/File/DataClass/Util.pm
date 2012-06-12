# @(#)$Id$

package File::DataClass::Util;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.10.%d', q$Rev$ =~ /\d+/gmx );

use Moose::Role;
use Class::MOP;
use File::Spec;
use List::Util        qw(first);
use Try::Tiny;
use File::DataClass::Constants;
use File::DataClass::IO ();
use Hash::Merge       qw(merge);

sub basename {
   my ($self, $path, @suffixes) = @_;

   return $self->io( NUL.$path )->basename( @suffixes );
}

sub catdir {
   my $self = shift; return File::Spec->catdir( @_ );
}

sub catfile {
   my $self = shift; return File::Spec->catfile( @_ );
}

sub dirname {
   my ($self, $path) = @_; return $self->io( NUL.$path )->dirname;
}

sub ensure_class_loaded {
   my ($self, $class, $opts) = @_; $opts ||= {};

   my $package_defined = sub { Class::MOP::is_class_loaded( $class ) };

   not $opts->{ignore_loaded} and $package_defined->() and return TRUE;

   try   { Class::MOP::load_class( $class ) }
   catch { $self->throw( $_ ) };

   $package_defined->() and return TRUE;

   $self->throw( error => 'Class [_1] loaded but package undefined',
                 args  => [ $class ] );
   return; # Not reached
}

sub extensions {
   return { '.json' => [ q(JSON) ],
            '.xml'  => [ q(XML::Simple), q(XML::Bare) ], };
}

sub io {
   my ($self, @rest) = @_; return File::DataClass::IO->new( @rest );
}

sub is_member {
   my ($self, $candidate, @rest) = @_; $candidate or return;

   return (first { $_ eq $candidate } @rest) ? TRUE : FALSE;
}

sub is_stale {
   my ($self, $data, $cache_mtime, $path_mtime) = @_;

   return ! defined $data || ! defined $path_mtime || ! defined $cache_mtime
         || $path_mtime > $cache_mtime
          ? TRUE : FALSE;
}

sub merge_hash_data {
   my ($self, $existing, $new) = @_;

   for (keys %{ $new }) {
      $existing->{ $_ } = exists $existing->{ $_ }
                        ? merge( $existing->{ $_ }, $new->{ $_ } )
                        : $new->{ $_ };
   }

   return;
}

sub throw {
   my $self = shift; EXCEPTION_CLASS->throw( @_ ); return; # Not reached
}

no Moose::Role;

1;

__END__

=pod

=head1 Name

File::DataClass::Util - Moose Role defining utility methods

=head1 Version

0.10.$Revision$

=head1 Synopsis

   use Moose;

   with qw(File::DataClass::Util);

=head1 Description

=head1 Subroutines/Methods

=head2 basename

=head2 catdir

=head2 catfile

=head2 dirname

=head2 ensure_class_loaded

=head2 extensions

Returns a hash ref whose keys are the supported extensions and whose values
are an array ref of storage subclasses that implement reading/writing files
with that extension

=head2 io

=head2 is_member

=head2 is_stale

   $bool = $self->is_stale( $data, $cache_mtime, $path_mtime );

Returns true if there is no data or the cache mtime is older than the
path mtime

=head2 merge_hash_data

   $self->merge_hash_data( $existsing, $new );

Uses L<Hash::Merge> to merge data from the new hash ref in with the existsing

=head2 throw

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::MOP>

=item L<File::DataClass::IO>

=item L<Hash::Merge>

=item L<List::Util>

=item L<Moose::Role>

=item L<Try::Tiny>

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

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
