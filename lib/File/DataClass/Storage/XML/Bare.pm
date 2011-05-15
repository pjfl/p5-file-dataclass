# @(#)$Id$

package File::DataClass::Storage::XML::Bare;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use XML::Bare;
use Moose;

extends qw(File::DataClass::Storage::XML);

my $PADDING = q(  );

augment '_read_file' => sub {
   my ($self, $rdr) = @_; my $data;

   $data = $self->_dtd_parse( $rdr->all );
   $data = XML::Bare->new( text => $data )->parse() || {};
   $data = $data->{ $self->root_name } || {};
   $self->_read_filter( $self->_arrays || {}, $data );
   return $data;
};

augment '_write_file' => sub {
   my ($self, $wtr, $data) = @_;

   $self->_dtd->[0] and $wtr->println( @{ $self->_dtd } );
   $wtr->append( $self->_write_filter( 0, $self->root_name, $data ) );
   return $data;
};

# Private methods

sub _read_filter {
   # Turn the structure returned by XML::Bare into one returned by XML::Simple
   my ($self, $arrays, $data) = @_; my ($hash, $value);

   if (ref $data eq ARRAY) {
      for my $key (0 .. $#{ $data }) {
         if (    ref $data->[ $key ] eq HASH
             and defined ($value = $data->[ $key ]->{value})
             and $value !~ m{ \A [\n\s]+ \z }mx) {
            # Coerce arrays from single scalars. Array list given by the DTD
            $data->[ $key ] = $arrays->{ $key } ? [ $value ] : $value;

            next;
         }

         $self->_read_filter( $arrays, $data->[ $key ] ); # Recurse
      }
   }
   elsif (ref $data eq HASH) {
      for my $key (keys %{ $data }) {
         if (    ref $data->{ $key } eq HASH
             and defined ($value = $data->{ $key }->{value})
             and $value !~ m{ \A [\n\s]+ \z }mx) {
            # Coerce arrays from single scalars. Array list given by the DTD
            $data->{ $key } = $arrays->{ $key } ? [ $value ] : $value;

            next;
         }

         $self->_read_filter( $arrays, $data->{ $key } ); # Recurse

         # Turn arrays of hashes with a name attribute into hash keyed by name
         if (    ref $data->{ $key } eq ARRAY
             and $value = $data->{ $key }->[0]
             and ref $value eq HASH
             and exists $value->{name}) {
            $hash = {};

            for my $ref (@{ $data->{ $key } }) {
               my $name = delete $ref->{name}; $hash->{ $name } = $ref;
            }

            $data->{ $key } = $hash;
         }
      }

      exists $data->{_i   } and delete $data->{_i};
      exists $data->{_pos } and delete $data->{_pos};
      exists $data->{_z   } and delete $data->{_z};
      exists $data->{value} and $data->{value} =~ m{ \A [\n\s]+ \z }mx
         and delete $data->{value};
   }

   return;
}

sub _write_filter {
   my ($self, $level, $element, $data) = @_; my $xml = NUL;

   my $padding = $PADDING x $level;

   if (ref $data eq ARRAY) {
      for (sort @{ $data }) {
         $xml .= $padding.q(<).$element.q(>).$_.q(</).$element.q(>)."\n";
      }
   }
   elsif (ref $data eq HASH) {
      $padding = $PADDING x ($level + 1);

      for my $key (sort keys %{ $data }) {
         my $value = $data->{ $key };

         if (ref $value eq HASH) {
            for (sort keys %{ $value }) {
               $xml .= $padding.q(<).$key.q(>)."\n";
               $xml .= $padding.$PADDING.q(<name>).$_.q(</name>)."\n";
               $xml .= $self->_write_filter( $level + 1, NUL, $value->{ $_ } );
               $xml .= $padding.q(</).$key.q(>)."\n";
            }
         }
         else { $xml .= $self->_write_filter( $level + 1, $key, $value ) }
      }
   }
   elsif ($element) {
      $xml .= $padding.q(<).$element.q(>).$data.q(</).$element.q(>)."\n";
   }

   if ($level == 0 && $element) {
      $xml = q(<).$element.q(>)."\n".$xml.q(</).$element.q(>)."\n";
   }

   return $xml;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::XML::Bare - Read/write XML data storage model

=head1 Version

0.4.$Revision$

=head1 Synopsis

   use Moose;

   extends qw(File::DataClass::Schema);

   has '+storage_class' => default => q(XML::Bare);

=head1 Description

Uses L<XML::Bare> to read and write XML files

=head1 Subroutines/Methods

=head2 _read_file

Defines the closure that reads the file, parses the DTD, parses the
file using L<XML::Bare> and filters the resulting hash so that it is
compatible with L<XML::Simple>. Calls
L<read file with locking|File::DataClass::Storage::XML/_read_file_with_locking>
in the base class

=head2 _read_filter

Processes the hash read by L</_read_file> altering it's structure so that
is is compatible with L<XML::Simple>

=head2 _write_file

Defines the closure that writes the DTD and data to file. Filters the data
so that it is readable by L<XML::Bare>

=head2 _write_filter

Reverses the changes made by L</_read_filter>

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Storage::XML>

=item L<XML::Bare>

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
