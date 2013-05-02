# @(#)Ident: ErrorLeader.pm 2013-05-01 17:32 pjf ;

package File::DataClass::Exception::TraitFor::ErrorLeader;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.19.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Moose::Role;
use MooseX::Types::Common::Numeric qw(PositiveInt);
use MooseX::Types::Common::String  qw(NonEmptySimpleStr);
use List::Util                     qw(first);

requires qw(as_string frames ignore);

# Object methods (public)
has 'leader' => is => 'ro', isa => NonEmptySimpleStr,
   builder   => '_build_leader', init_arg => undef, lazy => 1;

has 'level'  => is => 'ro', isa => PositiveInt, default => 1;

# Construction
around 'as_string' => sub {
   my ($next, $self, @args) = @_; my $str = $self->$next( @args );

   return $str ? $self->leader.$str : $str;
};

# Private methods
sub _build_leader {
   my $self = shift; my $level = $self->level;

   my @frames = $self->frames; my ($leader, $line, $package);

   $level >= scalar @frames and $level = scalar @frames - 1;

   do {
      if ($frames[ $level ] and $package = $frames[ $level ]->package) {
         $line    = $frames[ $level ]->line;
         $leader  = $package; $leader =~ s{ :: }{-}gmx;
         $leader .= "[${line}/${level}]: "; $level++;
      }
      else { $leader = $package = q() }
   }
   while ($package and __is_member( $package, $self->ignore) );

   return $leader;
}

# Private functions
sub __is_member {
   my ($candidate, @args) = @_; $candidate or return;

   $args[ 0 ] && ref $args[ 0 ] eq q(ARRAY) and @args = @{ $args[ 0 ] };

   return (first { $_ eq $candidate } @args) ? 1 : 0;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

File::DataClass::Exception::TraitFor::ErrorLeader - Prepends a leader to the exception

=head1 Synopsis

   use Moose;

   with 'File::DataClass::Exception::TraitFor::ErrorLeader';

=head1 Version

This documents version v0.19.$Rev: 1 $
of L<File::DataClass::Exception::TraitFor::ErrorLeader>

=head1 Description

Prepends a one line stack summary to the exception error message

=head1 Configuration and Environment

Requires the C<as_string> method and the C<ignore> attribute in the
consuming class

Defines the following attributes;

=over 3

=item C<leader>

Set to the package and line number where the error should be reported

=item C<level>

A positive integer which defaults to one. How many additional stack frames
to pop before calculating the C<leader> attribute

=back

Modifies C<as_string> in the consuming class. Prepends the C<leader>
attribute to the return value

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::autoclean>

=item L<Moose::Role>

=item L<List::Util>

=item L<MooseX::Types::Common::Numeric>

=item L<MooseX::Types::Common::String>

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

Peter Flanigan, C<< <pjfl@cpan.org> >>

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
