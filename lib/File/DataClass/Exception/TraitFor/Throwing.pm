# @(#)Ident: Throwing.pm 2013-05-01 20:10 pjf ;

package File::DataClass::Exception::TraitFor::Throwing;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.19.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Carp      ();
use English qw(-no_match_vars);
use Moose::Role;

requires qw(is_one_of_us);

my %_CACHE;

# Lifted from Throwable
has 'previous_exception' => is => 'ro',
   default               => sub { $_CACHE{ __cache_key() } };

# Construction
sub BUILD {}

after 'BUILD' => sub {
   my $self = shift; $self->_cache_exception; return;
};

# Public methods
sub caught {
   my ($self, @args) = @_; $self->_is_object_ref( @args ) and return $self;

   my $attr  = __build_attr_from( @args );
   my $error = $attr->{error} ||= $EVAL_ERROR; $error or return;

   return $self->is_one_of_us( $error ) ? $error : $self->new( $attr );
}

sub throw {
   my ($self, @args) = @_;

   $self->_is_object_ref( @args )    and die $self;
   $self->is_one_of_us( $args[ 0 ] ) and die $args[ 0 ];
                                         die $self->new( @args );
}

sub throw_on_error {
   my $e; $e = shift->caught( @_ ) and die $e; return;
}

# Private methods
sub _cache_exception {
   my $self = shift; my $e = bless { %{ $self } }, blessed $self;

   delete $e->{previous_exception}; $_CACHE{ __cache_key() } = $e;

   return;
}

sub _is_object_ref {
   my ($self, @args) = @_; blessed $self or return 0;

   scalar @args and Carp::confess
      'Trying to throw an Exception object with arguments';
   return 1;
}

# Private functions
sub __build_attr_from {
   return ($_[ 0 ] && ref $_[ 0 ] eq q(HASH)) ? { %{ $_[ 0 ] } }
        :        (defined $_[ 1 ])            ? { @_ }
                                              : { error => $_[ 0 ] };
}

sub __cache_key {
   return $PID.'-'.(exists $INC{ 'threads.pm' } ? threads->tid() : 0);
}

1;

__END__

=pod

=encoding utf8

=head1 Name

File::DataClass::Exception::TraitFor::Throwing - Detects and throws exceptions

=head1 Synopsis

   use Moose;

   with 'File::DataClass::Exception::TraitFor::Throwing';

=head1 Version

This documents version v0.19.$Rev: 1 $ of
L<File::DataClass::Exception::TraitFor::Throwing>

=head1 Description

Detects and throws exceptions

=head1 Configuration and Environment

Requires the consuming class to have the class method C<is_one_of_us>

Defines the following list of attributes;

=over 3

=item C<previous_exception>

May hold a reference to the previous exception in this thread

=back

Modifies C<BUILD> in the consuming class. Caches the new exception for
use by the C<previous_exception> attribute in the next exception thrown

=head1 Subroutines/Methods

=head2 BUILD

Default subroutine enable method modifiers

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
