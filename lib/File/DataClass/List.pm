# @(#)$Id$

package File::DataClass::List;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

use Moose;

with qw(File::DataClass::Constraints);

has 'found'  => is => 'rw', isa => 'Bool',     default => 0;
has 'labels' => is => 'rw', isa => 'HashRef',  default => sub { return {} };
has 'list'   => is => 'rw', isa => 'ArrayRef', default => sub { return [] };
has 'result' => is => 'rw', isa => 'Maybe[F_DC_Result]';

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::List - List response class

=head1 Version

0.6.$Revision$

=head1 Synopsis

   use File::DataClass::List;

   $list_object = $self->list_class->new;

=head1 Description

List object returned by L<File::DataClass::ResultSet/list>

=head1 Configuration and Environment

Defines these attributes

=over 3

=item B<found>

True if the requested element was found

=item B<labels>

A hash ref keyed by element attribute name, where the values are the
descriptive labels for each attribute

=item B<list>

An array ref of element names

=item B<result>

Maybe an C<F_DC_Result> if the requested element was found

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Constraints>

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

Copyright (c) 2010 Peter Flanigan. All rights reserved

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
