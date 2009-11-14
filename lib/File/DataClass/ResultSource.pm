# @(#)$Id$

package File::DataClass::ResultSource;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;

use File::DataClass::ResultSet;

with qw(File::DataClass::Util);

has 'attributes'           => is => 'rw', isa => 'ArrayRef[Str]',
   default                 => sub { return [] };
has 'defaults'             => is => 'rw', isa => 'HashRef',
   default                 => sub { return {} };
has 'name'                 => is => 'rw', isa => 'Str',
   default                 => NUL;
has 'label_attr'           => is => 'rw', isa => 'Str',
   default                 => NUL;
has 'resultset_attributes' => is => 'ro', isa => 'HashRef',
   default                 => sub { return {} };
has 'resultset_class'      => is => 'ro', isa => 'ClassName',
   default                 => q(File::DataClass::ResultSet);
has 'schema'               => is => 'ro', isa => 'Object',
   required                => TRUE, weak_ref => TRUE;

sub resultset {
   my $self = shift;

   my $attrs = { %{ $self->resultset_attributes }, source => $self };

   return $self->resultset_class->new( $attrs );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::ResultSource - A source of result sets for a given schema

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File:DataClass;

   $attrs = { result_source_attributes => { schema_attributes => { ... } } };

   $result_source = File::DataClass->new( $attrs )->result_source;

   $rs = $result_source->resultset( { path => q(path_to_data_file) } );

=head1 Description

Provides new result sources for a given schema

If the result source is language dependent then an instance of
L<File::DataClass::Combinator> is created as a proxy for the
storage class

=head1 Subroutines/Methods

=head2 dump

Moose bug. Cannot delegate a method called dump so we have to do it instead

=head2 resultset

Sets the resultset's I<path> attribute from the optional
parameters. Creates and returns a new
L<File::DataClass::Resultset> object

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass>

=item L<File::DataClass::Schema>

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
