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
has 'schema' => is => 'ro', isa => 'Object',  weak_ref => TRUE;

sub delete {
   my ($self, $path, $element_obj) = @_;

   return $self->_delete( $element_obj, $path );
}

sub dump {
   my ($self, $path, $data) = @_;

   $self->throw( 'No file path specified' ) unless ($path);

   $self->lock->set( k => $path->pathname );

   return $self->_write_file( $path, $data, TRUE );
}

sub insert {
   my ($self, $path, $element_obj) = @_;

   return $self->_update( $element_obj, $path, FALSE, sub { TRUE } );
}

sub load {
   my ($self, @paths) = @_; my $red;

   return {} unless ($paths[0]);

   my ($data, $stale) = $self->_cache_get_by_paths( \@paths );

   return $data if ($data and not $stale); $data = {};

   for my $path (@paths) {
      next unless ($red = $self->_read_file( $path, FALSE ));

      for (keys %{ $red }) {
         $data->{ $_ } = exists $data->{ $_ }
                       ? merge( $data->{ $_ }, $red->{ $_ } )
                       : $red->{ $_ };
      }
   }

   $self->_cache_set_by_paths( \@paths, $data );

   return $data;
}

sub select {
   my ($self, $path) = @_;
   my $elem          = $self->validate_params( $path );
   my $data          = $self->_read_file( $path, FALSE );

   return exists $data->{ $elem } ? $data->{ $elem } : {};
}

sub update {
   my ($self, $path, $element_obj, $overwrite, $condition) = @_;

   $overwrite ||= TRUE; $condition ||= sub { TRUE };

   return $self->_update( $element_obj, $path, $overwrite, $condition );
}

sub validate_params {
   my ($self, $path) = @_; my ($elem, $schema);

   $self->throw( 'No file path specified' ) unless ($path);
   $self->throw( 'No schema specified'    ) unless ($schema = $self->schema);
   $self->throw( 'No element specified'   ) unless ($elem = $schema->element);

   return $elem;
}

# Private methods

sub _cache_get {
   my ($self, $key) = @_;

   my $cached = $key    ? $self->cache->get( $key ) : FALSE;
   my $data   = $cached ? $cached->{data }          : undef;
   my $mtime  = $cached ? $cached->{mtime} || 0     : 0;

   return ($data, $mtime);
}

sub _cache_get_by_paths {
   my ($self, $paths) = @_;
   my ($key, $newest) = $self->_cache_get_key_and_newest( $paths );
   my ($data, $mtime) = $self->_cache_get( $key );

   return ($data, $mtime < $newest);
}

sub _cache_get_key_and_newest {
   my ($self, $paths) = @_; my ($key, $pathname); my $newest = 0;

   my $mtimes = $self->cache->get( q(mtimes) ) || {};

   for my $path (@{ $paths }) {
      next unless ($pathname = $path->pathname);

      $key .= $key ? q(~).$pathname : $pathname;

      my $mtime = $mtimes->{ $pathname } || 0;

      $newest = $mtime if ($mtime > $newest);
   }

   return ($key, $newest);
}

sub _cache_remove {
   my ($self, $key) = @_;

   return unless ($key);

   my $mtimes = $self->cache->get( q(mtimes) ) || {};

   delete $mtimes->{ $key };
   $self->cache->set( q(mtimes), $mtimes );
   $self->cache->remove( $key );
   return;
}

sub _cache_set {
   my ($self, $key, $data, $mtime) = @_;

   if ($key) {
      $self->cache->set( $key, { data => $data, mtime => $mtime || 0 } );

      my $mtimes = $self->cache->get( q(mtimes) ) || {};

      $mtimes->{ $key } = $mtime;
      $self->cache->set( q(mtimes), $mtimes );
   }

   return ($data, $mtime);
}

sub _cache_set_by_paths {
   my ($self, $paths, $data) = @_;

   my ($key, $newest) = $self->_cache_get_key_and_newest( $paths );

   return $self->_cache_set( $key, $data, $newest );
}

sub _delete {
   my ($self, $element_obj, $path) = @_;

   my $name = $element_obj->{name};
   my $elem = $self->validate_params( $path );
   my $data = $self->_read_file( $path, TRUE );

   if (exists $data->{ $elem } and exists $data->{ $elem }->{ $name }) {
      delete $data->{ $elem }->{ $name };
      delete $data->{ $elem } if (0 <= scalar keys %{ $data->{ $elem } });
      $self->_write_file( $path, $data );
      return TRUE;
   }

   $self->lock->reset( k => $path->pathname );
   return FALSE;
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

      $self->log->debug( "Read file  $pathname" ) if ($self->debug);
   }
   else {
      $self->log->debug( "Read cache $pathname" ) if ($self->debug);
   }

   $self->lock->reset( k => $pathname ) unless ($for_update);

   return $data;
}

sub _update {
   my ($self, $element_obj, $path, $overwrite, $condition) = @_;

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
   $self->_cache_remove( $pathname );
   $self->lock->reset( k => $pathname );
   return $data;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage - Factory subclass loader

=head1 Version

0.1.$Revision$

=head1 Synopsis

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
