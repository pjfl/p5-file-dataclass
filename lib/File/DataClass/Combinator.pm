# @(#)$Id$

package File::DataClass::Combinator;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;

extends qw(File::DataClass);

has 'lang'    => is => 'rw', isa => 'Str',    required => TRUE;
has 'storage' => is => 'ro', isa => 'Object', required => TRUE,
   handles    => [ qw(exception_class extn load txn_do validate_params) ];

with qw(File::DataClass::Util);

sub delete {
   my ($self, $path, $element_obj) = @_;

   my $deleted = $self->storage->delete( $path, $element_obj );

   if (my $lang_path = $self->_make_lang_path( $path )) {
      my $updated = $self->storage->delete( $lang_path, $element_obj );

      $deleted ||= $updated;
   }

   return $deleted;
}

sub dump {
   # Moose delegation bug
   my ($self, $path, $data) = @_; return $self->storage->dump( $path, $data );
}

sub insert {
   my ($self, $path, $element_obj) = @_;

   return $self->_update( $path, $element_obj, FALSE );
}

sub select {
   my ($self, $path, $element) = @_; my @paths = ($path);

   push @paths, $self->_make_lang_path( $path ) if ($self->lang);

   my $data = $self->load( @paths );

   $self->validate_params( $path, $element );

   return exists $data->{ $element } ? $data->{ $element } : {};
}

sub update {
   my ($self, $path, $element_obj) = @_;

   return $self->_update( $path, $element_obj, TRUE );
}

# Private methods

sub _make_lang_path {
   my ($self, $path) = @_;

   return unless ($path and $self->lang);

   my $extn = $self->storage->extn;

   return $path.q(_).$self->lang unless ($path =~ m{ $extn \z }mx);

   my $file = $self->basename( $path, $extn ).q(_).$self->lang.$extn;

   return $self->io( $self->catfile( $self->dirname( $path ), $file ) );
}

sub _update {
   my ($self, $path, $element_obj, $overwrite) = @_;

   my $source    = $element_obj->_resultset->source;
   my $condition = sub { !$source->lang_dep || !$source->lang_dep->{ $_[0] } };
   my $updated   = $self->storage->update( $path, $element_obj,
                                           $overwrite, $condition );

   if (my $lpath = $self->_make_lang_path( $path )) {
      $condition  = sub { $source->lang_dep && $source->lang_dep->{ $_[0] } };
      my $written = $self->storage->update( $lpath, $element_obj,
                                            $overwrite, $condition );
      $updated ||= $written;
   }

   $self->throw( 'Nothing updated' ) if ($overwrite and not $updated);

   return $updated;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Combinator - Split/merge language dependent data

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
