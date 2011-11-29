# @(#)$Id$

package File::DataClass::Storage::WithLanguage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use File::Gettext;
use Hash::Merge qw(merge);
use Moose;

extends qw(File::DataClass);

has 'gettext' => is => 'ro', isa => 'Object',  lazy_build => TRUE;
has 'schema'  => is => 'ro', isa => 'Object',  required   => TRUE,
   handles    => [ qw(cache lang localedir) ], weak_ref   => TRUE;
has 'storage' => is => 'ro', isa => 'Object',  required   => TRUE,
   handles    => [ qw(exception_class extn _is_stale _meta_pack
                      _read_file txn_do validate_params) ];

with qw(File::DataClass::Util);

sub delete {
   my ($self, $path, $result) = @_;

   my $source    = $result->_resultset->source;
   my $condition = sub { $source->lang_dep->{ $_[ 0 ] } };
   my $deleted   = $self->storage->delete( $path, $result );
   my $rs        = $self->_gettext( $path )->resultset;
   my $element   = $source->name;

   for my $attr_name (__get_attributes( $condition, $source )) {
      my $attrs  = { msgctxt => "${element}.${attr_name}",
                     msgid   => $result->name, };
      my $name   = $rs->storage->make_key( $attrs );

      $name      = $rs->delete( { name => $name, optional => TRUE } );
      $deleted ||= $name ? TRUE : FALSE;
   }

   return $deleted;
}

sub dump {
   # Moose delegation bug. Finds Moose::Object::dump instead
   my ($self, $path, $data) = @_; $self->validate_params( $path, TRUE );

   my $gettext      = $self->_gettext( $path );
   my $gettext_data = $gettext->path->is_file ? $gettext->load : {};

   for my $source (values %{ $self->schema->source_registrations }) {
      my $element = $source->name; my $element_ref = $data->{ $element };

      for my $msgid (keys %{ $element_ref }) {
         for my $attr_name (keys %{ $source->lang_dep || {} }) {
            my $msgstr = delete $element_ref->{ $msgid }->{ $attr_name }
                      or next;
            my $attrs  = { msgctxt => "${element}.${attr_name}",
                           msgid   => $msgid,
                           msgstr  => [ $msgstr ] };
            my $key    = $gettext->storage->make_key( $attrs );

            $gettext_data->{ $gettext->source_name }->{ $key } = $attrs;
         }
      }
   }

   $gettext->dump( { data => $gettext_data } );

   return $self->storage->dump( $path, $data );
}

sub insert {
   my ($self, $path, $result) = @_;

   return $self->_create_or_update( $path, $result, FALSE );
}

sub load {
   my ($self, @paths) = @_; $paths[ 0 ] or return {};

   my ($key, $newest) = $self->_get_key_and_newest( \@paths );

   my ($data, $meta)  = $self->cache->get( $key );

   not $self->_is_stale( $data, $meta, $newest ) and return $data;

   ($data, $newest)   = $self->_load( \@paths );

   $self->cache->set( $key, $data, $self->_meta_pack( $newest ) );

   return $data;
}

sub select {
   my ($self, $path, $element) = @_; $self->validate_params( $path, $element );

   my $data = $self->load( $path );

   return exists $data->{ $element } ? $data->{ $element } : {};
}

sub update {
   my ($self, $path, $result) = @_;

   return $self->_create_or_update( $path, $result, TRUE );
}

# Private methods

sub _build_gettext {
   my $self = shift;

   return File::Gettext->new( ioc_obj   => $self->schema,
                              localedir => $self->localedir );
}

sub _create_or_update {
   my ($self, $path, $result, $updating) = @_;

   my $source    = $result->_resultset->source;
   my $condition = sub { not $source->lang_dep->{ $_[ 0 ] } };
   my $updated   = $self->storage->_create_or_update( $path, $result,
                                                      $updating, $condition );
   my $rs        = $self->_gettext( $path )->resultset;
   my $element   = $source->name;

   $condition = sub { $source->lang_dep->{ $_[ 0 ] } };

   for my $attr_name (__get_attributes( $condition, $source )) {
      my $msgstr = $result->$attr_name() or next;
      my $attrs  = { msgctxt => "${element}.${attr_name}",
                     msgid   => $result->name,
                     msgstr  => [ $msgstr ], };

      $attrs->{name} = $rs->storage->make_key( $attrs );

      my $name   = $updating ? $rs->create_or_update( $attrs )
                             : $rs->create( $attrs );

      $updated ||= $name ? TRUE : FALSE;
   }

   $updating and not $updated and $self->throw( 'Nothing updated' );

   $updated and $path->touch; return $updated;
}

