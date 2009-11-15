# @(#)$Id$

package File::UnixAuth::Storage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;

extends qw(File::DataClass::Storage);

augment '_read_file' => sub {
   my ($self, $rdr) = @_;

   return $self->_read_filter( [ $rdr->chomp->getlines ] );
};

augment '_write_file' => sub {
   my ($self, $wtr, $data) = @_;

   $wtr->println( @{ $self->_write_filter( $data ) } );
   return $data;
};

# Private methods

sub _read_filter {
   my ($self, $buf) = @_; my $hash = {};

   my $fields = $self->_source->attributes; my $order = 0;

   for my $line (@{ $buf || [] }) {
      my ($id, @rest) = split m{ : }mx, $line; my %attrs = ();

      @attrs{ @{ $fields } } = @rest;
      $attrs{ _order_by } = $order++;
      $hash->{ $id } = \%attrs;
   }

   return $hash;
}

sub _source {
   my $self = shift;

   return $self->schema->source( $self->schema->source_name );
}

sub _write_filter {
   my ($self, $hash) = @_; my $buf = [];

   my $fields = $self->_source->attributes;

   for my $id (sort { __original_order( $hash, $a, $b ) } keys %{ $hash }) {
      my $attrs = $hash->{ $id }; delete $attrs->{_order_by};
      my $line  = join q(:),
                  map  { defined $attrs->{ $_ } ? $attrs->{ $_ } : q() }
                  @{ $fields };

      push @{ $buf }, $id.q(:).$line;
   }

   return $buf;
}

# Private subroutines

sub __original_order {
   my ($hash, $lhs, $rhs) = @_;

   # New elements will be  added at the end
   return  1 unless (exists $hash->{ $lhs }->{_order_by});
   return -1 unless (exists $hash->{ $rhs }->{_order_by});

   return $hash->{ $lhs }->{_order_by} <=> $hash->{ $rhs }->{_order_by};
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::UnixAuth::Storage - Unix authentication and authorization file storage

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::UnixAuth::Storage;

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<File::DataClass::Storage>

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
