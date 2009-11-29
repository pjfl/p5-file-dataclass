# @(#)$Id$

package File::DataClass::Storage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use English qw(-no_match_vars);
use File::Copy;
use File::DataClass::Constants;
use File::DataClass::HashMerge;
use Hash::Merge qw(merge);
use Moose;
use TryCatch;

with qw(File::DataClass::Util);

has 'backup' => is => 'rw', isa => 'Str',    default  => NUL;
has 'extn'   => is => 'rw', isa => 'Str',    default  => NUL;
has 'schema' => is => 'ro', isa => 'Object', required => 1, weak_ref => TRUE;

sub delete {
   my ($self, $path, $element_obj) = @_;

   return $self->_delete( $path, $element_obj );
}

sub dump {
   my ($self, $path, $data) = @_;

   $self->validate_params( $path, TRUE );
   $self->_lock->set( k => $path );

   return $self->_write_file( $path, $data, TRUE );
}

sub insert {
   my ($self, $path, $element_obj) = @_;

   return $self->_update( $path, $element_obj, FALSE, sub { TRUE } );
}

sub load {
   my ($self, @paths) = @_; return $paths[0] ? $self->_load( @paths ) : {};
}

sub select {
   my ($self, $path, $element) = @_;

   $self->validate_params( $path, $element );

   my $data = $self->_read_file( $path, FALSE );

   return exists $data->{ $element } ? $data->{ $element } : {};
}

sub txn_do {
   my ($self, $path, $code_ref) = @_;

   $self->validate_params( $path, TRUE );

   my $key = q(txn:).$path->pathname; my $wantarray = wantarray; my $res;

   try {
      $self->_lock->set( k => $key );

      if ($wantarray) { @{ $res } = $code_ref->() }
      else { $res = $code_ref->() }

      $self->_lock->reset( k => $key );
   }
   catch ($e) { $self->_lock->reset( k => $key ); $self->throw( $e ) }

   return $wantarray ? @{ $res } : $res;
}

sub update {
   my ($self, $path, $element_obj, $overwrite, $condition) = @_;

   defined $overwrite or $overwrite = TRUE; $condition ||= sub { TRUE };

   return $self->_update( $path, $element_obj, $overwrite, $condition );
}

sub validate_params {
   my ($self, $path, $element) = @_;

   $path or $self->throw( 'No file path specified' );

   blessed $path or
      $self->throw( error => 'Path [_1] is not blessed', args => [ $path ] );

   $element or $self->throw( error => 'Path [_1] no element specified',
                             args  => [ $path ] );

   return;
}

# Private methods

sub _cache {
   return shift->schema->cache;
}

sub _debug {
   return shift->schema->debug;
}

sub _delete {
   my ($self, $path, $element_obj) = @_;

   my $element = $element_obj->_resultset->source->name;

   $self->validate_params( $path, $element );

   my $data = $self->_read_file( $path, TRUE );
   my $name = $element_obj->{name};

   if (exists $data->{ $element } and exists $data->{ $element }->{ $name }) {
      delete $data->{ $element }->{ $name };
      scalar keys %{ $data->{ $element } } or delete $data->{ $element };
      $self->_write_file( $path, $data );
      return TRUE;
   }

   $self->_lock->reset( k => $path->pathname );
   return FALSE;
}

sub _load {
   my ($self, @paths) = @_;

   my ($data, $meta, $newest) = $self->_cache->get_by_paths( \@paths );

   my $cache_mtime = $self->_meta_unpack( $meta );

   my $stale = $newest == 0 || $cache_mtime < $newest ? TRUE : FALSE;

   $data and not $stale and return $data;

   scalar @paths == 1 and return $self->_read_file( $paths[0], FALSE ) || {};

   $data = {};

   for my $path (@paths) {
      my $red = $self->_read_file( $path, FALSE ) or next;

      for (keys %{ $red }) {
         $data->{ $_ } = exists $data->{ $_ }
                       ? merge( $data->{ $_ }, $red->{ $_ } )
                       : $red->{ $_ };
      }
   }

   $self->_cache->set_by_paths( \@paths, $data, $self->_meta_pack( $newest ) );

   return $data;
}

sub _lock {
   return shift->schema->lock;
}

sub _log {
   return shift->schema->log;
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

   $self->_lock->set( k => $path );

   my $path_mtime    = $path->stat->{mtime};
   my ($data, $meta) = $self->_cache->get( $path );
   my $cache_mtime   = $self->_meta_unpack( $meta );

   if (not $data or $cache_mtime < $path_mtime) {
      try        { $data = inner( $path->_lock ); $path->close }
      catch ($e) { $self->_lock->reset( k => $path ); $self->throw( $e ) }

      $self->_cache->set( $path, $data, $self->_meta_pack( $path_mtime ) );
      $self->_log->debug( "Read file  $path" ) if ($self->_debug);
   }
   else {
      $self->_log->debug( "Read cache $path" ) if ($self->_debug);
   }

   $for_update or $self->_lock->reset( k => $path );

   return $data;
}

sub _update {
   my ($self, $path, $element_obj, $overwrite, $condition) = @_;

   my $element = $element_obj->_resultset->source->name;

   $self->validate_params( $path, $element );

   my $data = $self->_read_file( $path, TRUE );
   my $name = $element_obj->{name};

   if (not $overwrite and exists $data->{ $element }->{ $name }) {
      $self->_lock->reset( k => $path );
      $self->throw( error => 'File [_1] element [_2] already exists',
                    args  => [ $path, $name ] );
   }

   my $updated = File::DataClass::HashMerge->merge
      ( $element_obj, \$data->{ $element }->{ $name }, $condition );

   if ($updated) { $self->_write_file( $path, $data ) }
   else { $self->_lock->reset( k => $path ) }

   return $updated;
}

sub _write_file {
   my ($self, $path, $data, $create) = @_;

   $create or $path->is_file
      or $self->throw( error => 'File [_1] not found', args => [ $path ] );

   $path->is_file or $path->perms( $self->schema->perms );

   if ($self->backup and $path->is_file and not $path->empty) {
      copy( $path.NUL, $path.$self->backup ) or $self->throw( $ERRNO );
   }

   try        { $data = inner( $path->atomic->lock, $data ) }
   catch ($e) { $path->delete; $self->_lock->reset( k => $path );
                $self->throw( $e ) }

   $path->close;
   $self->_cache->remove( $path );
   $self->_lock->reset( k => $path );
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

=head2 txn_do

Executes the supplied coderef wrapped in lock on the pathname

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
