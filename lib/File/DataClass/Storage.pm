# @(#)$Id$

package File::DataClass::Storage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.10.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use Class::Null;
use English     qw(-no_match_vars);
use File::Copy;
use File::DataClass::Constants;
use File::DataClass::HashMerge;
use Hash::Merge qw(merge);
use Try::Tiny;

with qw(File::DataClass::Util);

has 'backup' => is => 'ro', isa => 'Str',    default  => NUL;
has 'extn'   => is => 'ro', isa => 'Str',    default  => NUL;
has 'schema' => is => 'ro', isa => 'Object', required => TRUE, weak_ref => TRUE,
   handles   => { _cache => q(cache), _debug => q(debug), _lock => q(lock),
                  _log   => q(log),   _perms => q(perms) };

sub delete {
   my ($self, $path, $result) = @_;

   my $element = $result->_resultset->source->name;

   $self->validate_params( $path, $element );

   my $data = ($self->_read_file( $path, TRUE ))[ 0 ] || {};
   my $name = $result->name;

   if (exists $data->{ $element } and exists $data->{ $element }->{ $name }) {
      delete $data->{ $element }->{ $name };
      scalar keys %{ $data->{ $element } } or delete $data->{ $element };
      $self->_write_file( $path, $data );
      return TRUE;
   }

   $self->_lock->reset( k => $path );
   return FALSE;
}

sub dump {
   my ($self, $path, $data) = @_;

   return $self->txn_do( $path, sub {
      $self->_lock->set( k => $path );
      $self->_write_file( $path, $data, TRUE ) } );
}

sub extensions {
   return { '.json' => [ q(JSON) ],
            '.xml'  => [ q(XML::Simple), q(XML::Bare) ], };
}

sub insert {
   my ($self, $path, $result) = @_;

   return $self->_create_or_update( $path, $result, FALSE, sub { TRUE } );
}

sub load {
   my ($self, @paths) = @_; $paths[ 0 ] or return {};

   scalar @paths == 1
      and return ($self->_read_file( $paths[ 0 ], FALSE ))[ 0 ] || {};

   my ($data, $meta, $newest) = $self->_cache->get_by_paths( \@paths );
   my $cache_mtime  = $self->_meta_unpack( $meta );

   not $self->is_stale( $data, $cache_mtime, $newest ) and return $data;

   ($data, $newest) = $self->_load( \@paths );

   $self->_cache->set_by_paths( \@paths, $data, $self->_meta_pack( $newest ) );

   return $data;
}

sub select {
   my ($self, $path, $element) = @_;

   $self->validate_params( $path, $element );

   my $data = ($self->_read_file( $path, FALSE ))[ 0 ] || {};

   return exists $data->{ $element } ? $data->{ $element } : {};
}

sub txn_do {
   my ($self, $path, $code_ref) = @_;

   $self->validate_params( $path, TRUE );

   my $key = q(txn:).$path; my $wantarray = wantarray; my $res;

   $self->_lock->set( k => $key );

   try {
      if ($wantarray) { @{ $res } = $code_ref->() }
      else { $res = $code_ref->() }
   }
   catch {
      $self->_lock->reset( k => $key );
      $self->throw( error => $_, level => 7 );
   };

   $self->_lock->reset( k => $key );

   return $wantarray ? @{ $res } : $res;
}

sub update {
   my ($self, $path, $result, $updating, $cond) = @_;

   defined $updating or $updating = TRUE; $cond ||= sub { TRUE };

   my $updated = $self->_create_or_update( $path, $result, $updating, $cond )
      or $self->throw( 'Nothing updated' );

   return $updated;
}

sub validate_params {
   my ($self, $path, $element) = @_;

   $path or $self->throw( error => 'No file path specified', level => 4 );

   blessed $path or $self->throw( error => 'Path [_1] is not blessed',
                                  args  => [ $path ], level => 4 );

   $element or $self->throw( error => 'Path [_1] no element specified',
                             args  => [ $path ], level => 4 );

   return;
}

# Private methods

sub _create_or_update {
   my ($self, $path, $result, $updating, $cond) = @_;

   my $element = $result->_resultset->source->name;

   $self->validate_params( $path, $element ); my $updated;

   my $data = ($self->_read_file( $path, TRUE ))[ 0 ] || {};

   try {
      my $filter = sub { __get_src_attributes( $cond, $_[ 0 ] ) };
      my $name   = $result->name; $data->{ $element } ||= {};

      not $updating and exists $data->{ $element }->{ $name }
         and $self->throw( error => 'File [_1] element [_2] already exists',
                           args  => [ $path, $name ], level => 4 );

      $updated = File::DataClass::HashMerge->merge
         ( \$data->{ $element }->{ $name }, $result, $filter );
   }
   catch { $self->_lock->reset( k => $path ); $self->throw( $_ ) };

   if ($updated) { $self->_write_file( $path, $data, not $updating ) }
   else { $self->_lock->reset( k => $path ) }

   return $updated;
}

