# @(#)$Id$

package File::UnixAuth::Storage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Lingua::EN::NameParse;
use Moose;

extends q(File::DataClass::Storage);

augment '_read_file' => sub {
   my ($self, $rdr) = @_;

   $self->encoding and $rdr->encoding( $self->encoding );

   return $self->_read_filter( [ $rdr->chomp->getlines ] );
};

augment '_write_file' => sub {
   my ($self, $wtr, $data) = @_;

   $self->encoding and $wtr->encoding( $self->encoding );

   $wtr->println( @{ $self->_write_filter( $data ) } );
   return $data;
};

# Private methods

sub _deflate {
   my ($self, $hash, $id) = @_; my $attr = $hash->{ $id };

   if (exists $attr->{members}) {
       $attr->{members} = join q(,), @{ $attr->{members} || [] };
   }

   if (exists $attr->{first_name}) {
      my $gecos = $attr->{first_name} || NUL;

      $gecos .= $attr->{last_name} ? SPC.$attr->{last_name} : NUL;

      if ($attr->{location} or $attr->{work_phone} or $attr->{home_phone}) {
         $gecos .= q(,).($attr->{location  } || q(?));
         $gecos .= q(,).($attr->{work_phone} || q(?));
         $gecos .= q(,).($attr->{home_phone} || q(?));
      }

      $attr->{gecos} = $gecos;
   }

   return;
}

sub _inflate {
   my ($self, $hash, $id, $name_parser) = @_; my $attr = $hash->{ $id };

   if (exists $attr->{members}) {
       $attr->{members} = [ split m{ , }mx, $attr->{members} || NUL ];
   }

   if (exists $attr->{gecos}) {
      my %names  = ( surname_1 => NUL, );
      my @fields = qw(full_name location work_phone home_phone);

      @{ $attr }{ @fields } = split m{ , }mx, $attr->{gecos} || NUL;

      # Weird logic is correct from L::EN::NP POD
      if ($attr->{full_name}
          and not $name_parser->parse( $attr->{full_name} )) {
         %names = $name_parser->components;
      }
      else { $names{given_name_1} = $attr->{full_name} || $id }

      $attr->{first_name} = $names{given_name_1};
      $attr->{last_name } = $names{surname_1   };
      delete $attr->{full_name}; delete $attr->{gecos};
   }

   return;
}

sub _read_filter {
   my ($self, $buf) = @_; my $hash = {}; my $order = 0;

   my $source_name = $self->schema->source_name;
   my $fields      = $self->schema->source->attributes;
   my %args        = ( force_case => 1, lc_prefix => 1 );
   my $name_parser = Lingua::EN::NameParse->new( %args );

   for my $line (@{ $buf || [] }) {
      my ($id, @rest) = split m{ : }mx, $line; my %attr = ();

      @attr{ @{ $fields } } = @rest;
      $attr{ _order_by    } = $order++;
      $hash->{ $id } = \%attr;
      $self->_inflate( $hash, $id, $name_parser );
   }

   return { $source_name => $hash };
}

sub _write_filter {
   my ($self, $data) = @_; my $buf = [];

   my $source_name = $self->schema->source_name;
   my $fields      = $self->schema->source->attributes;
   my $hash        = $data->{ $source_name };

   $source_name eq q(passwd) and $fields = [ @{ $fields }[ 0 .. 5 ] ];

   for my $id (sort { __original_order( $hash, $a, $b ) } keys %{ $hash }) {
      $self->_deflate( $hash, $id );

      my $attr = $hash->{ $id }; delete $attr->{_order_by};
      my $line = join q(:), map { $attr->{ $_ } // NUL } @{ $fields };

      push @{ $buf }, "${id}:${line}";
   }

   return $buf;
}

# Private subroutines

sub __original_order {
   my ($hash, $lhs, $rhs) = @_;

   # New elements will be  added at the end
   exists $hash->{ $lhs }->{_order_by} or return  1;
   exists $hash->{ $rhs }->{_order_by} or return -1;
   return $hash->{ $lhs }->{_order_by} <=> $hash->{ $rhs }->{_order_by};
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::UnixAuth::Storage - Unix authentication and authorisation file storage

=head1 Version

0.15.$Revision$

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
