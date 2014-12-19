package File::DataClass::Storage::JSON;

use namespace::autoclean;

use Moo;
use File::DataClass::Functions qw( extension_map throw );
use JSON::MaybeXS              qw( JSON );
use Try::Tiny;

extends q(File::DataClass::Storage);

has '+extn' => default => '.json';

extension_map 'JSON' => '.json';

sub read_from_file {
   my ($self, $rdr) = @_;

   $self->encoding and $rdr->encoding( $self->encoding );

   # The filter causes the data to be untainted (running suid). I shit you not
   my $json = JSON->new->canonical->filter_json_object( sub { $_[ 0 ] } );

   $rdr->empty and return {}; my $data;

   try   { $data = $json->utf8( 0 )->decode( $rdr->all ) }
   catch { s{ at \s [^ ]+ \s line \s\d+\. }{}mx; throw "${_} in file ${rdr}" };

   return $data;
}

sub write_to_file {
   my ($self, $wtr, $data) = @_; my $json = JSON->new->canonical;

   $self->encoding and $wtr->encoding( $self->encoding );

   $wtr->print( $json->pretty->utf8( 0 )->encode( $data ) ); return $data;
}

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::JSON - Read/write JSON data storage model

=head1 Synopsis

   use Moo;

   extends 'File::DataClass::Schema';

   has '+storage_class' => default => 'JSON';

=head1 Description

Uses L<JSON::MaybeXS> to read and write JSON files

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<extn>

The extension appended to filenames. Defaults to F<.json>

=back

=head1 Subroutines/Methods

=head2 read_from_file

API required method. Calls L<JSON::MaybeXS/decode> to parse the input

=head2 write_to_file

API required method. Calls L<JSON::MaybeXS/encode> to generate the output

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Storage>

=item L<JSON::MaybeXS>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

Using the module L<JSON::XS> causes the round trip test to fail

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
