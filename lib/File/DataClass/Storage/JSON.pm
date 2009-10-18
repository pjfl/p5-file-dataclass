# @(#)$Id$

package File::DataClass::Storage::JSON;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use JSON qw();
use Moose;

extends qw(File::DataClass::Storage);

has '+extn' => default => q(.json);

# Private methods

sub _read_file {
   my ($self, $path, $for_update) = @_;

   my $method = sub { my $rdr = shift; return JSON->new->decode( $rdr->all ) };

   return $self->_read_file_with_locking( $method, $path, $for_update );
}

sub _write_file {
   my ($self, $path, $data, $create) = @_;

   my $method = sub {
      my $wtr = shift;
      $wtr->append( JSON->new->pretty->encode( $data ) );
      return $data;
   };

   return $self->_write_file_with_locking( $method, $path, $create );
}

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

Uses L<JSON> to read and write JSON files

=head1 Subroutines/Methods

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Storage>

=item L<JSON>

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
