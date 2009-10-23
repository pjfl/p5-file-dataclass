# @(#)$Id$

package File::DataClass::Storage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use File::DataClass::Constants;
use File::DataClass::HashMerge;
use Hash::Merge qw(merge);
use Moose;
use TryCatch;

with qw(File::DataClass::Util);

has 'cache'  => is => 'ro', isa => 'Object',  required => 1;
has 'debug'  => is => 'ro', isa => 'Bool',    default  => FALSE;
has 'extn'   => is => 'rw', isa => 'Str',     default  => NUL;
has 'lock'   => is => 'ro', isa => 'Object',  required => 1;
has 'log'    => is => 'ro', isa => 'Object',
   default   => sub { Class::Null->new };
has 'schema' => is => 'ro', isa => 'Object',  required => 1, weak_ref => TRUE;

sub delete {
   my ($self, $path, $element_obj) = @_;

   return $self->_delete( $path, $element_obj );
}

sub dump {
   my ($self, $path, $data) = @_;

   $self->throw( 'No file path specified' ) unless ($path);

   $self->lock->set( k => $path->pathname );

   return $self->_write_file( $path, $data, TRUE );
}

sub insert {
   my ($self, $path, $element_obj) = @_;

   return $self->_update( $path, $element_obj, FALSE, sub { TRUE } );
}

sub load {
   my ($self, @paths) = @_; $paths[0] || return {};

   return $self->_load( @paths );
}

sub select {
   my ($self, $path) = @_;
   my $elem          = $self->validate_params( $path );
   my $data          = $self->_read_file( $path, FALSE );

   return exists $data->{ $elem } ? $data->{ $elem } : {};
}

sub update {
   my ($self, $path, $element_obj, $overwrite, $condition) = @_;

   defined $overwrite or $overwrite = TRUE; $condition ||= sub { TRUE };

   return $self->_update( $path, $element_obj, $overwrite, $condition );
}

sub validate_params {
   my ($self, $path) = @_; my ($elem, $schema);

   $self->throw( 'No file path specified' ) unless ($path);
   $self->throw( 'Path is not blessed'    ) unless (blessed $path);
   $self->throw( 'No schema specified'    ) unless ($schema = $self->schema);
   $self->throw( 'No element specified'   ) unless ($elem = $schema->element);

   return $elem;
}

# Private methods

sub _delete {
   my ($self, $path, $element_obj) = @_;

   my $name = $element_obj->{name};
   my $elem = $self->validate_params( $path );
   my $data = $self->_read_file( $path, TRUE );

   if (exists $data->{ $elem } and exists $data->{ $elem }->{ $name }) {
      delete $data->{ $elem }->{ $name };
      delete $data->{ $elem } unless (scalar keys %{ $data->{ $elem } });
      $self->_write_file( $path, $data );
      return TRUE;
   }

   $self->lock->reset( k => $path->pathname );
   return FALSE;
}

sub _load {
   my ($self, @paths) = @_;
   my ($data, $stale) = $self->cache->get_by_paths( \@paths );

   return $data if ($data and not $stale);

   return $self->_read_file( $paths[0], FALSE ) || {} if (scalar @paths == 1);

   my $red; $data = {};

   for my $path (@paths) {
      next unless ($red = $self->_read_file( $path, FALSE ));

      for (keys %{ $red }) {
         $data->{ $_ } = exists $data->{ $_ }
                       ? merge( $data->{ $_ }, $red->{ $_ } )
                       : $red->{ $_ };
      }
   }

   $self->cache->set_by_paths( \@paths, $data );

   return $data;
}

sub _meta_pack {
   # Can be modified in a subclass
   my ($self, $mtime) = @_; return { mtime => $mtime };
}

sub _meta_unpack {
   # Can be modified in a subclass
   my ($self, $attrs) = @_; return $attrs->{mtime};
}

sub _read_file {
   my ($self, $path, $for_update) = @_;

   my $pathname = $path->pathname;

   $self->lock->set( k => $pathname );

   my $path_mtime    = $path->stat->{mtime};
   my ($data, $meta) = $self->cache->get( $pathname );
   my $cache_mtime   = $self->_meta_unpack( $meta );

   if (not $data or $cache_mtime < $path_mtime) {
      try        { $data = inner( $path->lock ) }
      catch ($e) { $self->lock->reset( k => $pathname ); $self->throw( $e ) }

      $self->cache->set( $pathname, $data, $self->_meta_pack( $path_mtime ) );
      $self->log->debug( "Read file  $pathname" ) if ($self->debug);
   }
   else {
      $self->log->debug( "Read cache $pathname" ) if ($self->debug);
   }

   $self->lock->reset( k => $pathname ) unless ($for_update);

   return $data;
}

sub _update {
   my ($self, $path, $element_obj, $overwrite, $condition) = @_;

   my $name = $element_obj->{name};
   my $elem = $self->validate_params( $path );
   my $data = $self->_read_file( $path, TRUE );

   if (not $overwrite and exists $data->{ $elem }->{ $name }) {
      $self->lock->reset( k => $path->pathname );
      $self->throw( error => 'File [_1] element [_2] already exists',
                    args  => [ $path->pathname, $name ] );
   }

   my $updated = File::DataClass::HashMerge->merge
      ( $element_obj, \$data->{ $elem }->{ $name }, $condition );

   if ($updated) { $self->_write_file( $path, $data ) }
   else { $self->lock->reset( k => $path->pathname ) }

   return $updated;
}

sub _write_file {
   my ($self, $path, $data, $create) = @_;

   my $pathname = $path->pathname;

   unless ($create or $path->is_file) {
      $self->throw( error => 'File [_1] not found', args => [ $pathname ] );
   }

   my $wtr = $path->atomic;

   $wtr->perms( $self->schema->source->perms ) if ($create);

   try        { $data = inner( $wtr->lock, $data ) }
   catch ($e) { $wtr->delete; $self->lock->reset( k => $pathname );
                $self->throw( $e ) }

   $wtr->close;
   $self->cache->remove( $pathname );
   $self->lock->reset( k => $pathname );
   return $data;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage - Storage base class

=head1 Version

0.1.$Revision$

=head1 Synopsis

=head1 Description

Storage base class

=head1 Subroutines/Methods

=head2 delete

   $bool = $storage->delete( $path, $element_obj );

Deletes the specified element object returning true if successful. Throws
an error otherwise. Path is an instance of L<File::DataClass::IO>

=head2 dump

   $data = $storage->dump( $path, $data );

Dumps the data to the specified path. Path is an instance of
L<File::DataClass::IO>

=head2 insert

   $bool = $storage->insert( $path, $element_obj );

Inserts the specified element object returning true if successful. Throws
an error otherwise. Path is an instance of L<File::DataClass::IO>

=head2 load

   $hash_ref = $storage->load( @paths );

Loads each of the specified files merging the resultant hash ref which
it returns. Paths are instances of L<File::DataClass::IO>

=head2 select

   $hash_ref = $storage->select( $path );

Returns a hash ref containing all the elements of the type specified in the
schema. Path is an instance of L<File::DataClass::IO>

=head2 update

   $bool = $storage->update( $path, $element_object, $overwrite, $condition );

Updates the specified element object returning true if successful. Throws
an error otherwise. Path is an instance of L<File::DataClass::IO>

=head2 validate_params

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Base>

=item L<File::DataClass::HashMerge>

=item L<Hash::Merge>

=item L<Scalar::Util>

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
