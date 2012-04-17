# @(#)$Id$

package File::DataClass::Storage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.9.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use Class::Null;
use English qw(-no_match_vars);
use File::Copy;
use File::DataClass::Constants;
use File::DataClass::HashMerge;
use Hash::Merge qw(merge);
use Try::Tiny;

with qw(File::DataClass::Util);

has 'backup' => is => 'ro', isa => 'Str',    default  => NUL;
has 'extn'   => is => 'ro', isa => 'Str',    default  => NUL;
has 'schema' => is => 'ro', isa => 'Object', required => 1, weak_ref => TRUE,
   handles   => { _cache => q(cache), _debug => q(debug), _lock  => q(lock),
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

sub insert {
   my ($self, $path, $result) = @_;

   return $self->_create_or_update( $path, $result, FALSE, sub { TRUE } );
}

sub load {
   my ($self, @paths) = @_; $paths[ 0 ] or return {};

   scalar @paths == 1
      and return ($self->_read_file( $paths[ 0 ], FALSE ))[ 0 ] || {};

   my ($data, $meta, $newest) = $self->_cache->get_by_paths( \@paths );

   not $self->_is_stale( $data, $meta, $newest ) and return $data;

   $data = {}; $newest = 0;

   for my $path (@paths) {
      my ($red, $path_mtime) = $self->_read_file( $path, FALSE );

      $red or next; $path_mtime > $newest and $newest = $path_mtime;

      for (keys %{ $red }) {
         $data->{ $_ } = exists $data->{ $_ }
                       ? merge( $data->{ $_ }, $red->{ $_ } ) : $red->{ $_ };
      }
   }

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
   my ($self, $path, $result, $updating, $condition) = @_;

   defined $updating or $updating = TRUE; $condition ||= sub { TRUE };

   return $self->_create_or_update( $path, $result,
                                    $updating, $condition )
       or $self->throw( 'Nothing updated' );
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
   my ($self, $path, $result, $updating, $condition) = @_;

   my $element = $result->_resultset->source->name;

   $self->validate_params( $path, $element ); my $updated;

   my $data = ($self->_read_file( $path, TRUE ))[ 0 ] || {};

   try {
      my $filter = sub { __get_src_attributes( $condition, $_[ 0 ] ) };
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

sub _is_stale {
   my ($self, $data, $meta, $path_mtime) = @_;

   my $cache_mtime = $self->_meta_unpack( $meta );

   return ! defined $data || ! defined $path_mtime || ! defined $cache_mtime
         || $path_mtime > $cache_mtime
          ? TRUE : FALSE;
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
      ($data, $meta) = $self->_cache->get( $path );
      $path_mtime    = $path->stat->{mtime};

      if ($self->_is_stale( $data, $meta, $path_mtime ) ) {
         if ($for_update and not $path->is_file) { $data = undef }
         else {
            $data = inner( $path->lock ); $path->close;
            $meta = $self->_meta_pack( $path_mtime );
            $self->_cache->set( $path, $data, $meta );
            $self->_debug and $self->_log->debug( "Read file  $path" );
         }
      }
      else { $self->_debug and $self->_log->debug( "Read cache $path" ) }
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
      $self->_debug and $self->_log->debug( "Write file $path" )
   }
   catch { $self->_lock->reset( k => $path ); $self->throw( $_ ) };

   $self->_lock->reset( k => $path );
   return $data;
}

# Private subroutines

sub __get_src_attributes {
   my ($condition, $src) = @_;

   return grep { not m{ \A _ }mx
                 and $_ ne q(name)
                 and $condition->( $_ ) } keys %{ $src };
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage - Storage base class

=head1 Version

0.9.$Revision$

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
