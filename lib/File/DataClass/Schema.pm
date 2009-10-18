# @(#)$Id$

package File::DataClass::Schema;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;

use File::DataClass::Element;

with qw(File::DataClass::Util);

has 'attributes' =>
   is => 'rw', isa => 'ArrayRef', default => sub { return [] };
has 'defaults' =>
   is => 'rw', isa => 'HashRef',  default => sub { return {} };
has 'element' =>
   is => 'rw', isa => 'Str',      default => NUL;
has 'label_attr' =>
   is => 'rw', isa => 'Str',      default => NUL;

has 'source' =>
   is => 'ro', isa => 'Object',   weak_ref => TRUE;

has 'element_class' =>
   is => 'ro', isa => 'ClassName',
   default => q(File::DataClass::Element);

has 'storage_attributes' =>
   is => 'ro', isa => 'HashRef',  default => sub { return {} };
has 'storage_base' =>
   is => 'ro', isa => 'Str',      default => q(File::DataClass::Storage);
has 'storage_class' =>
   is => 'ro', isa => 'Str',      default => q(XML::Simple);
has 'storage' =>
   is => 'rw', isa => 'Object',   lazy_build => TRUE;

sub create_element {
   my ($self, $path, $attrs) = @_;

   $attrs = { %{ $self->defaults }, %{ $attrs } };

   $attrs->{_path  } = $path;
   $attrs->{_schema} = $self;

   return $self->element_class->new( $attrs );
}

sub txn_do {
   my ($self, @rest) = @_; return $self->storage->txn_do( @rest );
}

sub update_attributes {
   my ($self, $element, $attrs) = @_;

   for my $attr (grep { exists $attrs->{ $_ } } @{ $self->attributes }) {
      $element->$attr( $attrs->{ $attr } );
   }

   return;
}

# Private methods

sub _build_storage {
   my $self = shift; my $class = $self->storage_class;

   if (q(+) eq substr $class, 0, 1) { $class = substr $class, 1 }
   else { $class = $self->storage_base.q(::).$class }

   $self->ensure_class_loaded( $class );

   return $class->new( { %{ $self->storage_attributes  }, schema => $self } );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Schema - Base class for schema definitions

=head1 Version

0.1.$Revision$

=head1 Synopsis

=head1 Description

This is the base class for schema definitions. Each element in a data file
requires a schema definition to define it's attributes that should
inherit from this

=head1 Subroutines/Methods

=head2 create_element

=head2 update_attributes

=head1 Configuration and Environment

Creates a new instance of the storage class which defaults to
L<File::DataClass::Storage::XML::Simple>

If the schema is language dependent then an instance of
L<File::DataClass::Combinator> is created as a proxy for the
storage class

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Base>

=item L<File::DataClass::Combinator>

=item L<File::DataClass::Storage>

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
