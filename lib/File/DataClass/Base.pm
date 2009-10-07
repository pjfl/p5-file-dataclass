# @(#)$Id$

package File::DataClass::Base;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use File::DataClass::Constants;
use File::Spec;
use IPC::SRLock;
use Moose;

extends qw(Moose::Object Class::Accessor::Grouped);

has 'debug' =>
   ( is => q(rw), isa => q(Bool),   default => FALSE );
has 'log' =>
   ( is => q(rw), isa => q(Object), default => sub { Class::Null->new } );
has 'tempdir' =>
   ( is => q(rw), isa => q(Str),    default => sub { File::Spec->tmpdir } );

sub lock {
   my ($self, $args) = @_; my $lock;

   # There is only one lock object
   return $lock if ($lock = __PACKAGE__->get_inherited( q(lock) ));

   return Class::Null->new unless ($args and blessed $self);

   $args->{debug  } ||= $self->debug;
   $args->{log    } ||= $self->log;
   $args->{tempdir} ||= $self->tempdir;

   return __PACKAGE__->set_inherited( q(lock), IPC::SRLock->new( $args ) );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Base - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use parent qw(File::DataClass::Base);

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Accessor::Fast>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

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
