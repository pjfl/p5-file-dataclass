# @(#)$Ident: Result.pm 2013-04-30 01:32 pjf ;

package File::DataClass::Result;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.20.%d', q$Rev: 0 $ =~ /\d+/gmx );

use Moose;

has 'name'       => is => 'rw', isa => 'Str',    required => 1;
has '_resultset' => is => 'ro', isa => 'Object', required => 1,
   handles       => { _path    => q(path), _source => q(source),
                      _storage => q(storage) };

sub BUILD {
   my ($self, $args) = @_; my $class = blessed $self;

   my %types = ( qw(SCALAR Maybe[Str] ARRAY  Maybe[ArrayRef]
                    HASH   Maybe[HashRef]) );

   for (@{ $self->_source->attributes }) {
      my $type = ref $self->_source->defaults->{ $_ } || ref $args->{ $_ };

      $class->meta->has_attribute( $_ )
         or $class->meta->add_attribute
            ( $_ => ( is => 'rw', isa => $types{ $type || q(SCALAR) } ) );

      defined $args->{ $_ } and $self->$_( $args->{ $_ } );
   }

   return;
}

sub delete {
   return $_[ 0 ]->_storage->delete( $_[ 0 ]->_path, $_[ 0 ] );
}

sub insert {
   return $_[ 0 ]->_storage->insert( $_[ 0 ]->_path, $_[ 0 ] );
}

sub update {
   return $_[ 0 ]->_storage->update( $_[ 0 ]->_path, $_[ 0 ] );
}

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Result - Result object definition

=head1 Version

This document describes version v0.20.$Rev: 0 $

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

=item L<Moose>

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

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
