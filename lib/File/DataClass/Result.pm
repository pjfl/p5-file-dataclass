# @(#)$Id$

package File::DataClass::Result;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev$ =~ /\d+/gmx );

use Moose;

extends qw(File::DataClass);

has 'name'       => is => 'rw', isa => 'Str',    required => 1;
has '_resultset' => is => 'ro', isa => 'Object', required => 1;

sub BUILD {
   my ($self, $args) = @_; my $class = blessed $self;

   my %types = ( qw(SCALAR Maybe[Str]
                    ARRAY  Maybe[ArrayRef]
                    HASH   Maybe[HashRef]) );

   for (@{ $self->_resultset->source->attributes }) {
      my $type = ref $args->{ $_ } || q(SCALAR);

      $class->meta->has_attribute( $_ )
         or $class->meta->add_attribute
            ( $_ => ( is => 'rw', isa => $types{ $type } ) );

      defined $args->{ $_ } and $self->$_( $args->{ $_ } );
   }

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

sub _path {
   return shift->_resultset->path;
}

sub _storage {
   return shift->_resultset->storage;
}

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Result - Result object definition

=head1 Version

0.3.$Revision$

=head1 Synopsis

=head1 Description

This is analogous to the result object in L<DBIx::Class>

=head1 Configuration and Environment

Defines these attributes

=over 3

=item B<name>

An additional attribute added to the result to store the underlying hash
key

=item B<_resultset>

An object reference to the L<File::DataClass::ResultSet> instance that
created this result object

=back

=head1 Subroutines/Methods

=head2 BUILD

Creates accessors and mutators for the attributes defined by the
schema class

=head2 delete

   $result->delete;

Calls the delete method in the storage class

=head2 insert

   $result->insert;

Calls the insert method in the storage class

=head2 update

   $result->update;

Calls the update method in the storage class

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
