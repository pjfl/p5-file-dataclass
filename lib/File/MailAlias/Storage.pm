# @(#)$Id$

package File::MailAlias::Storage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.10.%d', q$Rev$ =~ /\d+/gmx );

use Date::Format;
use File::DataClass::Constants;
use Moose;
use Text::Wrap;

extends qw(File::DataClass::Storage);

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

sub _read_filter {
   my ($self, $buf) = @_; $buf ||= [];

   my $res = {}; my $ord = 0; my $recipients;

   my ($alias, $comment, $created, $owner) = (NUL, NUL, NUL, NUL);

   for my $line (@{ $buf }) {
      if ($line and $line =~ m{ \A \# }mx) {
         $line =~ s{ \A \# \s* }{}mx;

         if ($line =~ m{ \A Created \s+ by \s+ ([^ ]+) \s+ (.*) }mx) {
            $owner = $1; $created = $2;
         }
         elsif (not $comment) { $comment = [ $line ] }
         else { push @{ $comment }, $line }
      }
      elsif ($line and $line !~ m{ \A \# }mx
             and $line =~ m{ \A (([^:]+) : \s+) (.*) }mx) {
         $alias      =  $2;
         $recipients =  $3;
         $recipients =~ s{ \s+ }{}gmx; $recipients =~ s{ , \z }{}mx;

         $res->{ $alias } = {
            comment    => $comment,
            created    => $created,
            owner      => $owner,
            recipients => [ split m{ , }mx, $recipients ],
            _order_by  => $ord++,
         };
      }
      elsif ($line and $line !~ m{ \A \# }mx and $alias) {
         $line =~ s{ \s+ }{}gmx; $line =~ s{ , \z }{}mx;
         push @{ $res->{ $alias }->{recipients} }, split m{ , }mx, $line;
      }
      else { ($alias, $comment, $created, $owner) = (NUL, NUL, NUL, NUL) }
   }

   return { aliases => $res };
}

sub _write_filter {
   my ($self, $data) = @_; my $aliases = $data->{aliases}; my $buf = [];

## no critic
   local $Text::Wrap::columns  = 80; local $Text::Wrap::unexpand = 0;
## critic

   for my $name (sort  { __original_order( $aliases, $a, $b ) }
                 keys %{ $aliases }) {
      my $alias = $aliases->{ $name }; my ($comment, $owner);

      if ($owner = $alias->{owner}) {
         my $created = $alias->{created} || __stamp();

         push @{ $buf }, "# Created by $owner $created";
      }

      if ($comment = $alias->{comment}) {
         for my $line (@{ $comment }) {
            push @{ $buf }, wrap( '# ', '# ', $line );
         }
      }

      my $pad  = SPC x (2 + length $name);
      my $line = $name.q(: ).(join q(, ), @{ $alias->{recipients} || [] });

      push @{ $buf }, wrap( NUL, $pad, $line ), NUL;
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

sub __stamp {
   return Date::Format::Generic->time2str( '%Y-%m-%d %H:%M:%S', time );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::MailAlias::Storage - Storage class file the mail alias file

=head1 Version

0.10.$Revision$

=head1 Synopsis

   use File::MailAlias::Storage;

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Text::Wrap>

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

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
