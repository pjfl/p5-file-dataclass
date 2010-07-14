# @(#)$Id$

package File::DataClass::Cache;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use CHI;
use Class::Null;
use File::DataClass::Constants;
use Moose;

with qw(File::DataClass::Util);

has 'cache_attributes' => is => 'ro', isa => 'HashRef',
   default             => sub { return {} };
has 'cache_class'      => is => 'ro', isa => 'ClassName',
   default             => q(CHI);
has 'cache'            => is => 'ro', isa => 'Object',
   lazy_build          => TRUE;
has 'schema'           => is => 'ro', isa => 'Object',
   required            => 1, weak_ref => TRUE,
   handles             => { _debug => q(debug), _log => q(log), };

has '_mtimes_key'      => is => 'ro', isa => 'Str',
   default             => q(_mtimes);

sub get {
   my ($self, $key) = @_; $key .= NUL;

   my $cached = $key    ? $self->cache->get( $key ) : FALSE;
   my $data   = $cached ? $cached->{data}           : undef;
   my $meta   = $cached ? $cached->{meta}           : { mtime => undef };

   return ($data, $meta);
}

sub get_by_paths {
   my ($self, $paths) = @_;
   my ($key, $newest) = $self->_get_key_and_newest( $paths );

   return ($self->get( $key ), $newest);
}

sub remove {
   my ($self, $key) = @_; $key or return; $key .= NUL;

   my $mtimes = $self->cache->get( $self->_mtimes_key ) || {};

   delete $mtimes->{ $key };
   $self->cache->set( $self->_mtimes_key, $mtimes );
   $self->cache->remove( $key );
   return;
}

sub set {
   my ($self, $key, $data, $meta) = @_;

   $key .= NUL; $meta ||= {}; $meta->{mtime} ||= undef;

   my $mt_key = $self->_mtimes_key;

   $key eq $mt_key and $self->throw( error => 'Cache key "[_1]" not allowed',
                                     args  => [ $mt_key ] );

   if ($key and defined $data) {
      $self->cache->set( $key, { data => $data, meta => $meta } );

      my $mtimes = $self->cache->get( $mt_key ) || {};

      $mtimes->{ $key } = $meta->{mtime};
      $self->cache->set( $mt_key, $mtimes );
   }

   return ($data, $meta);
}

sub set_by_paths {
   my ($self, $paths, $data, $meta) = @_; $meta ||= {};

   my ($key, $newest) = $self->_get_key_and_newest( $paths );

   $meta->{mtime} = $newest;

   return $self->set( $key, $data, $meta );
}

# Private methods

sub _build_cache {
   my $self = shift; my $attrs = $self->cache_attributes;

   my $class = delete $attrs->{cache_class} || $self->cache_class;

   $class eq q(none) and return Class::Null->new;

   $attrs->{on_set_error} = sub { $self->_log->error( $_[ 0 ] ) };

   return $class->new( %{ $attrs } );
}

sub _get_key_and_newest {
   my ($self, $paths) = @_; my $key; my $newest = 0; my $valid = TRUE;

   my $mtimes = $self->cache->get( $self->_mtimes_key ) || {};

   for my $path (map { NUL.$_ } grep { $_->pathname } @{ $paths }) {
      $key .= $key ? q(~).$path : $path; my $mtime;

      if ($mtime = $mtimes->{ $path }) { $mtime > $newest and $newest = $mtime }
      else { $valid = FALSE }
   }

   return ($key, $valid ? $newest : undef);
}

1;

__END__

=pod

=head1 Name

File::DataClass::Cache - Adds extra methods to the CHI API

=head1 Version

0.1.$Revision$

=head1 Synopsis

   package File::DataClass::Schema;

   use File::DataClass::Cache;
   use Moose;

   extends qw(File::DataClass);
   with    qw(File::DataClass::Constraints);

   has 'cache'            => is => 'ro', isa => 'F_DC_Cache',
      lazy_build          => TRUE;

   has 'cache_attributes' => is => 'ro', isa => 'HashRef',
      default             => sub { return {} };

   sub _build_cache {
      my $self  = shift;

      $self->Cache and return $self->Cache;

      my $attrs = {}; (my $ns = lc __PACKAGE__) =~ s{ :: }{-}gmx;

      $attrs->{cache_attributes}                = $self->cache_attributes;
      $attrs->{cache_attributes}->{driver   } ||= q(FastMmap);
      $attrs->{cache_attributes}->{root_dir } ||= NUL.$self->tempdir;
      $attrs->{cache_attributes}->{namespace} ||= $ns;

      return $self->Cache( File::DataClass::Cache->new( $attrs ) );
   }

=head1 Description

Adds meta data and compound keys to the L<CHI> caching API. In instance of
this class is created by L<File::DataClass::Schema>

=head1 Configuration and Environment

The class defines these attributes

=over 3

=item B<cache>

An instance of the L<CHI> cache object

=item B<cache_attributes>

A hash ref passed to the L<CHI> constructor

=item B<cache_class>

The class name of the cache object, defaults to L<CHI>

=back

=head1 Subroutines/Methods

=head2 get

   ($data, $meta) = $schema->cache->get( $key );

Returns the data and metadata associated with the given key. If no cache
entry exists the data returned is C<undef> and the metadata is a hash ref
with a key of C<mtime> and a value of C<0>

=head2 get_by_paths

   ($data, $meta, $newest) = $schema->cache->get_by_paths( $paths );

The paths passed in the array ref are concatenated to form a compound key.
The L<CHI> cache entry is fetched and the data and meta data returned along
with the modification time of the newest file in the list of paths

=head2 remove

   $schema->cache->remove( $key );

Removes the L<CHI> cache entry for the given key

=head2 set

   ($data, $meta) = $schema->cache->set( $key, $data, $meta );

Sets the L<CHI> cache entry for the given key

=head2 set_by_paths

   ($data, $meta) = $schema->cache->set_by_paths( $paths, $data, $meta );

Set the L<CHI> cache entry for the compound key formed from the array ref
C<$paths>

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<CHI>

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

Copyright (c) 2010 Peter Flanigan. All rights reserved

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
