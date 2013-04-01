# @(#)$Id$

package File::MealMaster;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use File::MealMaster::Result;
use Moose;

extends qw(File::DataClass::Schema);

has '+cache_attributes' => default => sub {
   (my $ns = lc __PACKAGE__) =~ s{ :: }{-}gmx; return { namespace => $ns, }
};

has '+cache_class' => default => q(none);

has '+result_source_attributes' => default => sub {
   { recipes          => {
      attributes      => [ qw(categories directions
                              ingredients title yield) ],
      defaults        => { categories => [], ingredients => [] },
      resultset_attributes => {
         result_class => q(File::MealMaster::Result), }, }, }
};

has '+storage_class' => default => q(+File::MealMaster::Storage);

has 'source_name' => is => 'ro', isa => 'Str', default => q(recipes);

around 'source' => sub {
   my ($orig, $self) = @_; return $self->$orig( $self->source_name );
};

around 'resultset' => sub {
   my ($orig, $self) = @_; return $self->$orig( $self->source_name );
};

sub make_key {
   my ($self, $title) = @_; return $self->source->storage->make_key( $title );
}


1;

__END__

=pod

=head1 Name

File::MealMaster - OO access to the MealMaster recipe files

=head1 Version

0.15.$Revision$

=head1 Synopsis

=head1 Description

=head1 Configuration and Environment

Sets these attributes:

=over 3

=back

=head1 Subroutines/Methods

=head2 make_key

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Schema>

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
