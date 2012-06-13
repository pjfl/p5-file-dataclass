# @(#)$Id$

package File::DataClass::Util;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.10.%d', q$Rev$ =~ /\d+/gmx );

use Moose::Role;
use File::DataClass::Constants;

no Moose::Role;

1;

__END__

=pod

=head1 Name

File::DataClass::Util - Moose Role defining utility methods

=head1 Version

0.10.$Revision$

=head1 Synopsis

   use Moose;

   with qw(File::DataClass::Util);

=head1 Description

=head1 Subroutines/Methods

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::MOP>

=item L<File::DataClass::IO>

=item L<Hash::Merge>

=item L<List::Util>

=item L<Moose::Role>

=item L<Try::Tiny>

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

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
