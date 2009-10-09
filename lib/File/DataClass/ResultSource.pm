# @(#)$Id: ResultSource.pm 683 2009-08-13 20:58:18Z pjf $

package File::DataClass::ResultSource;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev: 683 $ =~ /\d+/gmx );

use File::DataClass::ResultSet;
use File::DataClass::Schema;
use Moose;

with qw(File::DataClass::Util);

has 'resultset_attributes' =>
   ( is => q(ro), isa => q(HashRef), default => sub { return {} } );
has 'resultset_class' =>
   ( is => q(ro), isa => q(ClassName),
     default => q(File::DataClass::ResultSet) );
has 'schema' =>
   ( is => q(ro), isa => q(Object), lazy_build => 1, init_arg => undef );
has 'schema_attributes' =>
   ( is => q(ro), isa => q(HashRef), default => sub { return {} } );
has 'schema_class' =>
   ( is => q(ro), isa => q(ClassName), default => q(File::DataClass::Schema) );

sub _build_schema {
   my $self = shift; my $class = $self->schema_class;

   return $class->new( { %{ $self->schema_attributes }, source => $self } );
}

sub resultset {
   my ($self, $path, $lang) = @_;

   $path = $self->io( $path ) if ($path and not blessed $path);

   $self->storage->lang( $lang ) if ($lang and $self->storage->can( q(lang) ));

   my $attrs = { %{ $self->resultset_attributes },
                 path => $path, source => $self };

   return $self->resultset_class->new( $attrs );
}

sub storage {
   return shift->schema->storage;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::ResultSource - A source of result sets for a given schema

=head1 Version

0.4.$Revision: 683 $

=head1 Synopsis

   use File:DataClass;

   $attrs = { result_source_attributes => { schema_attributes => { ... } } };

   $result_source = File::DataClass->new( $attrs );

   $result_source->resultset( $file, $lang );

=head1 Description

Provides new result sets for a given schema. Ideas robbed from
L<DBIx::Class>

=head1 Subroutines/Methods

=head2 new

Constructor's arguments are the application object and a hash ref of
schema attributes. Creates a new instance of the schema class
which defaults to L<File::DataClass::Schema>

=head2 resultset

Sets the schema's I<file> and I<lang> attributes from the optional
parameters. Creates and returns a new
L<File::DataClass::Resultset> object

=head2 storage

Returns the storage handle for the current schema

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
