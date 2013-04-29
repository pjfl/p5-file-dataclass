# @(#)Ident: TracingStacks.pm 2013-04-29 14:52 pjf ;

package File::DataClass::TraitFor::TracingStacks;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose::Role;
use MooseX::AttributeShortcuts;
use MooseX::Types   -declare => [ q(StackTrace) ];
use MooseX::Types::Moose         qw(ArrayRef HashRef Object);
use MooseX::Types::LoadableClass qw(LoadableClass);
use Scalar::Util                 qw(weaken);
use List::Util                   qw(first);

requires qw(ignore level);

# Type constraints
subtype StackTrace, as Object,
   where   { $_->can( q(frames) ) },
   message { blessed $_ ? 'Object '.(blessed $_).' is missing a frames method'
                        : "Scalar ${_} is not on object reference" };

# Object attributes (public)
has 'trace'        => is => 'lazy', isa => StackTrace,
   handles         => [ qw(frames) ], init_arg => undef;

has 'trace_args'   => is => 'lazy', isa => HashRef;

has 'trace_class'  => is => 'ro',   isa => LoadableClass, coerce => 1,
   default         => sub { q(Devel::StackTrace) };

# Construction
sub BUILD {}

after 'BUILD' => sub {
   my $self = shift; $self->trace; return;
};

# Public methods
sub _build_leader {
   my $self = shift; my $level = $self->level;

   my @frames = $self->frames; my ($leader, $line, $package);

   do {
      if ($package = $frames[ $level ]->package) {
         $line   = $frames[ $level ]->line;
         $leader = "${package}[${line}][${level}]: "; $level++;
      }
      else { $leader = $package = q() }
   }
   while ($package and __is_member( $package, $self->ignore) );

   return $leader;
}

sub stacktrace {
   my ($self, $skip) = @_; my ($l_no, @lines, %seen, $subr);

   for my $frame (reverse $self->frames) {
      unless ($l_no = $seen{ $frame->package } and $l_no == $frame->line) {
         my $symbol = $subr || $frame->package;

         $seen{ $frame->package } = $frame->line;

         if ($symbol !~ m{ :: __ANON__ \z }mx) {
            push @lines, join q( ), $symbol, 'line', $frame->line;
         }
      }

      $subr = $frame->subroutine;
   }

   defined $skip or $skip = 0; pop @lines while ($skip--);

   return wantarray ? reverse @lines : (join "\n", reverse @lines)."\n";
}

sub trace_frame_filter { # Lifted from StackTrace::Auto
   my $self = shift; my $found_mark = 0; weaken( $self );

   return sub {
      my ($raw)    = @_;
      my  $sub     = $raw->{caller}->[ 3 ];
     (my  $package = $sub) =~ s{ :: \w+ \z }{}mx;

      if    ($found_mark == 3) { return 1 }
      elsif ($found_mark == 2) {
         $sub =~ m{ ::new \z }mx and $self->isa( $package ) and return 0;
         $found_mark++; return 1;
      }
      elsif ($found_mark == 1) {
         $sub =~ m{ ::new \z }mx and $self->isa( $package ) and $found_mark++;
         return 0;
      }

      $raw->{caller}->[ 3 ] =~ m{ ::_build_trace \z }mx and $found_mark++;
      return 0;
   }
}

# Private methods
sub _build_trace {
   return $_[ 0 ]->trace_class->new( %{ $_[ 0 ]->trace_args } );
}

sub _build_trace_args {
   return { no_refs          => 1,
            respect_overload => 0,
            max_arg_length   => 0,
            frame_filter     => $_[ 0 ]->trace_frame_filter, };
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

File::DataClass::TraitFor::TracingStacks - One-line description of the modules purpose

=head1 Synopsis

   use File::DataClass::TraitFor::TracingStacks;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev$ of L<File::DataClass::TraitFor::TracingStacks>

=head1 Description

=head1 Configuration and Environment

Requires the C<ignore> and C<attributes> in the consuming class

Defines the following attributes;

=over 3

=item C<trace>

An instance of the C<trace_class>

=item C<trace_args>

A hash ref of arguments passed the C<trace_class> constructor when the
C<trace> attribute is instantiated

=item C<trace_class>

A loadable class which defaults to L<Devel::StackTrace>

=back

=head1 Subroutines/Methods

=head2 BUILD

Forces the instantiation of the C<trace> attribute

=head2 _build_leader

A builder for the C<leader> attribute defined in the consuming class

=head2 stacktrace

   $lines = $self->stacktrace( $num_lines_to_skip );

Return the stack trace. Defaults to skipping zero lines of output

=head2 trace_frame_filter

Lifted from L<StackTrace::Auto> this methods filters out frames from the
raw stacktrace that are not of interest. If is very clever

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::autoclean>

=item L<List::Util>

=item L<Moose::Role>

=item L<MooseX::AttributeShortcuts>

=item L<MooseX::Types>

=item L<MooseX::Types::Moose>

=item L<MooseX::Types::LoadableClass>

=item L<Scalar::Util>

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
