# @(#)Ident: ThrowingExceptions.pm 2013-04-30 17:10 pjf ;

package File::DataClass::TraitFor::ThrowingExceptions;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.18.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Moose::Role;
use English qw(-no_match_vars);

requires qw(is_one_of_us);

# Public methods
sub caught {
   my ($self, @args) = @_; my $attr = __build_attr_from( @args );

   my $error = $attr->{error} ||= $EVAL_ERROR; $error or return;

   return $self->is_one_of_us( $error ) ? $error : $self->new( $attr );
}

sub throw {
   my ($self, @args) = @_;

   die $self->is_one_of_us( $args[ 0 ] ) ? $args[ 0 ] : $self->new( @args );
}

sub throw_on_error {
   my $self = shift; my $e; $e = $self->caught( @_ ) and die $e; return;
}

# Private functions
sub __build_attr_from {
   return ($_[ 0 ] && ref $_[ 0 ] eq q(HASH)) ? { %{ $_[ 0 ] } }
        :        (defined $_[ 1 ])            ? { @_ }
                                              : { error => $_[ 0 ] };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

File::DataClass::TraitFor::ThrowingExceptions - Detects and throws exceptions

=head1 Synopsis

   use Moose;

   with 'File::DataClass::TraitFor::ThrowingExceptions';

=head1 Version

This documents version v0.18.$Rev: 2 $ of L<File::DataClass::TraitFor::ThrowingExceptions>

=head1 Description

Detects and throws exceptions

=head1 Configuration and Environment

Requires the consuming class to have the class method C<is_one_of_us>

Defines no attributes

=head1 Subroutines/Methods

=head2 caught

   $self = $class->caught( [ @args ] );

Catches and returns a thrown exception or generates a new exception if
C<$EVAL_ERROR> has been set. Returns either an exception object or undef

=head2 throw

   $class->throw error => 'Path [_1] not found', args => [ 'pathname' ];

Create (or re-throw) an exception. If the passed parameter is a
blessed reference it is re-thrown. If a single scalar is passed it is
taken to be an error message, a new exception is created with all
other parameters taking their default values. If more than one
parameter is passed the it is treated as a list and used to
instantiate the new exception. The 'error' parameter must be provided
in this case

=head2 throw_on_error

   $class->throw_on_error( [ @args ] );

Calls L</caught> passing in the options C<@args> and if there was an
exception L</throw>s it

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::autoclean>

=item L<Moose::Role>

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
