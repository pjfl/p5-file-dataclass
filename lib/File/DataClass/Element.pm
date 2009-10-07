# @(#)$Id: Element.pm 664 2009-08-03 15:35:23Z pjf $

package File::DataClass::Element;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev: 664 $ =~ /\d+/gmx );

use Moose;
use Scalar::Util qw(blessed);

extends qw(File::DataClass::Base);

has 'name'      => ( is => q(rw), isa => q(Str) );
has 'resultset' => ( is => q(ro), isa => q(Object) );
has '_storage'  => ( is => q(ro), isa => q(Object), lazy_build => 1 );

sub BUILD {
   my ($self, %p) = @_; my $class = blessed $self;

   $class->mk_accessors( @{ $self->resultset->schema->attributes } );
   return;
}

sub _build__storage {
   my $self = shift; return $self->resultset->schema->storage;
}

sub delete {
   my $self = shift; $self->_assert_has_name;

   return $self->_storage->delete( $self );
}

sub insert {
   my $self = shift; $self->_assert_has_name;

   return $self->_storage->insert( $self );
}

sub update {
   my $self = shift; $self->_assert_has_name;

   return $self->_storage->update( $self );
}

sub _assert_has_name {
   my $self = shift;

   unless ($self->name) {
      $self->throw( error => 'No element name specified [_1]',
                    args  => [ $self->storage->path->pathname ] );
   }

   return 1;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Element - Element object definition

=head1 Version

0.4.$Revision: 664 $

=head1 Synopsis

   use File::DataClass::Element;

   __PACKAGE__->config( element_class => q(File::DataClass::Element) );

   __PACKAGE__->mk_accessors( qw(element_class) );

   sub find {
      my ($self, $name) = @_; my $elements = $self->storage->select;

      return unless ($name && exists $elements->{ $name });

      my $attrs = $elements->{ $name }; $attrs->{name} = $name;

      return $self->element_class->new( $self, $attrs );
   }

=head1 Description

This is analogous to the row object in L<DBIx::Class>

=head1 Subroutines/Methods

=head2 new

Creates accessors and mutators for the attributes defined by the
schema class

=head2 delete

Calls the delete method in the storage class

=head2 insert

Calls the insert method in the storage class

=head2 update

Calls the update method in the storage class

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

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
