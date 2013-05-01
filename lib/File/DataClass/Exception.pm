# @(#)Ident: Exception.pm 2013-05-01 20:20 pjf ;

package File::DataClass::Exception;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.18.%d', q$Rev: 11 $ =~ /\d+/gmx );

use Moose;
use MooseX::ClassAttribute;
use MooseX::Types::Moose qw(ArrayRef);

extends q(File::DataClass::Exception::Base);

class_has 'Ignore' => is => 'ro', isa => ArrayRef, traits => [ 'Array' ],
   default         => sub { [ qw(File::DataClass::IO) ] },
   handles         => { ignore_class => 'push' },  reader => 'ignore';

sub is_one_of_us {
   return $_[ 1 ] && blessed $_[ 1 ] && $_[ 1 ]->isa( __PACKAGE__ );
}

with q(File::DataClass::Exception::TraitFor::Throwing);
with q(File::DataClass::Exception::TraitFor::TracingStacks);
with q(File::DataClass::Exception::TraitFor::ErrorLeader);

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf8

=head1 Name

File::DataClass::Exception - Consumes the base class and applies roles

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

This documents version v0.18.$Rev: 11 $ of L<File::DataClass::Exception>

=head1 Description

An exception class that supports error messages with placeholders, a
L<File::DataClass::Exception::TraitFor::Throwing/throw> method with
automatic re-throw upon detection of self, conditional throw if an
exception was caught and a simplified stacktrace

Error objects are overloaded to stringify to the full error message
plus a leader

Applies exception roles to the exception base class
L<File::DataClass::Exception::Base>. See L</Dependencies> for the list of
roles that are applied

=head1 Configuration and Environment

The C<< File::DataClass::Exception->Ignore >> class attribute is an
array ref of methods whose presence should be ignored by the error
message leader. It does the 'Array' trait where C<push> implements the
C<ignore_class> method

=head1 Subroutines/Methods

=head2 is_one_of_us

   $bool = $class->is_one_of_us( $string_or_exception_object_ref );

Class method which detects instances of this exception class

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::autoclean>

=item L<File::DataClass::Exception::Base>

=item L<File::DataClass::Exception::TraitFor::Throwing>

=item L<File::DataClass::Exception::TraitFor::TracingStacks>

=item L<File::DataClass::Exception::TraitFor::ErrorLeader>

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
