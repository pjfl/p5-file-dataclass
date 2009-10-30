# @(#)$Id$

package File::DataClass::Exception;

use Exception::Class
   'File::DataClass::Exception::Base' => { fields => [ qw(args) ] };

use strict;
use warnings;
use overload '""' => sub { shift->to_string }, fallback => 1;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use base qw(File::DataClass::Exception::Base);

use Carp;
use File::DataClass::Constants;
use English      qw(-no_match_vars);
use Scalar::Util qw(blessed);
use MRO::Compat;

our $IGNORE = [ __PACKAGE__ ];

sub new {
   my ($self, @rest) = @_;

   return $self->next::method( args           => [],
                               error          => 'Error unknown',
                               ignore_package => $IGNORE,
                               @rest );
}

sub catch {
   my ($self, $e) = @_; $e ||= $EVAL_ERROR;

   $e and blessed $e and $e->isa( __PACKAGE__ ) and return $e;

   return $e ? $self->new( error => NUL.$e ) : undef;
}

sub stacktrace {
   my $self = shift; my ($frame, $l_no, %seen, $text); my $i = 1;

   while (defined ($frame = $self->trace->frame( $i++ ))) {
      next if ($l_no = $seen{ $frame->package } and $l_no == $frame->line);

      $text .= $frame->package.' line '.$frame->line."\n";

      $seen{ $frame->package } = $frame->line;
   }

   return $text;
}

sub throw {
   my ($self, @rest) = @_; my $e = $rest[0];

   $e and blessed $e and $e->isa( __PACKAGE__ ) and croak $e;

   croak $self->new( @rest == 1 ? ( error => NUL.$e ) : @rest );
}

sub throw_on_error {
   my ($self, @rest) = @_; my $e;

   $e = $self->catch( @rest ) and $self->throw( $e );

   return;
}

sub to_string {
   my $self = shift; my $text = $self->error or return;

   # Expand positional parameters of the form [_<n>]
   0 > index $text, LOCALIZE and return $text;

   my @args = @{ $self->args }; push @args, map { NUL } 0 .. 10;

   $text =~ s{ \[ _ (\d+) \] }{$args[ $1 - 1 ]}gmx;

   return $text;
}

1;

__END__

=pod

=head1 Name

File::DataClass::Exception - Exception base class

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use parent qw(File::DataClass::Base);

   sub some_method {
      my $self = shift;

      eval { this_will_fail }

      $self->throw_on_error;
   }

=head1 Description

Implements try (by way of an eval), throw, and catch error
semantics. Inherits from L<Exception::Class>

=head1 Subroutines/Methods

=head2 new

Create an exception object. You probably do not want to call this directly,
but indirectly through L</catch> and L</throw>

=head2 as_string

   warn $e->as_string( $verbosity, $offset );

Serialise the exception to a string. The passed parameters; I<verbosity>
and I<offset> determine how much output is returned.

The I<verbosity> parameter can be:

=over 3

=item 1

The default value. Only show a stack trace if C<< $self->show_trace >> is true

=item 2

Always show the stack trace and start at frame I<offset> which
defaults to 1. The stack trace stops when the first duplicate output
line is detected

=item 3

Always shows the complete stack trace starting at frame 0

=back

=head2 catch

Catches and returns a thrown exception or generates a new exception if
I<EVAL_ERROR> has been set

=head2 throw

Create (or re-throw) an exception to be caught by the catch above. If
the passed parameter is a reference it is re-thrown. If a single scalar
is passed it is taken to be an error message code, a new exception is
created with all other parameters taking their default values. If more
than one parameter is passed the it is treated as a list and used to
instantiate the new exception. The 'error' parameter must be provided
in this case

=head2 throw_on_error

Calls L</catch> and if the was an exception L</throw>s it

=head2 to_string

What an instance of this class stringifies to

=head1 Diagnostics

None

=head1 Configuration and Environment

The C<$IGNORE> package variable is list of methods whose presence
should be suppressed in the stack trace output

=head1 Dependencies

=over 3

=item L<Exception::Class>

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
