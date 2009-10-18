# @(#)$Id$

package File::DataClass::ResultSource;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;

use File::DataClass::ResultSet;
use File::DataClass::Schema;

with qw(File::DataClass::Util);

has 'resultset_attributes' =>
   is => 'ro', isa => 'HashRef',   default => sub { return {} };
has 'resultset_class' =>
   is => 'ro', isa => 'ClassName', default => q(File::DataClass::ResultSet);

has 'schema_attributes' =>
   is => 'ro', isa => 'HashRef',   default => sub { return {} };
has 'schema_class' =>
   is => 'ro', isa => 'ClassName', default => q(File::DataClass::Schema);
has 'schema' =>
   is => 'ro', isa => 'Object',    lazy_build => 1, init_arg => undef;

sub _build_schema {
   my $self = shift;

   my $attrs = { %{ $self->schema_attributes }, source => $self };

   return $self->schema_class->new( $attrs );
}

sub resultset {
   my ($self, $path) = @_;

   $path = $self->io( $path ) if ($path and not blessed $path);

   my $attrs = { %{ $self->resultset_attributes },
                 path => $path, schema => $self->schema };

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

   $result_source = File::DataClass->new( $attrs );

   $result_source->resultset( $file );

=head1 Description

Provides new result sets for a given schema. Ideas robbed from
L<DBIx::Class>

=head1 Subroutines/Methods

=head2 new

Constructor's arguments are the application object and a hash ref of
schema attributes. Creates a new instance of the schema class
which defaults to L<File::DataClass::Schema>

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
