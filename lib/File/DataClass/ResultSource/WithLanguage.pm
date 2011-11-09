# @(#)$Id$

package File::DataClass::ResultSource::WithLanguage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use File::DataClass::Storage::WithLanguage;
use Moose;

extends qw(File::DataClass::ResultSource);

has 'lang'     => is => 'rw', isa => 'Str',
   default     => NUL, trigger => \&_set_lang;
has 'lang_dep' => is => 'rw', isa => 'Maybe[HashRef]';

sub BUILD {
   my $self = shift;

   if ($self->lang_dep) {
      my $attrs = { lang => $self->lang, storage => $self->storage };

      $self->storage( File::DataClass::Storage::WithLanguage->new( $attrs ) );
   }

   return;
}

# Private methods

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

0.6.$Revision$

=head1 Synopsis

=head1 Description

If the result source is language dependent then an instance of
L<File::DataClass::Combinator> is created as a proxy for the
storage class

=head1 Configuration and Environment

Defines these attributes

=over 3

=item B<lang>

The two character language code, e.g. de. The setting this attribute
is propagated via a trigger to the attribute of the same name in the
L<File::DataClass::Combinator> storage instance

=item B<lang_dep>

Is a hash ref of language dependent attributes names. The values a just set
to C<TRUE>

=back

=head1 Subroutines/Methods

=head2 BUILD

If the schema is language dependent then an instance of
L<File::DataClass::Combinator> is created as a proxy for the
storage class

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Combinator>

=item L<File::DataClass::ResultSource>

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

Copyright (c) 2010 Peter Flanigan. All rights reserved

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
