# @(#)$Id$

package File::Gettext::Storage::MO;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use File::Gettext::Constants;
use Moose;

extends qw(File::DataClass::Storage);

augment '_read_file' => sub {
   my ($self, $rdr) = @_;

   return $self->_read_filter( $rdr->pathname, $rdr->all );
};

augment '_write_file' => sub {
   my ($self, $wtr, $data) = @_; return $data;
};

# Private methods

sub _read_filter {
   my ($self, $path, $raw) = @_; my %meta = (); my $unpack = q(N);

   my $size = length $raw; $size < 28
      and $self->throw( error => 'Path [_1] corrupted', args => [ $path ] );

   $meta{magic} = unpack $unpack, substr $raw, 0, 4;

   if    ($meta{magic} == MAGIC_V) { $unpack = q(V) }
   elsif ($meta{magic} != MAGIC_N) {
      $self->throw( error => 'Path [_1] bad magic', args => [ $path ] );
   }

   @meta{ qw(revision num_strings msgids_off msgstrs_off hash_size hash_off) }
      = unpack( ($unpack x 6), substr $raw, 4, 24 );

   $meta{revision} == 0 or $self->throw( error => 'Path [_1 ] invalid version',
                                         args  => [ $path ] );

   my $nstrs = $meta{num_strings};

   $meta{msgids_off}  + 4 * $nstrs > $size and
      $self->throw( error => 'Path [_1] bad msgid offset',  args => [ $path ] );
   $meta{msgstrs_off} + 4 * $nstrs > $size and
      $self->throw( error => 'Path [_1] bad msgstr offset', args => [ $path ] );

   my @orig_tab  = unpack( ($unpack x (2 * $nstrs)),
      substr $raw, $meta{msgids_off},  8 * $nstrs );
   my @trans_tab = unpack( ($unpack x (2 * $nstrs)),
      substr $raw, $meta{msgstrs_off}, 8 * $nstrs );
   my $sep       = PLURAL_SEP;
   my $messages  = {};

   for (my $count = 0; $count < 2 * $nstrs; $count += 2) {
      my $orig_length  = $orig_tab[ $count ];
      my $orig_offset  = $orig_tab[ $count + 1 ];
      my $trans_length = $trans_tab[ $count ];
      my $trans_offset = $trans_tab[ $count + 1 ];

      $orig_offset  + $orig_length  > $size
         and $self->throw( error => 'Path [_1] bad key length',
                           args  => [ $path ] );
      $trans_offset + $trans_length > $size
         and $self->throw( error => 'Path [_1] bad text length',
                           args  => [ $path ] );

      my @origs = split m{ $sep }mx, substr $raw, $orig_offset,  $orig_length;
      my @trans = split m{ $sep }mx, substr $raw, $trans_offset, $trans_length;

      # The singular is the key, the plural plus all translations is the value
      $messages->{ $origs[ 0 ] || NUL } = { msgid_plural => $origs[ 1 ],
                                            msgstr       => [ @trans ] };
   }

   my $po_header = {}; my $null_entry;

   # Try to find po header information.
   if ($null_entry = $messages->{ q() }->{msgstr}->[ 0 ]) {
      for my $line (split m{ [\n] }msx, $null_entry) {
         my ($k, $v) = split m{ [:] }msx, $line, 2;

         $k =~ s{ [-] }{_}gmsx; $v =~ s{ \A \s+ }{}msx;
         $po_header->{ lc $k } = $v;
      }
   }

   if (exists $po_header->{content_type}) {
      my $content_type = $po_header->{content_type};

      $content_type =~ s{ .* = }{}msx and $po_header->{charset} = $content_type;
   }

   my $code = $po_header->{plural_forms} || NUL;
   my $s    = '[ \t\r\n\013\014]'; # Whitespace, locale-independent.

   # Untaint the plural header. Keep line breaks as is Perl 5_005 compatibility
   if ($code =~ m{ \A ($s* nplurals $s* = $s* [0-9]+ $s* ; $s*
                       plural $s* = $s*
                       (?:$s|[-\?\|\&=!<>+*/\%:;a-zA-Z0-9_\(\)])+ ) }msx) {
      $po_header->{plural_forms} = $1;
   }
   else { $po_header->{plural_forms} = NUL }

   return { meta => \%meta, mo => $messages, po_header => $po_header };
}

# Private functions

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::Gettext::Storage::MO - Storage class for GNU gettext machine object format

=head1 Version

0.1.$Revision$

=head1 Synopsis

=head1 Description

=head1 Subroutines/Methods

=head1 Configuration and Environment

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Moose>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2011 Peter Flanigan. All rights reserved

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
