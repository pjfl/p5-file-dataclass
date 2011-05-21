# @(#)$Id$

package File::DataClass::Storage::XML;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use XML::DTD;
use Moose;

extends qw(File::DataClass::Storage);

has '+extn'     => default => q(.xml);
has 'root_name' => is => 'ro', isa => 'Str',      default  => 'config';
has '_arrays'   => is => 'rw', isa => 'F_DC_HashRefOfBools',
   coerce       => TRUE,  init_arg => 'force_array',
   default      => sub { return {} };
has '_dtd'      => is => 'rw', isa => 'ArrayRef', init_arg => 'dtd',
   default      => sub { return [] };

around '_meta_pack' => sub {
   my ($orig, $self, $args) = @_; my $packed = $self->$orig( $args );

   $self->_dtd and $packed->{_dtd} = $self->_dtd;

   return $packed;
};

around '_meta_unpack' => sub {
   my ($orig, $self, $packed) = @_; $packed ||= {};

   $self->_dtd( exists $packed->{_dtd} ? delete $packed->{_dtd} : [] );

   return $self->$orig( $packed );
};

# Private methods

sub _dtd_parse {
   my ($self, $data) = @_;

   defined $self->_dtd->[ 0 ] and $self->_dtd_parse_reset; $data or return;

   while ($data =~ s{ ( <! [^<>]+ > ) }{}msx) {
      $1 and push @{ $self->_dtd }, $1;
   }

   my $dtd = XML::DTD->new; $dtd->sread( join NUL, @{ $self->_dtd } );

   for my $el (map { $dtd->element( $_ ) } @{ $dtd->elementnames }) {
      $el->{CMPNTTYPE} eq q(element) and $el->{CONTENTSPEC}->{eltname} eq ARRAY
         and $self->_arrays->{ $el->{NAME} } = TRUE;
   }

   return $data;
}

sub _dtd_parse_reset {
   my $self = shift; $self->_arrays( {} ); $self->_dtd( [] ); return;
}

sub _is_array {
   my ($self, $element) = @_;

   # TODO: Add _arrays attributes from schema definition
   return FALSE;
}

sub _is_in_dtd {
   my ($self, $candidate) = @_; my %elements;

   my $pattern = '<!ELEMENT \s+ (\w+) \s+ \( \s* ARRAY \s* \) \*? \s* >';

   for (grep { m{ \A $pattern \z }msx } @{ $self->_dtd } ) {
      $elements{ $_ } = TRUE;
   }

   return exists $elements{ $candidate };
}

sub _update {
   my ($self, $path, $element_obj, $overwrite, $condition) = @_;

   my $element = $element_obj->_resultset->source->name;

   $self->validate_params( $path, $element );
   $overwrite or $path->touch;

   if (        $self->_is_array ( $element )
       and not $self->_is_in_dtd( $element )) {
      push @{ $self->_dtd }, '<!ELEMENT '.$element.' (ARRAY)*>';
   }

   return $self->next::method( $path, $element_obj, $overwrite, $condition );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::XML - Read/write XML data storage model

=head1 Version

0.4.$Revision$

=head1 Synopsis

This is an abstract base class. See one of the subclasses for a
concrete example

=head1 Description

Implements the basic storage methods for reading and writing XML files

=head1 Subroutines/Methods

No public methods

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Storage>

=item L<Hash::Merge>

=item L<List::Util>

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
