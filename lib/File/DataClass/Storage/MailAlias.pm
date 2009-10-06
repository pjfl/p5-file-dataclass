# @(#)$Id: MailAlias.pm 688 2009-08-19 02:17:20Z pjf $

package File::DataClass::Storage::MailAlias;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 688 $ =~ /\d+/gmx );
use parent qw(File::DataClass::Storage);

use Text::Wrap;

__PACKAGE__->config( extn => q() );

# Private methods

sub _read_file {
   my ($self, $path, $for_update) = @_;

   my $method = sub {
      return $self->_read_filter( [ $path->chomp->getlines ] );
   };

   return $self->_read_file_with_locking( $method, $path, $for_update );
}

sub _write_file {
   my ($self, $path, $data, $create) = @_;

   my $method = sub {
      my $wtr = shift;
      $wtr->println( @{ $self->_write_filter( $data ) } );
      return $data;
   };

   return $self->_write_file_with_locking( $method, $path, $create );
}

sub _read_filter {
   my ($self, $buf) = @_; $buf ||= [];

   my $res = {}; my $ord = 0; my $recipients;

   my ($alias, $comment, $created, $owner) = (q(), q(), q(), q());

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
         $line =~ s{ \s+ }{ }gmx; $line =~ s{ , \z }{}mx;
         push @{ $res->{ $alias }->recipients }, split m{ , }mx, $line;
      }
      else { ($alias, $comment, $created, $owner) = (q(), q(), q(), q()) }
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
         my $created = $alias->{created} || $self->stamp;

         push @{ $buf }, "# Created by $owner $created";
      }

      if ($comment = $alias->{comment}) {
         for my $line (@{ $comment }) {
            push @{ $buf }, wrap( '# ', '# ', $line );
         }
      }

      my $pad  = q( ) x (2 + length $name);
      my $line = $name.q(: ).(join q(,), @{ $alias->{recipients} || [] });

      push @{ $buf }, wrap( q(), $pad, $line ), q();
   }

   return $buf;
}

# Private subroutines

sub __original_order {
   my ($aliases, $lhs, $rhs) = @_;

   # New elements will be  added at the end
   return  1 unless (exists $aliases->{ $lhs }->{_order_by});
   return -1 unless (exists $aliases->{ $rhs }->{_order_by});

   return $aliases->{ $lhs }->{_order_by} <=> $aliases->{ $rhs }->{_order_by};
}

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::MailAlias - <One-line description of module's purpose>

=head1 Version

0.1.$Revision: 688 $

=head1 Synopsis

   use File::DataClass::Storage::MailAlias;

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
