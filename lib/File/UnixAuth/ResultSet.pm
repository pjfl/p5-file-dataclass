# @(#)$Id$

package File::UnixAuth::ResultSet;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;

extends qw(File::DataClass::ResultSet);

sub add_user_to_group {
   my ($self, $group, $user) = @_;

   return $self->_change_group_members( $group, $user, TRUE, sub {
      return [ @{ $_[1] }, $_[0] ] } );
}

sub remove_user_from_group {
   my ($self, $group, $user) = @_;

   return $self->_change_group_members( $group, $user, FALSE, sub {
      return [ grep { $_ ne $_[0] } @{ $_[1] } ] } );
}

# Private methods

sub _change_group_members {
   my ($self, $group, $user, $exists, $coderef) = @_;

   return $self->_txn_do( sub {
      my $attrs = $self->select->{ $group } || {};
      my $users = $attrs->{members};

      if ($exists xor $self->is_member( $user, @{ $users } )) {
         $attrs->{members} = $coderef->( $user, $users );
         $self->find_and_update( $group, $attrs );
      }
   } );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::UnixAuth::ResultSet - Unix authentication and authorization file custom results

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::UnixAuth::ResultSet;

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

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
