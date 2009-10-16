# @(#)$Id$

package File::DataClass::Exception;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use overload '""' => sub { shift->as_string }, fallback => 1;
use Exception::Class
   ( 'File::DataClass::Exception::Base' => {
      fields => [ qw(args messages) ] } );
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
                               messages       => {},
                               show_trace     => FALSE,
                               @rest );
}

sub as_string {
   my ($self, $verbosity, $offset) = @_; $verbosity ||= 1; $offset ||= 1;

   my $text = $self->_localize;

   return $text if ($verbosity < 2 and not $self->show_trace);

   my $i = $verbosity > 2 ? 0 : $offset; my ($frame, $l_no, %seen);

   while (defined ($frame = $self->trace->frame( $i++ ))) {
      my $line = "\n".$frame->package.' line '.$frame->line;

      if ($verbosity > 2) { $text .= $line; next }

      last if (($l_no = $seen{ $frame->package }) && $l_no == $frame->line);

      $seen{ $frame->package } = $frame->line;
   }

   return $text;
}

sub catch {
   my ($self, $e) = @_; $e ||= $EVAL_ERROR;

   return $e if ($e and blessed $e and $e->isa( __PACKAGE__ ));

   return $self->new( error => $e ) if ($e);

   return;
}

sub throw {
   my ($self, @rest) = @_; my $e = $rest[0];

   croak $e && blessed $e
       ? $e : $self->new( @rest == 1 ? ( error => $e ) : @rest );
}

sub throw_on_error {
   my $self = shift; my $e;

   return $e = $self->catch ? $self->throw( $e ) : undef;
}

# Private methods

sub _localize {
   my $self = shift; my $key = $self->error;

   return unless $key; $key = NUL.$key; # Stringify

   # Lookup the message using the supplied key
   my $messages = $self->{messages}   || {};
   my $msg      = $messages->{ $key } || {};
   my $text     = ($msg && ref $msg eq HASH ? $msg->{text} : $msg) || $key;

   # Expand positional parameters of the form [_<n>]
   if (0 <= index $text, LSB) {
      my @args = @{ $self->args };

      push @args, map { NUL } 0 .. 10;
      $text =~ s{ \[ _ (\d+) \] }{$args[ $1 - 1 ]}gmx;
   }

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
