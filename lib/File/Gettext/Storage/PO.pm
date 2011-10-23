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
   my ($self, $buf) = @_; my $charset = $self->schema->charset;

   my ($data, $order, $rec, $key, $last) = ({}, 0, {}); $buf ||= [];

   for my $line (grep { defined } @{ $buf }) {
      if ('#' eq substr $line, 0, 1) {
         my $field = __comment_field( substr $line, 0, 2 );

         $field and $self->_store_comment( $rec, $line, $field );
      }
      elsif (q(msg) eq substr $line, 0, 3) {
         $key = $self->_store_msgtext( $rec, $line, \$last );
      }
      elsif ($line =~ m{ \A \s* [\"] (.+) [\"] \z }msx and defined $key) {
         if (ref $rec->{ $key } eq ARRAY) {
            $rec->{ $key }->[ $last || 0 ] .= decode( $charset, $1 );
         }
         else { $rec->{ $key } .= decode( $charset, $1 ) }
      }
      elsif ($line =~ m{ \A \s* \z }msx) {
         __store_record( $data, $rec, \$order );
         $key = undef; $last = undef; $rec = {};
      }
   }

   __store_record( $data, $rec, \$order );

   return { po => $data, po_header => __extract_header( $data ) };
}

sub _store_comment {
   my ($self, $rec, $line, $attr) = @_; my $charset = $self->schema->charset;

   my $value = length $line > 1 ? substr $line, 2 : NUL;

   $rec->{ $attr } ||= [];

   if ($attr eq q(flags)) {
      my @values = map { s{ \s+ }{}msx; $_ } split m{ [,] }msx, $value;

      push @{ $rec->{ $attr } }, map { decode( $charset, $_ ) } @values;
   }
   else { push @{ $rec->{ $attr } }, decode( $charset, $value ) }

   return;
}

sub _store_msgtext {
   my ($self, $rec, $line, $last_ref) = @_; my $key;

   $line = decode( $self->schema->charset, $line );

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

# Private write methods

sub _write_filter {
   my ($self, $data) = @_; my $header = $data->{po_header};

   $data = $data->{po}; $data->{ q() } = __fold_header( $header );

   my $attrs = $self->schema->source->attributes; my $buf ||= [];

   for my $rec (map  { $data->{ $_ } }
                sort { __original_order( $data, $a, $b ) } keys %{ $data }) {
      for my $attr_name (grep { exists $rec->{ $_ } } @{ $attrs }) {
         my $values = $rec->{ $attr_name }; defined $values or next; my $cpref;

         if ($cpref = __comment_prefix( $attr_name )) {
            $attr_name eq q(flags)
               and $values = [ SPC.(join q(, ), @{ $values }) ];

            $self->_push_comment( $buf, $cpref, $values );
         }
         elsif (ref $values eq ARRAY) {
            if (@{ $values } > 1) {
               $self->_array_push_split_on_nl( $buf, $attr_name, $values );
            }
            else {
               $self->_push_split_on_nl( $buf, $attr_name, $values->[ 0 ] );
            }
         }
         else { $self->_push_split_on_nl( $buf, $attr_name, $values ) }
      }

      push @{ $buf }, NUL;
   }

   pop @{ $buf };
   return $buf;
}

sub _array_push_split_on_nl {
   my ($self, $buf, $attr, $values) = @_; my $index = 0;

   for my $lines (@{ $values }) {
      $self->_push_split_on_nl( $buf, "${attr}[${index}]", $lines ); $index++;
   }

   return;
}

sub _push_comment {
   my ($self, $buf, $prefix, $values) = @_;

   my $charset = $self->schema->charset;

   for my $value (@{ $values }) {
      my $line = $prefix.$value; 2 == length $line and $line =~ s{ \s \z }{}msx;

      push @{ $buf }, encode( $charset, $line );
   }

   return;
}

sub _push_split_on_nl {
   my ($self, $buf, $prefix, $lines) = @_;

   $lines =~ s{ [\n] \s+ }{\\\n}gmsx;

   my $charset = $self->schema->charset;
   my @lines   = split m{ [\\][n] }msx, $lines;

   if (@lines < 2) {
      push @{ $buf }, $prefix.' "'.__encode_line( $charset, $lines ).'"';
   }
   else {
      push @{ $buf }, "${prefix} \"\"";

      for my $line (map { __encode_line( $charset, $_ ) } @lines) {
         push @{ $buf }, "\"${line}\\n\"\n";
      }
   }

   return;
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

sub __encode_line {
   my ($charset, $line) = @_;

   $line =~ s{ \A [\"] }{\\\"}msx; $line =~ s{ ([^\\])[\"] }{$1\\\"}gmsx;

   return encode( $charset, $line );
}

sub __extract_header {
   my $data = shift; my $header = (delete $data->{ q() }) || { msgstr => [] };

   my $null_entry = $header->{msgstr}->[ 0 ]; $header->{msgstr} = {};

   if ($null_entry) {
      for my $line (split m{ [\\][n] }msx, $null_entry) {
         my ($k, $v) = split m{ [:] }msx, $line, 2;

         $v =~ s{ \A \s+ }{}msx; $header->{msgstr}->{ $k } = $v;
      }
   }

   return $header;
}

sub __fold_header {
   my $original = shift; my $header = { %{ $original || {} } };

   my $msgstr_ref = $original->{msgstr} || {}; my $msgstr;

   my @header_keys = ( qw(Project-Id-Version Report-Msgid-Bugs-To
                          POT-Creation-Date PO-Revision-Date Last-Translator
                          Language-Team Language MIME-Version Content-Type
                          Content-Transfer-Encoding Plural-Forms) );

   for my $key (@header_keys) {
      $msgstr .= $key.': '.($msgstr_ref->{ $key } || q()).'\\n';
   }

   $header->{_order} = 0;
   $header->{msgid } = q();
   $header->{msgstr} = [ $msgstr ];
   return $header;
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
