# @(#)$Id$

package File::DataClass::Element;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;

extends qw(Moose::Object Class::Accessor::Grouped);
with    qw(File::DataClass::Util);

has 'name'    => is => 'rw', isa => 'Str',           required => 1;
has '_path'   => is => 'ro', isa => 'DataClassPath', required => 1;
has '_schema' => is => 'ro', isa => 'Object',        required => 1,
   weak_ref   => 1;

sub BUILD {
   my ($self, $args) = @_; my $class = blessed $self;

   $class->mk_group_accessors( q(simple), @{ $self->_schema->attributes } );

   $self->_schema->update_attributes( $self, $args );
   return;
}

sub delete {
   my $self = shift; return $self->_storage->delete( $self->_path, $self );
}

sub insert {
   my $self = shift; return $self->_storage->insert( $self->_path, $self );
}

sub update {
   my $self = shift; return $self->_storage->update( $self->_path, $self );
}

# Private methods

sub _storage {
   return shift->_schema->storage;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Element - Element object definition

=head1 Version

0.1.$Revision$

=head1 Synopsis

=head1 Description

This is analogous to the row object in L<DBIx::Class>

=head1 Subroutines/Methods

=head2 BUILD

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
