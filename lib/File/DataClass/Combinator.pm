# @(#)$Id: Combinator.pm 685 2009-08-17 22:01:00Z pjf $

package File::DataClass::Combinator;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 685 $ =~ /\d+/gmx );

use File::Data::Constants;
use Moose;

extends qw(File::DataClass::Base);

has 'lang'    => ( is => q(rw), isa => q(Str), default => NUL );
has 'storage' => ( is => q(ro), isa => q(Object) );

sub delete {
   my ($self, $element_obj) = @_;

   my ($path, $elem) = $self->storage->_validate_params;
   my $deleted       = $self->storage->_delete( $element_obj, $path, $elem );

   if (my $lang_path = $self->_make_lang_path( $path )) {
      my $updated = $self->storage->_delete( $element_obj, $lang_path, $elem );

      $deleted ||= $updated;
   }

   return $deleted;
}

sub dump {
   my ($self, $path, $data) = @_; return $self->storage->dump( $path, $data );
}

sub insert {
   my ($self, $element_obj) = @_; return $self->_update( $element_obj, FALSE );
}

sub load {
   my ($self, @paths) = @_; return $self->storage->load( @paths );
}

sub path {
   my ($self, $path) = @_;

   $self->storage->path( $path ) if (defined $path);

   return $self->storage->path;
}

sub select {
   my $self          = shift;
   my ($path, $elem) = $self->storage->_validate_params;
   my @paths         = ($path);

   push @paths, $self->_make_lang_path( $path ) if ($self->lang);

   my $data = $self->storage->load( @paths );

   return exists $data->{ $elem } ? $data->{ $elem } : {};
}

sub update {
   my ($self, $element_obj) = @_; return $self->_update( $element_obj, TRUE );
}

# Private methods

sub _make_lang_path {
   my ($self, $path) = @_;

   return unless ($self->lang);

   my $pathname = $path->pathname; my $extn = $self->storage->extn;

   return $pathname.q(_).$self->lang unless ($pathname =~ m{ $extn \z }mx);

   my $file = $self->basename( $pathname, $extn ).q(_).$self->lang.$extn;

   return $self->io( $self->catfile( $self->dirname( $pathname ), $file ) );
}

sub _update {
   my ($self, $element_obj, $overwrite) = @_;

   my ($path, $elem) = $self->storage->_validate_params;
   my $schema    = $self->storage->schema;
   my $condition = sub { !$schema->lang_dep || !$schema->lang_dep->{ $_[0] } };
   my $updated   = $self->storage->_update( $element_obj, $path, $elem,
                                            $overwrite, $condition );

   if (my $lpath = $self->_make_lang_path( $path )) {
      $condition  = sub { $schema->lang_dep && $schema->lang_dep->{ $_[0] } };
      my $written = $self->storage->_update( $element_obj, $lpath, $elem,
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

0.1.$Revision: 685 $

=head1 Synopsis

=head1 Description

=head1 Configuration and Environment

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

=head2 path

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

=head1 Dependencies

None

=over 3

=item L<File::DataClass::Base>

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
