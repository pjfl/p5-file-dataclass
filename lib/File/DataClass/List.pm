# @(#)$Id: List.pm 672 2009-08-06 22:44:02Z pjf $

package CatalystX::Usul::File::List;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev: 672 $ =~ /\d+/gmx );
use parent qw(CatalystX::Usul);

__PACKAGE__->mk_accessors( qw(element found labels list) );

sub new {
   my $class = shift;

   return bless { element => undef, found => 0,
                  labels  => {},    list  => [] }, $class;
}

1;

__END__

=pod

=head1 Name

CatalystX::Usul::File::List - List response class

=head1 Version

0.4.$Revision: 672 $

=head1 Synopsis

   use CatalystX::Usul::File::List;

   $list_object = $self->list_class->new;

=head1 Description

List object returned by the
L<list|CatalystX::Usul::File::ResultSet/list> method

=head1 Subroutines/Methods

=head2 new

Defines four attributes; I<element>, I<found>, I<labels>, and I<list>

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<CatalystX::Usul>

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

Copyright (c) 2008 Peter Flanigan. All rights reserved

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
