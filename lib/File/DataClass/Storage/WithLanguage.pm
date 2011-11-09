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

has 'gettext' => is => 'ro', isa => 'Object', lazy_build => TRUE;
has 'lang'    => is => 'rw', isa => 'Str',    required   => TRUE;
has 'storage' => is => 'ro', isa => 'Object', required   => TRUE,
   handles    => [ qw(exception_class extn load txn_do validate_params) ];

with qw(File::DataClass::Util);

sub delete {
   my ($self, $path, $element_obj) = @_; $self->_set_gettext_path( $path );

   my $deleted   = $self->storage->delete( $path, $element_obj );
   my $source    = $element_obj->_resultset->source;
   my $condition = sub { $source->lang_dep && $source->lang_dep->{ $_[ 0 ] } };
   my $rs        = $self->gettext->resultset;
   my $element   = $source->name;

   for my $attr_name (__get_src_attributes( $condition, $element_obj )) {
      my $attrs  = { msgctxt => "${element}.${attr_name}",
                     msgid   => $element_obj->name, };
      my $name   = $rs->storage->make_key( $attrs );

      $name = $rs->delete( { name => $name, optional => TRUE } );
      $deleted ||= $name ? TRUE : FALSE;
   }

   return $deleted;
}

sub dump {
   # Moose delegation bug
   my ($self, $path, $data) = @_; return $self->storage->dump( $path, $data );
}

sub insert {
   my ($self, $path, $element_obj) = @_;

   return $self->_create_or_update( $path, $element_obj, FALSE );
}

sub select {
   my ($self, $path, $element) = @_; $self->validate_params( $path, $element );

   $self->_set_gettext_path( $path );

   my $gettext      = $self->gettext;
   my $gettext_data = $gettext->load->{ $gettext->source_name };
   my $data         = $self->load( $path );

   for my $key (grep { m{ \A $element [\.] }msx } keys %{ $gettext_data }) {
      my (undef, $attr_name, $msgid) = split m{ [\.] }msx, $key;

      $data->{ $element }->{ $msgid }->{ $attr_name }
         = $gettext_data->{ $key }->{msgstr}->[ 0 ];
   }

   return exists $data->{ $element } ? $data->{ $element } : {};
}

sub update {
   my ($self, $path, $element_obj) = @_;

   return $self->_create_or_update( $path, $element_obj, TRUE );
}

# Private methods

sub _build_gettext {
   my $self = shift; return File::Gettext->new;
}

sub _create_or_update {
   my ($self, $path, $element_obj, $overwrite) = @_;

   $self->_set_gettext_path( $path );

   my $source    = $element_obj->_resultset->source;
   my $condition = sub { !$source->lang_dep || !$source->lang_dep->{ $_[0] } };
   my $updated   = $self->storage->_create_or_update( $path, $element_obj,
                                                      $overwrite, $condition );
   my $rs        = $self->gettext->resultset;
   my $element   = $source->name;
      $condition = sub { $source->lang_dep && $source->lang_dep->{ $_[0] } };

   for my $attr_name (__get_src_attributes( $condition, $element_obj )) {
      my $attrs = { msgctxt => "${element}.${attr_name}",
                    msgid   => $element_obj->name,
                    msgstr  => [ $element_obj->$attr_name() ], };

      $attrs->{name} = $rs->storage->make_key( $attrs );

      my $name  = $overwrite ? $rs->update( $attrs ) : $rs->create( $attrs );

      $updated ||= $name ? TRUE : FALSE;
   }

   $overwrite and not $updated and $self->throw( 'Nothing updated' );

   return $updated;
}

sub _set_gettext_path {
   my ($self, $path) = @_;

   $path       or $self->throw( 'Path not specified' );
   $self->lang or $self->throw( 'Language not specified' );

   my $dir  = $self->dirname ( $path );
   my $file = $self->basename( $path, $self->extn ).q(_).$self->lang.q(.po);

   $self->gettext->path( $self->io( $self->catfile( $dir, $file ) ) );
   return TRUE;
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

   $bool = $self->delete( $path, $element_obj );

Deletes the specified element object returning true if successful. Throws
an error otherwise

=head2 dump

   $data = $self->dump( $path, $data );

Exposes L<File::DataClass::Storage/dump> in the storage class

=head2 insert

   $bool = $self->insert( $path, $element_obj );

Inserts the specified element object returning true if successful. Throws
an error otherwise

=head2 select

   $hash_ref = $self->select( $element );

Returns a hash ref containing all the elements of the type specified in the
result source

=head2 update

   $bool = $self->update( $path, $element_obj );

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
