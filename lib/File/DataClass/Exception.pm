# @(#)$Id$

package File::DataClass::Exception;

# Package namespace::autoclean does not play nice with overload
use namespace::clean -except => 'meta';
use overload '""' => sub { shift->as_string }, fallback => 1;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use MooseX::ClassAttribute;
use MooseX::AttributeShortcuts;
use MooseX::Types::Common::String  qw(NonEmptySimpleStr);
use MooseX::Types::Common::Numeric qw(PositiveInt);
use MooseX::Types::Moose           qw(ArrayRef);

# Class attributes
class_has 'Ignore' => is => 'ro', isa => ArrayRef,
   default         => sub { [ qw(File::DataClass::IO) ] };

# Object attributes (public)
has 'args'   => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'class'  => is => 'ro',   isa => NonEmptySimpleStr,
   default   => __PACKAGE__;

has 'error'  => is => 'ro',   isa => NonEmptySimpleStr,
   default   => 'Unknown error';

has 'ignore' => is => 'ro',   isa => ArrayRef,
   default   => sub { __PACKAGE__->Ignore }, init_arg => undef;

has 'leader' => is => 'lazy', isa => NonEmptySimpleStr;

has 'level'  => is => 'ro',   isa => PositiveInt, default => 1;

with q(File::DataClass::TraitFor::ThrowingExceptions);
with q(File::DataClass::TraitFor::TracingStacks);

# Construction
around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $attr = __get_attr( @args );

   $attr->{error} and $attr->{error} .= q() and chomp $attr->{error};

   return $attr;
};

# Public methods
sub as_string {
   my $self = shift; my $text = $self->error or return;

   # Expand positional parameters of the form [_<n>]
   0 > index $text, q([_)  and return $self->leader.$text;

   my @args = map { $_ // '[?]' } @{ $self->args }, map { '[?]' } 0 .. 9;

   $text =~ s{ \[ _ (\d+) \] }{$args[ $1 - 1 ]}gmx;

   return $self->leader.$text;
}

# Private functions
sub __get_attr {
   return ($_[ 0 ] && ref $_[ 0 ] eq q(HASH)) ? { %{ $_[ 0 ] } }
        : (defined $_[ 1 ])                   ? { @_ }
                                              : { error => $_[ 0 ] };
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

File::DataClass::Exception - Exception handling

=head1 Version

This documents version v0.15.$Rev$ of L<File::DataClass::Exception>

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

=head1 Description

An exception class that supports error messages with placeholders, a
L</throw> method with automatic re-throw upon detection of self,
conditional throw if an exception was caught and a simplified
stacktrace

Error objects are overloaded to stringify to the full error message
plus a leader

=head1 Configuration and Environment

The C<< File::DataClass::Exception->Ignore >> class attribute is an
array ref of methods whose presence should be ignored by the error
message leader

Defines the following list of read only attributes;

=over 3

=item C<args>

An array ref of parameters substituted in for the placeholders in the
error message when the error is localised

=item C<class>

Defaults to C<__PACKAGE__>. Can be used to differentiate different classes of
error

=item C<error>

The actually error message which defaults to C<Unknown error>. Can contain
placeholders of the form C<< [_<n>] >> where C<< <n> >> is an integer
starting at one

=item C<leader>

Set to the package and line number where the error should be reported

=item C<level>

A positive integer which defaults to one. How many additional stack frames
to pop before calculating the C<leader> attribute

=back

=head1 Subroutines/Methods

=head2 as_string

   $error_text = $self->as_string;

This is what the object stringifies to, including the C<leader> attribute

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::clean>

=item L<overload>

=item L<Devel::StackTrace>

=item L<File::DataClass::TraitFor::ThrowingExceptions>

=item L<File::DataClass::TraitFor::TracingStacks>

=item L<List::Util>

=item L<Moose>

=item L<MooseX::ClassAttribute>

=item L<MooseX::AttributeShortcuts>

=item L<MooseX::Types>

=item L<MooseX::Types::Common::String>

=item L<MooseX::Types::Common::Numeric>

=item L<MooseX::Types::LoadableClass>

=item L<MooseX::Types::Moose>

=item L<Scalar::Util>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan C<< <pjfl@cpan.org> >>

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
