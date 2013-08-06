# @(#)Ident: Exception.pm 2013-07-19 12:46 pjf ;

package File::DataClass::Exception;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.23.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Moo;
use Unexpected::Types qw(Str);

extends q(Unexpected);
with    q(Unexpected::TraitFor::ErrorLeader);

__PACKAGE__->ignore_class( 'File::DataClass::IO' );

has '+class' => default => __PACKAGE__;

has 'out'    => is => 'ro', isa => Str, default => q();

1;

__END__

=pod

=encoding utf8

=head1 Name

File::DataClass::Exception - Exception class composed from traits

=head1 Synopsis

   use File::DataClass::Functions qw(throw);
   use Try::Tiny;

   sub some_method {
      my $self = shift;

      try   { this_will_fail }
      catch { throw $_ };
   }

   # OR
   use File::DataClass::Exception;

   sub some_method {
      my $self = shift;

      eval { this_will_fail };
      File::DataClass::Exception->throw_on_error;
   }

   # THEN
   try   { $self->some_method() }
   catch { warn $_."\n\n".$_->stacktrace."\n" };

=head1 Version

This documents version v0.23.$Rev: 1 $ of L<File::DataClass::Exception>

=head1 Description

An exception class that supports error messages with placeholders, a
L<File::DataClass::Exception::TraitFor::Throwing/throw> method with
automatic re-throw upon detection of self, conditional throw if an
exception was caught and a simplified stacktrace

Applies exception roles to the exception base class L<Unexpected>. See
L</Dependencies> for the list of roles that are applied

Error objects are overloaded to stringify to the full error message
plus a leader if the optional C<ErrorLeader> role has been applied

=head1 Configuration and Environment

Ignores L<File::DataClass::IO> when creating exception leaders

Overrides the C<class> attribute setting it's value to this class

Defines these attributes;

=over 3

=item C<class>

Defaults the "class" of a thrown exception to L<File::DataClass::Exception>

=item C<out>

A string containing the output from whatever was being called before
it threw

=back

=head1 Subroutines/Methods

=head2 as_string

   $printable_string = $e->as_string

What an instance of this class stringifies to

=head2 caught

   $e = IPC::SRLock::Exception->caught( $error );

Catches and returns a thrown exception or generates a new exception if
C<EVAL_ERROR> has been set or if an error string was passed in

=head2 stacktrace

   $lines = $e->stacktrace( $num_lines_to_skip );

Return the stack trace. Defaults to skipping zero lines of output
Skips anonymous stack frames, minimalist

=head2 throw

   IPC::SRLock::Exception->throw( $error );

Create (or re-throw) an exception to be caught by the L</caught> method. If
the passed parameter is a reference it is re-thrown. If a single scalar
is passed it is taken to be an error message code, a new exception is
created with all other parameters taking their default values. If more
than one parameter is passed the it is treated as a list and used to
instantiate the new exception. The C<error> attribute must be provided
in this case

=head2 throw_on_error

   IPC::SRLock::Exception->throw_on_error( $error );

Calls L</caught> and if the was an exception L</throw>s it

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::sweep>

=item L<Moo>

=item L<Unexpected>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

L<Throwable::Error> - Lifted the stack frame filter from here

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
