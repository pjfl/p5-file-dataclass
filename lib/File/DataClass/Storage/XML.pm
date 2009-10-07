# @(#)$Id: XML.pm 685 2009-08-17 22:01:00Z pjf $

package File::DataClass::Storage::XML;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev: 685 $ =~ /\d+/gmx );

use Moose;
use MRO::Compat;

extends qw(File::DataClass::Storage);

has '+extn'     => ( is => q(ro), isa => q(Str), default => q(.xml) );
has 'root_name' => ( is => q(ro), isa => q(Str), default => q(config) );
has '_arrays'   => ( is => q(rw), isa => q(HashRef),
                     default => sub { return {} } );
has '_dtd'      => ( is => q(rw), isa => q(ArrayRef),
                     default => sub { return [] } );

# Private methods

sub _cache_get {
   my ($self, $key) = @_; my $cached = $self->_cache( $key );

   $self->_dtd( $cached && exists $cached->{_dtd} ? $cached->{_dtd} : [] );

   return $cached ? ($cached->{data}, $cached->{mtime} || 0) : (undef, 0);
}

sub _cache_set {
   my ($self, $key, $data, $mtime) = @_;

   my $ref = { data => $data, mtime => $mtime };

   $ref->{_dtd} = $self->_dtd if ($self->_dtd);

   $self->_cache( $key, $ref );
   return ($data, $mtime);
}

sub _dtd_parse {
   my ($self, $data) = @_;

   $self->_dtd_parse_reset;

   return unless ($data);

   while ($data =~ s{ ( <! [^<>]+ > ) }{}msx) {
      push @{ $self->_dtd }, $1; $self->_dtd_parse_line( $1 );
   }

   return $data;
}

sub _dtd_parse_line {
   my ($self, $data) = @_;

   if ($data =~ m{ \A <!ELEMENT \s+ (\w+) \s+ \(
                      \s* ARRAY \s* \) \*? \s* > \z }imsx) {
      $self->_arrays->{ $1 } = 1;
   }

   return;
}

sub _dtd_parse_reset {
   my $self = shift; $self->_arrays( {} ); $self->_dtd( [] ); return;
}

sub _is_array {
   my ($self, $element) = @_;

   return 0;
}

sub _is_in_dtd {
   my ($self, $candidate) = @_; my %elements;

   my $pattern = '<!ELEMENT \s+ (\w+) \s+ \( \s* ARRAY \s* \) \*? \s* >';

   for (grep { m{ \A $pattern \z }msx } @{ $self->_dtd } ) {
      $elements{ $_ } = 1;
   }

   return exists $elements{ $candidate };
}

sub _update {
   my ($self, $overwrite, $element_obj, $path, $element, $condition) = @_;

   $path->touch unless ($overwrite);

   # TODO: Add _arrays attributes from schema definition
   if ($self->_is_array( $element ) and not $self->_is_in_dtd( $element )) {
      push @{ $self->_dtd }, '<!ELEMENT '.$element.' (ARRAY)*>';
   }

   return $self->next::method( $overwrite, $element_obj,
                               $path, $element, $condition );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::XML - Read/write XML data storage model

=head1 Version

0.4.$Revision: 685 $

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
