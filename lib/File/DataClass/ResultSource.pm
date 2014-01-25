package File::DataClass::ResultSource;

use namespace::sweep;

use Moo;
use File::DataClass::Constants;
use File::DataClass::ResultSet;
use File::DataClass::Types qw( ArrayRef ClassName HashRef
                               Object SimpleStr Str );

has 'attributes'           => is => 'ro', isa => ArrayRef[Str],
   default                 => sub { [] };

has 'defaults'             => is => 'ro', isa => HashRef,
   default                 => sub { {} };

has 'name'                 => is => 'ro', isa => SimpleStr,
   default                 => NUL;

has 'label_attr'           => is => 'ro', isa => SimpleStr,
   default                 => NUL;

has 'resultset_attributes' => is => 'ro', isa => HashRef,
   default                 => sub { {} };

has 'resultset_class'      => is => 'ro', isa => ClassName,
   default                 => 'File::DataClass::ResultSet';

has 'schema'               => is => 'ro', isa => Object,
   handles                 => [ qw( path storage ) ],
   required                => TRUE, weak_ref => TRUE,


has '_attributes' => is => 'lazy', isa => HashRef, init_arg => undef;

sub columns {
   return @{ $_[ 0 ]->attributes };
}

sub has_column {
   my $key = $_[ 1 ] || '_invalid_key_';

   return exists $_[ 0 ]->_attributes->{ $key } ? TRUE : FALSE;
}

sub resultset {
   my $self = shift;

   my $attrs = { %{ $self->resultset_attributes }, source => $self };

   return $self->resultset_class->new( $attrs );
}

# Private methods
sub _build__attributes {
   my $self = shift; my $attr = {};

   $attr->{ $_ } = TRUE for (@{ $self->attributes });

   return $attr;
}

1;

__END__

=pod

=head1 Name

File::DataClass::ResultSource - A source of result sets for a given schema

=head1 Synopsis

   use File::DataClass::Schema;

   $schema = File::DataClass::Schema->new
      ( path    => [ qw(path to a file) ],
        result_source_attributes => { source_name => {}, },
        tempdir => [ qw(path to a directory) ] );

   $schema->source( q(source_name) )->attributes( [ qw(list of attr names) ] );
   $rs = $schema->resultset( q(source_name) );
   $result = $rs->find( { name => q(id of field element to find) } );
   $result->$attr_name( $some_new_value );
   $result->update;
   @result = $rs->search( { 'attr name' => q(some value) } );

=head1 Description

Provides new result sources for a given schema

This is the base class for schema definitions. Each element in a data file
requires a schema definition to define it's attributes that should
inherit from this

=head1 Configuration and Environment

Defines the following attributes

=over 3

=item B<attributes>

Array ref of attributes defined in this result source

=item B<defaults>

=item B<name>

=item B<label_attr>

=item B<resultset_attributes>

=item B<resultset_class>

=item B<schema>

=item B<storage>

=back

=head1 Subroutines/Methods

=head2 columns

   @attributes = $self->columns;

Returns a list of attributes

=head2 has_column

   $bool = $self->has_column( $attribute_name );

Predicate return true if the attribute exists, false otherwise

=head2 resultset

   $rs = $self->resultset;

Creates and returns a new L<File::DataClass::ResultSet> object

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::ResultSet>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
