# @(#)$Id$

package File::Gettext::Storage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
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
   my ($self, $buf) = @_; $buf ||= [];

   my ($data, $order, $rec, $key, $last) = ({}, 0, {});

   for my $line (grep { defined } @{ $buf }) {
      if ('#' eq substr $line, 0, 1) {
         my $field = __comment_field( substr $line, 0, 2 );

         $field and __store_comment( $rec, $line, $field );
      }
      elsif (q(msg) eq substr $line, 0, 3) {
         $key = __store_msgtext( $rec, $line, \$last );
      }
      elsif ($line =~ m{ \A \s* [\"] (.+) [\"] \z }msx and defined $key) {
         if (ref $rec->{ $key } eq ARRAY) {
            $rec->{ $key }->[ $last || 0 ] .= $1;
         }
         else { $rec->{ $key } .= $1 }
      }
      elsif ($line =~ m{ \A \s* \z }msx) {
         __store_record( $data, $rec, \$order );
         $key = undef; $last = undef; $rec = {};
      }
   }

   __store_record( $data, $rec, \$order );

   return { $self->schema->source_name => $data };
}

sub _write_filter {
   my ($self, $data) = @_; $data = $data->{ $self->schema->source_name };

   my $attrs = $self->schema->source->attributes; my $buf ||= [];

   for my $rec (map  { $data->{ $_ } }
                sort { __original_order( $data, $a, $b ) } keys %{ $data }) {
      for my $attr_name (grep { exists $rec->{ $_ } } @{ $attrs }) {
         my $values = $rec->{ $attr_name }; defined $values or next; my $cpref;

         if ($cpref = __comment_prefix( $attr_name )) {
            __push_comment( $buf, $attr_name, $cpref, $values );
         }
         elsif (ref $values eq ARRAY) {
            if (@{ $values } > 1) {
               __array_push_split_on_nl( $buf, $attr_name, $values );
            }
            else { __push_split_on_nl( $buf, $attr_name, $values->[ 0 ] ) }
         }
         else { __push_split_on_nl( $buf, $attr_name, $values ) }
      }

      push @{ $buf }, NUL;
   }

   pop @{ $buf };
   return $buf;
}

# Private functions

sub __array_push_split_on_nl {
   my ($buf, $attr, $values) = @_; my $index = 0;

   for my $lines (@{ $values }) {
      __push_split_on_nl( $buf, "${attr}[${index}]", $lines ); $index++;
   }

   return;
}

sub __comment_field {
   return { '#'  => q(translator-comment),
            '# ' => q(translator-comment),
            '#.' => q(extracted-comment),
            '#:' => q(reference),
            '#,' => q(flags),
            '#|' => q(previous), }->{ $_[ 0 ] };
}

sub __comment_prefix {
   return { 'translator-comment' => '# ',
            'extracted-comment'  => '#.',
            'reference'          => '#:',
            'flags'              => '#,',
            'previous'           => '#|', }->{ $_[ 0 ] };
}

sub __make_key {
   my $rec = shift;

   return (exists $rec->{msgctxt} ? $rec->{msgctxt} : NUL).$rec->{msgid};
}

sub __original_order {
   my ($hash, $lhs, $rhs) = @_;

   # New elements will be  added at the end
   return  1 unless (exists $hash->{ $lhs }->{_order});
   return -1 unless (exists $hash->{ $rhs }->{_order});

   return $hash->{ $lhs }->{_order} <=> $hash->{ $rhs }->{_order};
}

sub __push_comment {
   my ($buf, $attr, $prefix, $values) = @_;

   $attr eq q(flags) and $values = [ SPC.(join q(, ), @{ $values }) ];

   for my $value (@{ $values }) {
      my $line = $prefix.$value; 2 == length $line and $line =~ s{ \s \z }{}msx;

      push @{ $buf }, $line;
   }

   return;
}

sub __push_split_on_nl {
   my ($buf, $prefix, $lines) = @_;

   my @lines = split m{ [\\][n] }msx, $lines;

   if (@lines > 1) {
      push @{ $buf }, "${prefix} \"\"";

      for my $line (@lines) { push @{ $buf }, "\"${line}\\n\"\n" }
   }
   else { push @{ $buf }, "${prefix} \"${lines}\"" }

   return;
}

sub __store_comment {
   my ($rec, $line, $attr) = @_;

   my $value = length $line > 1 ? substr $line, 2 : NUL;

   $rec->{ $attr } ||= [];

   if ($attr eq q(flags)) {
      my @values = map { s{ \s+ }{}msx; $_ } split m{ [,] }msx, $value;

      push @{ $rec->{ $attr } }, @values;
   }
   else { push @{ $rec->{ $attr } }, $value }

   return;
}

sub __store_msgtext {
   my ($rec, $line, $last_ref) = @_; my $key;

   if ($line =~ m{ \A msgctxt \s+ [\"] (.*) [\"] \z }msx) {
      $key = q(msgctxt); $rec->{ $key } = $1;
   }
   elsif ($line =~ m{ \A msgid \s+ [\"] (.*) [\"] \z }msx) {
      $key = q(msgid); $rec->{ $key } = $1;
   }
   elsif ($line =~ m{ \A msgid_plural \s+ [\"] (.*) [\"] \z }msx) {
      $key = q(msgid_plural); $rec->{ $key } = $1;
   }
   elsif ($line =~ m{ \A msgstr \s+ [\"] (.*) [\"] \z }msx) {
      $key = q(msgstr); $rec->{ $key } ||= [];
      $rec->{ $key }->[ ${ $last_ref } = 0 ] .= $1;
   }
   elsif ($line =~ m{ \A msgstr\[\s*(\d+)\s*\] \s+ [\"](.*)[\"] \z }msx) {
      $key = q(msgstr); $rec->{ $key } ||= [];
      $rec->{ $key }->[ ${ $last_ref } = $1 ] .= $2;
   }

   return $key;
}

sub __store_record {
   my ($data, $rec, $order_ref) = @_; exists $rec->{msgid} or return;

   $rec->{_order} = ${ $order_ref }++; $data->{ __make_key( $rec ) } = $rec;

   return;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::Gettext::Storage - Storage class for GNU gettext file format

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
