# @(#)$Id$

package File::DataClass::List;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );

use Moose;

has 'element' => ( is => q(rw), isa => q(Object) );
has 'found'   => ( is => q(rw), isa => q(Bool), default => 0 );
has 'labels'  => ( is => q(rw), isa => q(HashRef) ,
                   default => sub { return {} } );
has 'list'    => ( is => q(rw), isa => q(ArrayRef) ,
                   default => sub { return [] });

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::List - List response class

=head1 Version

0.4.$Revision$

=head1 Synopsis

   use File::DataClass::List;

   $list_object = $self->list_class->new;

=head1 Description

List object returned by L<File::DataClass::ResultSet/list>

=head1 Subroutines/Methods

=head2 new

Defines four attributes; I<element>, I<found>, I<labels>, and I<list>

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
