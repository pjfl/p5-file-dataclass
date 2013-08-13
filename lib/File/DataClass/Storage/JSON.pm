# @(#)$Ident: JSON.pm 2013-06-08 22:27 pjf ;

package File::DataClass::Storage::JSON;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.24.%d', q$Rev: 1 $ =~ /\d+/gmx );

use JSON qw();
use Moo;
use MooX::Augment -class;

extends qw(File::DataClass::Storage);

has '+extn' => default => q(.json);

augment '_read_file' => sub {
   my ($self, $rdr) = @_;

   $self->encoding and $rdr->encoding( $self->encoding );

   # The filter causes the data to be untainted (running suid). I shit you not
   my $json = JSON->new->canonical->filter_json_object( sub { $_[ 0 ] } );

   return $rdr->empty ? {} : $json->utf8( 0 )->decode( $rdr->all );
};

augment '_write_file' => sub {
   my ($self, $wtr, $data) = @_; my $json = JSON->new->canonical;

   $self->encoding and $wtr->encoding( $self->encoding );

   $wtr->print( $json->pretty->utf8( 0 )->encode( $data ) ); return $data;
};

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::JSON - Read/write JSON data storage model

=head1 Version

This document describes version v0.24.$Rev: 1 $

=head1 Synopsis

   use Moo;

   extends qw(File::DataClass::Schema);

   has '+storage_class' => default => q(JSON);

=head1 Description

Uses L<JSON> to read and write JSON files

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<extn>

The extension appended to filenames. Defaults to F<.json>

=back

=head1 Subroutines/Methods

=head2 _read_file

Calls L<JSON/decode> to parse the input

=head2 _write_file

Calls L<JSON/encode> to generate the output

=head1 Diagnostics

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

Using the module L<JSON::XS> causes the round trip test to fail

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
