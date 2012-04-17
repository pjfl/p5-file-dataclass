# @(#)$Id$

package File::DataClass::Schema::WithLanguage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.8.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use File::DataClass::Constants;
use File::DataClass::Constraints qw(Directory);
use File::DataClass::ResultSource::WithLanguage;
use File::DataClass::Storage::WithLanguage;
use File::Gettext::Constants;
use MooseX::Types::Moose qw(Str);

extends qw(File::DataClass::Schema);

has 'lang'      => is => 'rw', isa => Str,     default => LANG;
has 'localedir' => is => 'ro', isa => Directory, coerce  => TRUE,
   default      => sub { DIRECTORIES->[ 0 ] };

around BUILDARGS => sub {
   my ($next, $class, @args) = @_; my $attrs = $class->$next( @args );

   $attrs->{result_source_class}
      = q(File::DataClass::ResultSource::WithLanguage);

   return $attrs;
};

sub BUILD {
   my $self    = shift;
   my $storage = $self->storage;
   my $class   = q(File::DataClass::Storage::WithLanguage);
   my $attrs   = { schema => $self, storage => $storage };

   blessed $storage ne $class and $self->storage( $class->new( $attrs ) );

   return;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Schema::WithLanguage - Adds language support to the default schema

=head1 Version

0.8.$Revision$

=head1 Synopsis

   use File::DataClass::Schema::WithLanguage;

=head1 Description

Extends L<File::DataClass::Schema>

=head1 Configuration and Environment

Defines these attributes

=over 3

=item B<lang>

The two character language code, e.g. de.

=back

=head1 Subroutines/Methods

=head2 BUILD

If the schema is language dependent then an instance of
L<File::DataClass::Storage::WithLanguage> is created as a proxy for the
storage class

=head1 Diagnostics

=head1 Dependencies

=over 3

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

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2011 Peter Flanigan. All rights reserved

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
