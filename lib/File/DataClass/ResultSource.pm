# @(#)$Id: ResultSource.pm 683 2009-08-13 20:58:18Z pjf $

package File::DataClass::ResultSource;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev: 683 $ =~ /\d+/gmx );
use parent qw(File::DataClass::Base);

use File::DataClass::ResultSet;
use File::DataClass::Schema;
use MRO::Compat;

__PACKAGE__->config
   ( resultset_attributes => {},
     resultset_class      => q(File::DataClass::ResultSet),
     schema_class         => q(File::DataClass::Schema) );

__PACKAGE__->mk_accessors( qw(resultset_attributes resultset_class
                              schema schema_class) );

sub new {
   my ($self, $app, $attrs) = @_;

   my $new = $self->next::method( $app, $attrs );

   $attrs  = { %{ $attrs->{schema_attributes} || {} }, source => $new };
   $new->schema( $new->schema_class->new( $app, $attrs ) );

   return $new;
}

sub resultset {
   my ($self, $path, $lang) = @_;

   $self->storage->path( $path ) if ($path);
   $self->storage->lang( $lang ) if ($lang and $self->storage->can( q(lang) ));

   return $self->resultset_class->new( $self, $self->resultset_attributes );
}

sub storage {
   return shift->schema->storage;
}

1;

__END__

=pod

=head1 Name

File::DataClass::ResultSource - A source of result sets for a given schema

=head1 Version

0.4.$Revision: 683 $

=head1 Synopsis

   use File:DataClass;

   $attrs = { schema_attributes => { ... } };

   $result_source = File::DataClass->new( $app, $attrs );

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
