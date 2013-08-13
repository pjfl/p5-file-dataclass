# @(#)$Ident: XML.pm 2013-08-13 17:41 pjf ;

package File::DataClass::Storage::XML;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.24.%d', q$Rev: 1 $ =~ /\d+/gmx );

use File::DataClass::Constants;
use File::DataClass::Types  qw( HashRefOfBools );
use Moo;
use Unexpected::Types       qw( ArrayRef Str );

extends q(File::DataClass::Storage);

has '+extn'     => default => q(.xml);

has 'root_name' => is => 'ro', isa => Str, default => 'config';


has '_arrays'   => is => 'rw', isa => HashRefOfBools, default => sub { {} },
   init_arg     => 'force_array', coerce => HashRefOfBools->coercion;

has '_dtd'      => is => 'rw', isa => ArrayRef, default => sub { [] },
   init_arg     => 'dtd';

around 'meta_pack' => sub {
   my ($orig, $self, @args) = @_; my $packed = $orig->( $self, @args );

   $self->_dtd and $packed->{_dtd} = $self->_dtd;

   return $packed;
};

around 'meta_unpack' => sub {
   my ($orig, $self, $packed) = @_; $packed ||= {};

   $self->_dtd( exists $packed->{_dtd} ? delete $packed->{_dtd} : [] );

   return $orig->( $self, $packed );
};

# Private methods
sub _create_or_update {
   my ($self, $path, $element_obj, $overwrite, $condition) = @_;

   my $element = $element_obj->_resultset->source->name;

   $self->validate_params( $path, $element );

   if (        $self->_is_array ( $element )
       and not $self->_is_in_dtd( $element )) {
      push @{ $self->_dtd }, '<!ELEMENT '.$element.' (ARRAY)*>';
   }

   return $self->next::method( $path, $element_obj, $overwrite, $condition );
}

sub _dtd_parse {
   my ($self, $data) = @_;

   defined $self->_dtd->[ 0 ] and $self->_dtd_parse_reset; $data or return;

   while ($data =~ s{ ( <! [^<>]+ > ) }{}msx) {
      $1 and push @{ $self->_dtd }, $1;
   }

   for (@{ $self->_dtd }) {
      m{ \A <!ELEMENT \s+ (\S+) \s+ \(ARRAY\) }mx
         and $self->_arrays->{ $1 } = TRUE
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

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::XML - Read/write XML data storage model

=head1 Version

This document describes version v0.24.$Rev: 1 $

=head1 Synopsis

This is an abstract base class. See one of the subclasses for a
concrete example

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<extn>

The extension appended to filenames. Defaults to F<.xml>

=item C<meta_pack>

Adds the DTD to the meta data

=item C<meta_unpack>

Extracts the DTD from the meta data

=item C<root_name>

Defaults to C<config>. The name of the outer containing element

=back

=head1 Description

Implements the basic storage methods for reading and writing XML files

=head1 Subroutines/Methods

No public methods

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Storage>

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