sub _load {
   my ($self, $paths) = @_; my $data = {}; my $newest = 0;

   for my $path (@{ $paths }) {
      my ($red, $path_mtime) = $self->_read_file( $path, FALSE ); $red or next;

      $path_mtime > $newest and $newest = $path_mtime;
      $self->_merge_hash_data( $data, $red );
   }

   return ($data, $newest);
}

sub _merge_hash_data {
   my ($self, $existing, $new) = @_;

   for (keys %{ $new }) {
      $existing->{ $_ } = exists $existing->{ $_ }
                        ? merge( $existing->{ $_ }, $new->{ $_ } )
                        : $new->{ $_ };
   }

   return;
}

sub _meta_pack {
   # Can be modified in a subclass
   my ($self, $mtime) = @_; return { mtime => $mtime };
}

sub _meta_unpack {
   # Can be modified in a subclass
   my ($self, $attrs) = @_; return $attrs ? $attrs->{mtime} : undef;
}

sub _read_file {
   my ($self, $path, $for_update) = @_;

   $self->_lock->set( k => $path ); my ($data, $meta, $path_mtime);

   try {
      ($data, $meta)  = $self->_cache->get( $path );
      $path_mtime     = $path->stat->{mtime};

      my $cache_mtime = $self->_meta_unpack( $meta );

      if ($self->is_stale( $data, $cache_mtime, $path_mtime )) {
         if ($for_update and not $path->is_file) { $data = undef }
         else {
            $data = inner( $path->lock ); $path->close;
            $meta = $self->_meta_pack( $path_mtime );
            $self->_cache->set( $path, $data, $meta );
            $self->_debug and $self->_log->debug( "Read file  ${path}" );
         }
      }
      else { $self->_debug and $self->_log->debug( "Read cache ${path}" ) }
   }
   catch { $self->_lock->reset( k => $path ); $self->throw( $_ ) };

   $for_update or $self->_lock->reset( k => $path );

   return ($data, $path_mtime);
}

sub _write_file {
   my ($self, $path, $data, $create) = @_;

   try {
      $create or $path->is_file
         or $self->throw( error => 'File [_1] not found', args => [ $path ] );

      $path->is_file or $path->perms( $self->_perms );

      if ($self->backup and $path->is_file and not $path->empty) {
         copy( $path.NUL, $path.$self->backup ) or $self->throw( $ERRNO );
      }

      try   { $data = inner( $path->atomic->lock, $data ); $path->close }
      catch { $path->delete; $self->throw( $_ ) };

      $self->_cache->remove( $path );
      $self->_debug and $self->_log->debug( "Write file ${path}" )
   }
   catch { $self->_lock->reset( k => $path ); $self->throw( $_ ) };

   $self->_lock->reset( k => $path );
   return $data;
}

# Private subroutines

sub __get_src_attributes {
   my ($cond, $src) = @_;

   return grep { not m{ \A _ }mx
                 and $_ ne q(name)
                 and $cond->( $_ ) } keys %{ $src };
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage - Storage base class

=head1 Version

0.10.$Revision$

=head1 Synopsis

=head1 Description

Storage base class

=head1 Subroutines/Methods

=head2 delete

   $bool = $storage->delete( $path, $result );

Deletes the specified element object returning true if successful. Throws
an error otherwise. Path is an instance of L<File::DataClass::IO>

=head2 dump

   $data = $storage->dump( $path, $data );

Dumps the data to the specified path. Path is an instance of
L<File::DataClass::IO>

=head2 extensions

   $hash_ref = $storage->extensions;

Returns a hash ref whose keys are the supported extensions and whose values
are an array ref of storage subclasses that implement reading/writing files
with that extension

=head2 insert

   $bool = $storage->insert( $path, $result );

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

   $bool = $storage->update( $path, $result, $updating, $condition );

Updates the specified element object returning true if successful. Throws
an error otherwise. Path is an instance of L<File::DataClass::IO>

=head2 validate_params

=head2 _merge_hash_data

   $self->_merge_hash_data( $existsing, $new );

Uses L<Hash::Merge> to merge data from the new hash ref in with the existsing

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::HashMerge>

=item L<File::DataClass::Util>

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