sub _get_key_and_newest {
   my ($self, $paths) = @_; my $key; my $newest = 0; my $valid = TRUE;

   for my $path (grep { length } map { NUL.$_ } @{ $paths }) {
      $key .= $key ? q(~).$path : $path;

      my $mtime = $self->cache->get_mtime( $path );

      if ($mtime) { $mtime > $newest and $newest = $mtime }
      else { $valid = FALSE }

      my $lang_path = $self->_gettext( $path )->path;

      if (defined ($mtime = $self->cache->get_mtime( NUL.$lang_path ))) {
         if ($mtime) {
            $key .= $key ? q(~).$lang_path : $lang_path;
            $mtime > $newest and $newest = $mtime;
         }
      }
      else {
         if ($lang_path->is_file) {
            $key .= $key ? q(~).$lang_path : $lang_path; $valid = FALSE;
         }
         else { $self->cache->set_mtime( NUL.$lang_path, 0 ) }
      }
   }

   return ($key, $valid ? $newest : undef);
}

sub _gettext {
   my ($self, $path) = @_; my $gettext = $self->gettext;

   $path or $self->throw( 'Path not specified' );

   $gettext->set_path( $self->lang, $self->basename( $path, $self->extn ) );

   return $gettext;
}

sub _load {
   my ($self, $paths) = @_; my $data = {}; my $newest = 0;

   for my $path (@{ $paths }) {
      my ($red, $path_mtime) = $self->_read_file( $path, FALSE );

      if ($red) {
         for (keys %{ $red }) {
            $data->{ $_ } = exists $data->{ $_ }
                          ? merge( $data->{ $_ }, $red->{ $_ } ) : $red->{ $_ };
         }

         $path_mtime > $newest and $newest = $path_mtime;
      }

      $path_mtime = __load_gettext( $data, $self->_gettext( $path ) );
      $path_mtime and $path_mtime > $newest and $newest = $path_mtime;
   }

   return ($data, $newest);
}

# Private subroutines

sub __get_attributes {
   my ($condition, $source) = @_;

   return grep { not m{ \A _ }msx
                 and $_ ne q(name)
                 and $condition->( $_ ) } @{ $source->attributes || [] };
}

sub __load_gettext {
   my ($data, $gettext) = @_; $gettext->path->is_file or return;

   my $gettext_data = $gettext->load->{ $gettext->source_name };

   for my $key (keys %{ $gettext_data }) {
      my ($msgctxt, $msgid)     = $gettext->storage->decompose_key( $key );
      my ($element, $attr_name) = split m{ [\.] }msx, $msgctxt, 2;

      ($element and $attr_name and $msgid) or next;

      $data->{ $element }->{ $msgid }->{ $attr_name }
         = $gettext_data->{ $key }->{msgstr}->[ 0 ];
   }

   return $gettext->path->stat->{mtime};
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::WithLanguage - Split/merge language dependent data

=head1 Version

0.6.$Revision$

=head1 Synopsis

=head1 Description

This is a proxy for the storage class. In general, for each call made to a
storage method this class makes two instead. The "second" call handles
attributes stored in the language dependent file

=head1 Configuration and Environment

Defines the attributes

=over 3

=item B<lang>

Two character language code

=item B<storage>

Instance of L<File::DataClass::Storage>

=back

=head1 Subroutines/Methods

=head2 delete

   $bool = $self->delete( $path, $result );

Deletes the specified element object returning true if successful. Throws
an error otherwise

=head2 dump

   $data = $self->dump( $path, $data );

Exposes L<File::DataClass::Storage/dump> in the storage class

=head2 insert

   $bool = $self->insert( $path, $result );

Inserts the specified element object returning true if successful. Throws
an error otherwise

=head2 load

   $data = $self->load( $path );

Exposes L<File::DataClass::Storage/load> in the storage class

=head2 select

   $hash_ref = $self->select( $element );

Returns a hash ref containing all the elements of the type specified in the
result source

=head2 update

   $bool = $self->update( $path, $result );

Updates the specified element object returning true if successful. Throws
an error otherwise

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Util>

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

Copyright (c) 2011 Peter Flanigan. All rights reserved

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
