# @(#)$Id: Storage.pm 699 2009-10-02 17:57:19Z pjf $

package File::DataClass::Storage;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev: 699 $ =~ /\d+/gmx );
use parent qw(File::DataClass::Base);

use File::DataClass::HashMerge;
use Hash::Merge  qw(merge);
use Scalar::Util qw(weaken);
use TryCatch;

__PACKAGE__->config( path => q() );

__PACKAGE__->mk_accessors( qw(extn path schema) );

my $cache = {};

sub new {
   my ($self, $app, $attrs) = @_;

   my $new = $self->next::method( $app, $attrs );

   weaken( $new->{schema} );

   return $new;
}

sub delete {
   my ($self, $element_obj) = @_;

   return $self->_delete( $element_obj, $self->_validate_params );
}

sub dump {
   my ($self, $path, $data) = @_;

   $self->lock->set( k => $path->pathname );

   return $self->_write_file( $path, $data, 1 );
}

sub insert {
   my ($self, $element_obj) = @_;

   return $self->_update( $element_obj, $self->_validate_params, 0, sub { 1 });
}

sub load {
   my ($self, @paths) = @_; my $ref;

   return {} unless ($paths[0]);

   my ($data, $stale) = $self->_cache_get_by_paths( \@paths );

   return $data unless (not $data or $stale); $data = {};

   for my $path (@paths) {
      next unless ($ref = $self->_read_file( $path, 0 ));

      for (keys %{ $ref }) {
         $data->{ $_ } = exists $data->{ $_ }
                       ? merge( $data->{ $_ }, $ref->{ $_ } )
                       : $ref->{ $_ };
      }
   }

   $self->_cache_set_by_paths( \@paths, $data );

   return $data;
}

sub select {
   my $self          = shift;
   my ($path, $elem) = $self->_validate_params;
   my $data          = $self->_read_file( $path, 0 );

   return exists $data->{ $elem } ? $data->{ $elem } : {};
}

sub update {
   my ($self, $element_obj) = @_;

   return $self->_update( $element_obj, $self->_validate_params, 1, sub { 1 });
}

# Private methods

sub _cache {
   my ($self, $key, $value) = @_;

   return unless ($key);

   $cache->{ $key } = $value if (defined $value);

   return $cache->{ $key };
}

sub _cache_delete {
   my ($self, $key) = @_; delete $cache->{ $key }; return;
}

sub _cache_get {
   my ($self, $key) = @_; my $cached = $self->_cache( $key );

   return $cached ? ($cached->{data}, $cached->{mtime} || 0) : (undef, 0);
}

sub _cache_get_by_paths {
   my ($self, $paths) = @_;
   my ($key, $newest) = $self->_cache_key_and_mtime( $paths );
   my ($data, $mtime) = $self->_cache_get( $key );

   return ($data, $mtime < $newest);
}

sub _cache_key_and_mtime {
   my ($self, $paths) = @_; my ($key, $pathname); my $newest = 0;

   for my $path (@{ $paths }) {
      next unless ($pathname = $path->pathname);

      my ($data, $mtime) = $self->_cache_get( $pathname );

      $key    .= $key ? q(~).$pathname : $pathname;
      $mtime ||= $path->stat->{mtime} || 0;

      $newest = $mtime if ($mtime > $newest);
   }

   return ($key, $newest);
}

sub _cache_set {
   my ($self, $key, $data, $mtime) = @_;

   $self->_cache( $key, { data => $data, mtime => $mtime } );

   return ($data, $mtime);
}

sub _cache_set_by_paths {
   my ($self, $paths, $data) = @_;

   my ($key, $mtime) = $self->_cache_key_and_mtime( $paths );

   return $self->_cache_set( $key, $data, $mtime );
}

sub _delete {
   my ($self, $element_obj, $path, $element) = @_;

   my $updated = 0;
   my $name    = $element_obj->{name};
   my $data    = $self->_read_file( $path, 1 );

   if (exists $data->{ $element } and exists $data->{ $element }->{ $name }) {
      delete $data->{ $element }->{ $name };
      $self->_write_file( $path, $data );
      return 1;
   }

   $self->lock->reset( k => $path->pathname );
   return 0;
}

sub _read_file {
   my ($self, $path, $for_update) = @_;

   $self->throw( error => 'Method _read_file not overridden in [_1]',
                 args  => [ ref $self ] );
   return;
}

