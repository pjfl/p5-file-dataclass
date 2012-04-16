# @(#)$Id$

package File::DataClass::Exception;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.8.%d', q$Rev$ =~ /\d+/gmx );

use Exception::Class
   'File::DataClass::Exception::Base' => {
      fields => [ qw(args leader out rv) ] };

use base qw(File::DataClass::Exception::Base);

use Carp;
use MRO::Compat;
use English      qw(-no_match_vars);
use Scalar::Util qw(blessed);

our $IGNORE = [ __PACKAGE__ ];

sub new {
   my ($self, @rest) = @_;

   my $args   = @rest < 2 ? { error => $rest[ 0 ] } : { @rest };
   my $level  = 3; exists $args->{level} and $level = delete $args->{level};
   my ($package, $line) = (caller( $level ))[ 0, 2 ];
   my $leader = "${package}[${line}]: ";

   if (__is_one_of_us( $args->{error} )) {
      $args->{error}->{leader} = $leader; return $args->{error};
   }

   $args->{error} .= q();

   return $self->next::method( args           => [],
                               error          => 'Error unknown',
                               ignore_package => $IGNORE,
                               leader         => $leader,
                               out            => q(),
                               %{ $args } );
}

sub catch {
   my ($self, $e) = @_; $e ||= $EVAL_ERROR; $e or return;

   return __is_one_of_us( $e ) ? $e : $self->new( $e );
}

sub full_message {
   my $self = shift; my $text = $self->error or return;

   # Expand positional parameters of the form [_<n>]
   0 > index $text, q([_) and return $self->leader.$text;

   my @args = @{ $self->args }; push @args, map { q() } 0 .. 10;

   $text =~ s{ \[ _ (\d+) \] }{$args[ $1 - 1 ]}gmx;

   return $self->leader.$text;
}

sub stacktrace {
   my ($self, $skip) = @_; my ($l_no, @lines, %seen, $subr);

   for my $frame (reverse $self->trace->frames) {
      unless ($l_no = $seen{ $frame->package } and $l_no == $frame->line) {
         $subr and push @lines, join q( ), $subr, 'line', $frame->line;
         $seen{ $frame->package } = $frame->line;
      }

      $subr = $frame->subroutine;
   }

   defined $skip or $skip = 1; pop @lines while ($skip--);

   return wantarray ? reverse @lines : (join "\n", reverse @lines)."\n";
}

sub throw {
   my ($self, @rest) = @_;

   croak __is_one_of_us( $rest[ 0 ] ) ? $rest[ 0 ] : $self->new( @rest );
}

sub throw_on_error {
   my ($self, @rest) = @_;

   my $e; $e = $self->catch( @rest ) and $self->throw( $e );

   return;
}

# Private subroutines

sub __is_one_of_us {
   return $_[ 0 ] && blessed $_[ 0 ] && $_[ 0 ]->isa( __PACKAGE__ );
}

1;

__END__

=pod

=head1 Name

File::DataClass::Exception - Exception base class

=head1 Version

0.8.$Revision$

=head1 Synopsis

   use Moose;
   use Try::Tiny;

   extend qw(File::DataClass::Schema);

   sub some_method {
      my $self = shift;

      try   { this_will_fail }
      catch { $self->throw( $_ ) };
   }

=head1 Description

An exception class that inherits from a custom subclass of
L<Exception::Class>

=head1 Subroutines/Methods

=head2 new

Create an exception object. You probably do not want to call this directly,
but indirectly through L</catch> and L</throw>

=head2 catch

   $e = File::DataClass::Exception->catch( $error );

Catches and returns a thrown exception or generates a new exception if
I<EVAL_ERROR> has been set

=head2 full_message

   $printable_string = $e->full_message

What an instance of this class stringifies to

=head2 stacktrace

   $lines = $e->stacktrace( $num_lines_to_skip );

Return the stack trace. Defaults to skipping one (the first) line of output

=head2 throw

   File::DataClass::Exception->throw( $error );

Create (or re-throw) an exception to be caught by the catch above. If
the passed parameter is a reference it is re-thrown. If a single scalar
is passed it is taken to be an error message code, a new exception is
created with all other parameters taking their default values. If more
than one parameter is passed the it is treated as a list and used to
instantiate the new exception. The 'error' parameter must be provided
in this case

=head2 throw_on_error

   File::DataClass::Exception->throw_on_error $error );

Calls L</catch> and if the was an exception L</throw>s it

=head1 Diagnostics

None

=head1 Configuration and Environment

The C<$IGNORE> package variable is list of methods whose presence
should be suppressed in the stack trace output

=head1 Dependencies

=over 3

=item L<Exception::Class>

=item L<File::DataClass::Constants>

=item L<MRO::Compat>

=item L<Scalar::Util>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

The default ignore package list should be configurable

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan C<< <Support at RoxSoft.co.uk> >>

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
