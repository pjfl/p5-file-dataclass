# @(#)$Id$

package File::Gettext;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;

extends qw(File::DataClass::Schema);

has '+result_source_attributes' =>
   default           => sub { return {
      po             => {
         attributes  =>
            [ qw(translator-comment extracted-comment reference flags
                 previous msgctxt msgid msgid_plural msgstr) ],
         defaults    => {
            'translator-comment' => [], 'extracted-comment' => [],
            'flags'              => [], 'previous'          => [],
            'msgstr'             => [], },
         }, } };

has '+storage_class' => default => q(+File::Gettext::Storage);
has 'source_name'    => is => 'ro', isa => 'Str', default => q(po);

around 'source' => sub {
   my ($orig, $self) = @_; return $self->$orig( $self->source_name );
};

around 'resultset' => sub {
   my ($orig, $self) = @_; return $self->$orig( $self->source_name );
};

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::Gettext - Read and write GNU gettext po/mo files

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::Gettext;

=head1 Description

=head1 Subroutines/Methods

=head1 Configuration and Environment

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