sub _read_file_with_locking {
   my ($self, $coderef, $path, $for_update) = @_;

   my $pathname = $path->pathname;

   $self->lock->set( k => $pathname );

   my $path_mtime     = $path->stat->{mtime};
   my ($data, $mtime) = $self->_cache_get( $pathname );

   if (not $data or $mtime < $path_mtime) {
      try        { $data = $coderef->() }
      catch ($e) { $self->lock->reset( k => $pathname ); $self->throw( $e ) }

      $self->_cache_set( $pathname, $data, $path_mtime );

      $self->log_debug( "Reread config $pathname" ) if ($self->debug);
   }
   else {
      $self->log_debug( "Cached config $pathname" ) if ($self->debug);
   }

   $self->lock->reset( k => $pathname ) unless ($for_update);

   return $data;
}

sub _update {
   my ($self, $element_obj, $path, $element, $overwrite, $condition) = @_;

   my $name = $element_obj->{name};
   my $data = $self->_read_file( $path, 1 );

   if (not $overwrite and exists $data->{ $element }->{ $name }) {
      $self->lock->reset( k => $path->pathname );
      $self->throw( error => 'File [_1] element [_2] already exists',
                    args  => [ $path->pathname, $name ] );
   }

   my $updated = File::DataClass::HashMerge->merge
      ( $element_obj, \$data->{ $element }->{ $name }, $condition );

   if ($updated) { $self->_write_file( $path, $data ) }
   else { $self->lock->reset( k => $path->pathname ) }

   return $updated;
}

sub _validate_params {
   my $self = shift; my ($elem, $path, $schema);

   $self->throw( 'No file path specified' ) unless ($path = $self->path);
   $self->throw( 'No schema specified'    ) unless ($schema = $self->schema);
   $self->throw( 'No element specified'   ) unless ($elem = $schema->element);

   return ($path, $elem);
}

sub _write_file {
   my ($self, $path, $data, $create) = @_;

   $self->throw( error => 'Method _write_file not overridden in [_1]',
                 args  => [ ref $self ] );
   return;
}

sub _write_file_with_locking {
   my ($self, $coderef, $path, $create) = @_; my $pathname = $path->pathname;

   unless ($create or ($pathname and -f $pathname)) {
      $self->throw( error => 'File [_1] not found', args => [ $pathname ] );
   }

   my $wtr = $path->perms( oct q(0664) )->atomic; my $data;

   try        { $data = $coderef->( $wtr ) }
   catch ($e) { $wtr->delete; $self->lock->reset( k => $pathname );
                $self->throw( $e ) }

   $wtr->close;
   $self->_cache_delete( $pathname );
   $self->lock->reset( k => $pathname );
   return $data;
}

1;

__END__

=pod

=head1 Name

File::DataClass::Storage - Factory subclass loader

=head1 Version

0.4.$Revision: 699 $

=head1 Synopsis

   package File::DataClass::Schema;

   use parent qw(File::DataClass::Base);
   use File::DataClass::Storage;
   use MRO::Compat;
   use Scalar::Util qw(weaken);

   __PACKAGE__->config( storage_class => q(File::DataClass::Storage) );

   __PACKAGE__->mk_accessors( qw(storage storage_class) );

   sub new {
      my ($self, $app, $attrs) = @_;

      my $new = $self->next::method( $app, $attrs );

      $attrs  = { %{ $attrs->{storage_attributes} || {} }, schema => $new };
      $new->storage( $new->storage_class->new( $app, $attrs ) );

      weaken( $new->storage->{schema} );
      return $new;
   }

=head1 Description

Loads and instantiates a factory subclass

=head1 Subroutines/Methods

=head2 new

=head2 delete

   $bool = $self->delete( $element_obj );

Deletes the specified element object returning true if successful. Throws
an error otherwise

=head2 dump

=head2 insert

   $bool = $self->insert( $element_obj );

Inserts the specified element object returning true if successful. Throws
an error otherwise

=head2 load

   $hash_ref = $self->load( @paths );

Loads each of the specified files merging the resultant hash ref which
it returns. Paths are instances of L<File::DataClass::IO>

=head2 select

   $hash_ref = $self->select;

Returns a hash ref containing all the elements of the type specified in the
schema

=head2 update

   $bool = $self->update( $element_obj );

Updates the specified element object returning true if successful. Throws
an error otherwise

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
