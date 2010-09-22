# @(#)$Id$

package File::DataClass::HashMerge;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Carp;

sub merge {
   my ($self, $src, $dest_ref, $condition) = @_; my $updated = FALSE;

   $dest_ref or croak 'No destination reference specified';

   $src ||= {}; ${ $dest_ref } ||= {}; $condition ||= sub { return TRUE };

   for my $attr (__get_src_attributes( $condition, $src )) {
      if (defined $src->{ $attr }) {
         my $res = $self->_merge_attr
            ( $src->{ $attr }, \${ $dest_ref }->{ $attr } );

         $updated ||= $res;
      }
      elsif (exists ${ $dest_ref }->{ $attr }) {
         delete ${ $dest_ref }->{ $attr }; $updated = TRUE;
      }
   }

   $updated and ${ $dest_ref }->{name} = $src->{name};

   return $updated;
}

# Private methods

sub _merge_attr {
   my ($self, $from, $to_ref) = @_; my $updated = FALSE; my $to = ${ $to_ref };

   if ($to and ref $to eq ARRAY) {
      $updated = $self->_merge_attr_arrays( $from, $to );
   }
   elsif ($to and ref $to eq HASH) {
      $updated = $self->_merge_attr_hashes( $from, $to );
   }
   elsif ((not $to and defined $from) or ($to and $to ne $from)) {
      $updated = TRUE; ${ $to_ref } = $from;
   }

   return $updated;
}

sub _merge_attr_arrays {
   my ($self, $from, $to) = @_; my $updated = FALSE;

   for (0 .. $#{ $to }) {
      if ($from->[ $_ ]) {
         my $res = $self->_merge_attr( $from->[ $_ ], \$to->[ $_ ] );

         $updated ||= $res;
      }
      elsif ($to->[ $_ ]) {
         splice @{ $to }, $_; $updated = TRUE; last;
      }
   }

   if (@{ $from } > @{ $to }) {
      push @{ $to }, (splice @{ $from }, $#{ $to } + 1); $updated = TRUE;
   }

   return $updated;
}

sub _merge_attr_hashes {
   my ($self, $from, $to) = @_; my $updated = FALSE;

   for (keys %{ $to }) {
      if ($from->{ $_ }) {
         my $res = $self->_merge_attr( $from->{ $_ }, \$to->{ $_ } );

         $updated ||= $res;
      }
      elsif ($to->{ $_ }) {
         delete $to->{ $_ }; $updated = TRUE;
      }
   }

   if (keys %{ $from } > keys %{ $to }) {
      for (keys %{ $from }) {
         if ($from->{ $_ } and not exists $to->{ $_ }) {
            $to->{ $_ } = $from->{ $_ }; $updated = TRUE;
         }
      }
   }

   return $updated;
}

# Private subroutines

sub __get_src_attributes {
   my ($condition, $src) = @_;

   return grep { not m{ \A _ }mx
                 and $_ ne q(name)
                 and $condition->( $_ ) } keys %{ $src };
}

1;

__END__

=pod

=head1 Name

File::DataClass::HashMerge - Merge hashes with update flag

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::DataClass::HashMerge;

   $class   = q(File::DataClass::HashMerge);
   $updated = $class->merge( $src, $dest_ref, $condition );

=head1 Description

Merge the attributes from the source hash ref into destination ref

=head1 Subroutines/Methods

=head2 merge

   $class = q(File::DataClass::HashMerge);
   $bool  = $class->merge( $src, $dest_ref, $condition );

Only merge the attributes from C<$src> to C<$dest_ref> if the
C<$condition> coderef evaluates to true. Return true if the destination
ref was updated

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

None

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2010 Peter Flanigan. All rights reserved

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
