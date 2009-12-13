# @(#)$Id$

package File::DataClass::Storage::JSON;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use JSON::PP qw();
use Moose;

extends qw(File::DataClass::Storage);

has '+extn' => default => q(.json);

augment '_read_file' => sub {
   my ($self, $rdr) = @_;

   return $rdr->empty ? {} : JSON::PP->new->decode( $rdr->all );
};

augment '_write_file' => sub {
   my ($self, $wtr, $data) = @_;

   $wtr->print( JSON::PP->new->pretty->encode( $data ) );
   return $data;
};

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::JSON - Read/write JSON data storage model

=head1 Version

0.1.$Revision$

=head1 Synopsis

=head1 Description

Uses L<JSON::PP> to read and write JSON files

=head1 Subroutines/Methods

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Storage>

=item L<JSON::PP>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

Using the module L<JSON::XS> causes the roundtrip test to fail

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
