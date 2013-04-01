# @(#)$Id$

package File::DataClass::ResultSource::WithLanguage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev$ =~ /\d+/gmx );

use Moose;

extends qw(File::DataClass::ResultSource);

has 'lang_dep' => is => 'ro', isa => 'HashRef', default => sub { {} };

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::ResultSource::WithLanguage - Result source localisation

=head1 Version

0.15.$Revision$

=head1 Synopsis

=head1 Description

Extends L<File::DataClass::ResultSource>

=head1 Configuration and Environment

Defines these attributes

=over 3

=item B<lang_dep>

Is a hash ref of language dependent attributes names. The values a just set
to C<TRUE>

=back

=head1 Subroutines/Methods

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::ResultSource>

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
