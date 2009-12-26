# @(#)$Id$

package File::DataClass::ResultSource::WithLanguage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Combinator;
use File::DataClass::Constants;
use Moose;

extends qw(File::DataClass::ResultSource);

has 'lang'     => is => 'rw', isa => 'Str',
   default     => NUL, trigger => \&_set_lang;
has 'lang_dep' => is => 'rw', isa => 'Maybe[HashRef]';

sub BUILD {
   my $self = shift;

   if ($self->lang_dep) {
      my $attrs = { lang => $self->lang, storage => $self->schema->storage };

      $self->storage( File::DataClass::Combinator->new( $attrs ) );
   }

   return;
}

sub _set_lang {
   my ($self, $lang, $old_lang) = @_;

   return defined $old_lang ? $self->storage->lang( $lang ) : undef;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::ResultSource::WithLanguage - Result source localisation

=head1 Version

0.1.$Revision$

=head1 Synopsis

=head1 Description

This is the base class for schema definitions. Each element in a data file
requires a schema definition to define it's attributes that should
inherit from this

=head1 Subroutines/Methods

=head2 BUILD

If the schema is language dependent then an instance of
L<File::DataClass::Combinator> is created as a proxy for the
storage class

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Base>

=item L<File::DataClass::Combinator>

=item L<File::DataClass::Storage>

=item L<Scalar::Util>

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
