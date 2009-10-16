# @(#)$Id$

package File::DataClass::Schema;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;

with qw(File::DataClass::Util);

has 'attributes' =>
   ( is => q(rw), isa => q(ArrayRef), default => sub { return [] } );
has 'defaults' =>
   ( is => q(rw), isa => q(HashRef),  default => sub { return {} } );
has 'element' =>
   ( is => q(rw), isa => q(Str),      default => NUL );
has 'label_attr' =>
   ( is => q(rw), isa => q(Str),      default => NUL );

has 'source' =>
   ( is => q(ro), isa => q(Object),   weak_ref => TRUE );

has 'storage_attributes' =>
   ( is => q(ro), isa => q(HashRef),  default => sub { return {} } );
has 'storage_base' =>
   ( is => q(ro), isa => q(Str),      default => q(File::DataClass::Storage) );
has 'storage_class' =>
   ( is => q(ro), isa => q(Str),      default => q(XML::Simple) );
has 'storage' =>
   ( is => q(rw), isa => q(Object),   lazy_build => TRUE );

sub _build_storage {
   my $self = shift; my $class = $self->storage_class;

   if (q(+) eq substr $class, 0, 1) { $class = substr $class, 1 }
   else { $class = $self->storage_base.q(::).$class }

   $self->ensure_class_loaded( $class );

   return $class->new( { %{ $self->storage_attributes  }, schema => $self } );
}

sub update_attributes {
   my ($self, $element, $attrs) = @_;

   for my $attr (grep { exists $attrs->{ $_ } } @{ $self->attributes }) {
      $element->$attr( $attrs->{ $attr } );
   }

   return;
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

=head2 new

Creates a new instance of the storage class which defaults to
L<File::DataClass::Storage::XML::Simple>

If the schema is language dependent then an instance of
L<File::DataClass::Combinator> is created as a proxy for the
storage class

=head1 Diagnostics

None

=head1 Configuration and Environment

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
