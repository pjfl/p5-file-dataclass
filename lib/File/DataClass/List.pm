# @(#)$Ident: List.pm 2013-06-09 15:52 pjf ;

package File::DataClass::List;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.24.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Moo;
use Unexpected::Types       qw( ArrayRef Bool HashRef Undef );
use File::DataClass::Types  qw( Result );

has 'found'  => is => 'ro', isa => Bool,     default => 0;
has 'labels' => is => 'ro', isa => HashRef,  default => sub { return {} };
has 'list'   => is => 'ro', isa => ArrayRef, default => sub { return [] };
has 'result' => is => 'ro', isa => Result | Undef;

1;

__END__

=pod

=head1 Name

File::DataClass::List - List response class

=head1 Version

This document describes version v0.24.$Rev: 1 $

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

Maybe an C<Result> if the requested element was found

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Types>

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
