# @(#)$Id$

package File::Gettext::Storage::PO;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Encode qw(decode encode);
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

# Private read methods

sub _read_filter {
   my ($self, $buf) = @_; $buf ||= [];

   my ($data, $order, $rec, $key, $last) = ({}, 0, {});

   for my $line (grep { defined } @{ $buf }) {
      # Lines beginning with a hash are comments
      if ('#' eq substr $line, 0, 1) {
         my $field = __comment_field( substr $line, 0, 2 );

         $field and __store_comment( $rec, $line, $field );
      }
      # Field names all begin with the prefix msg
      elsif (q(msg) eq substr $line, 0, 3) {
         $key = __store_msgtext( $rec, $line, \$last );
      }
      # Match any continuation lines
      elsif ($line =~ m{ \A \s* [\"] (.+) [\"] \z }msx and defined $key) {
         if (ref $rec->{ $key } ne ARRAY) { $rec->{ $key } .= $1 }
         else { $rec->{ $key }->[ $last || 0 ] .= $1 }
      }
      # A blank lines ends the record
      elsif ($line =~ m{ \A \s* \z }msx) {
         __store_record( $data, $rec, \$order );
         $key = undef; $last = undef; $rec = {};
      }
   }

   __store_record( $data, $rec, \$order ); # If the last line isn't blank

   return $self->_inflate_and_decode( $data );
}

sub _inflate_and_decode {
   my ($self, $data) = @_;

   my $po_header = __header_inflate( $data );
   my $charset   = $self->_get_charset( $po_header );
   my $tmp       = $data; $data = {};

   # Decode all keys and values using the charset from the header
   for my $k (grep { $_ and defined $tmp->{ $_ } } keys %{ $tmp }) {
      my $rec = $tmp->{ $k }; my $id = decode( $charset, $k );

      $data->{ $id } = __decode_hash( $charset, $rec );
   }

   return { po => $data, po_header => __decode_hash( $charset, $po_header ), };
}

# Private write methods

sub _write_filter {
   my ($self, $data) = @_; my $buf ||= [];

   my $po        = $data->{po       } || {};
   my $po_header = $data->{po_header} || {};
   my $charset   = $self->_get_charset( $po_header );
   my $attrs     = $self->schema->source->attributes;

   $po->{ NUL() } = __header_deflate( $po_header );

   for my $rec (map  { $po->{ $_ } }
                sort { __original_order( $po, $a, $b ) } keys %{ $po }) {
      for my $attr_name (grep { exists $rec->{ $_ } } @{ $attrs }) {
         my $values = $rec->{ $attr_name }; defined $values or next;

         my ($cpref, $lines);

         if ($cpref = __comment_prefix( $attr_name )) {
            $attr_name eq q(flags)
               and $values = [ SPC.(join q(, ), @{ $values }) ];

            $lines = $self->_push_comment( $cpref, $values );
         }
         elsif (ref $values eq ARRAY) {
            if (@{ $values } > 1) {
               $lines = $self->_array_push_split_on_nl( $attr_name, $values );
            }
            else {
               $lines = $self->_push_split_on_nl( $attr_name, $values->[ 0 ] );
            }
         }
         else { $lines = $self->_push_split_on_nl( $attr_name, $values ) }

         push @{ $buf }, map { encode( $charset, $_ ) } @{ $lines };
      }

      push @{ $buf }, NUL;
   }

   pop @{ $buf };
   return $buf;
}

sub _array_push_split_on_nl {
   my ($self, $attr, $values) = @_; my $index = 0; my $lines = [];

   for my $value (@{ $values }) {
      push @{ $lines },
           @{ $self->_push_split_on_nl( "${attr}[${index}]", $value ) };
      $index++;
   }

   return $lines;
}

sub _push_comment {
   my ($self, $prefix, $values) = @_; my $lines = [];

   for my $value (@{ $values || [] }) {
      my $line = $prefix.$value;

      2 == length $line and $line =~ s{ \s \z }{}msx;
      push @{ $lines }, $line;
   }

   return $lines;
}

sub _push_split_on_nl {
   my ($self, $prefix, $value) = @_; my $lines = [];

   $value =~ s{ [\n] \s+ }{\\\n}gmsx;

   my @lines = split m{ [\\][n] }msx, $value;

   if (@lines < 2) {
      push @{ $lines }, $prefix.' "'.__quote_string( $value ).'"';
   }
   else {
      push @{ $lines }, "${prefix} \"\"";

      for my $line (map { __quote_string( $_ ) } @lines) {
         push @{ $lines }, "\"${line}\\n\"\n";
      }
   }

   return $lines;
}

# Private common methods

sub _get_charset {
   my ($self, $po_header) = @_; my $charset = $self->schema->charset;

   my $msgstr       = $po_header->{msgstr} || {};
   my $content_type = $msgstr->{content_type} || NUL;

   $content_type =~ s{ .* = }{}msx and $charset = $content_type;

   return $charset;
}

# Private functions

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

sub __decode_hash {
   my ($charset, $in) = @_; my $out = {};

   for my $k (grep { defined } keys %{ $in }) {
      my $values = $in->{ $k }; defined $values or next;

      if (ref $values eq HASH) {
         $out->{ $k } = __decode_hash( $charset, $values );
      }
      elsif (ref $values eq ARRAY) {
         $out->{ $k } = [ map { decode( $charset, $_ ) } @{ $values } ];
      }
      else { $out->{ $k } = decode( $charset, $values ) }
   }

   return $out;
}

sub __get_po_header_key {
   my $k    = shift;
   my $hash = {
      project_id_version        => [ 0,  q(Project-Id-Version)        ],
      report_msgid_bugs_to      => [ 1,  q(Report-Msgid-Bugs-To)      ],
      pot_creation_date         => [ 2,  q(POT-Creation-Date)         ],
      po_revision_date          => [ 3,  q(PO-Revision-Date)          ],
      last_translator           => [ 4,  q(Last-Translator)           ],
      language_team             => [ 5,  q(Language-Team)             ],
      language                  => [ 6,  q(Language)                  ],
      mime_version              => [ 7,  q(MIME-Version)              ],
      content_type              => [ 8,  q(Content-Type)              ],
      content_transfer_encoding => [ 9,  q(Content-Transfer-Encoding) ],
      plural_forms              => [ 10, q(Plural-Forms)              ], };

   defined $hash->{ $k } and return $hash->{ $k };

   my $po_key = join q(-), map { ucfirst $_ } split m{ [_] }msx, $k;

   return [ 1 + keys %{ $hash }, $po_key ];
}

sub __header_deflate {
   my $po_header = shift; my $msgstr_ref = $po_header->{msgstr} || {};

   my $header = { %{ $po_header || {} } }; my $msgstr;

   for my $k (sort { __get_po_header_key( $a )->[ 0 ]
                 <=> __get_po_header_key( $b )->[ 0 ] } keys %{ $msgstr_ref }) {
      $msgstr .= __get_po_header_key( $k )->[ 1 ];
      $msgstr .= ': '.($msgstr_ref->{ $k } || NUL).'\\n';
   }

   $header->{_order} = 0;
   $header->{msgid } = NUL;
   $header->{msgstr} = [ $msgstr ];
   return $header;
}

sub __header_inflate {
   my $data = shift; my $header = (delete $data->{ NUL() }) || { msgstr => [] };

   my $null_entry = $header->{msgstr}->[ 0 ]; $header->{msgstr} = {};

   $null_entry or return $header;

   for my $line (split m{ [\\][n] }msx, $null_entry) {
      my ($k, $v) = split m{ [:] }msx, $line, 2;

      $k =~ s{ [-] }{_}gmsx; $v =~ s{ \A \s+ }{}msx;
      $header->{msgstr}->{ lc $k } = $v;
   }

   return $header;
}

sub __make_key {
   my $rec = shift;

   return (exists $rec->{msgctxt} ? $rec->{msgctxt} : NUL).$rec->{msgid};
}

sub __original_order {
   my ($hash, $lhs, $rhs) = @_;

   # New elements will be  added at the end
   exists $hash->{ $lhs }->{_order} or return  1;
   exists $hash->{ $rhs }->{_order} or return -1;
   return $hash->{ $lhs }->{_order} <=> $hash->{ $rhs }->{_order};
}

sub __quote_string {
   my $line = shift;

   $line =~ s{ \A [\"] }{\\\"}msx; $line =~ s{ ([^\\])[\"] }{$1\\\"}gmsx;

   return $line;
}

sub __store_comment {
   my ($rec, $line, $attr) = @_; $rec->{ $attr } ||= [];

   my $value = length $line > 1 ? substr $line, 2 : NUL;

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

File::Gettext::Storage::PO - Storage class for GNU gettext portable object format

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
