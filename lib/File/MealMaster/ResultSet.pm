# @(#)$Id$

package File::MealMaster::ResultSet;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;

extends qw(File::DataClass::ResultSet);

sub make_key {
   my ($self, $title) = @_; return $self->storage->make_key( $title );
}

sub render {
   my ($self, $recipe) = @_;

   my $storage       = $self->storage;
   my $template_data = $storage->load_template( $storage->render_template );
   my $buffer        = NUL;

   $storage->template->process( \$template_data, $recipe, \$buffer )
      or $buffer = $storage->template->error;

   return $buffer;
}

# Private methods

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::MealMaster::ResultSet - MealMaster food recipes custom result set

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::MealMaster::ResultSet;

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 add_user_to_group

=head2 remove_user_from_group

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<File::DataClass::ResultSet>

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
