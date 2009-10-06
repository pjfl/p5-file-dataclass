# @(#)$Id: Schema.pm 685 2009-08-17 22:01:00Z pjf $

package File::DataClass::Schema;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev: 685 $ =~ /\d+/gmx );
use parent qw(File::DataClass::Base);

use File::DataClass::Combinator;
use MRO::Compat;
use Scalar::Util qw(weaken);

__PACKAGE__->config
   ( attributes    => [],
     defaults      => {},
     element       => q(unknown),
     storage_base  => q(File::DataClass::Storage) );

__PACKAGE__->mk_accessors( qw(attributes defaults element
                              label_attr lang_dep source storage
                              storage_base storage_class) );

sub new {
   my ($self, $app, $attrs) = @_;

   my $new = $self->next::method( $app, $attrs );

   weaken( $new->{source} );

   my $class = $new->storage_class || q(XML::Simple);

   if (q(+) eq substr $class, 0, 1) { $class = substr $class, 1 }
   else { $class = $new->storage_base.q(::).$class }

   $self->ensure_class_loaded( $class );
   $attrs = { %{ $attrs->{storage_attributes} || {} }, schema => $new };
   $new->storage( $class->new( $app, $attrs ) );

   if ($new->lang_dep) {
      $attrs = { storage => $new->storage };
      $new->storage( File::DataClass::Combinator->new( $app, $attrs ) );
   }

   return $new;
}

1;

__END__

=pod

=head1 Name

File::DataClass::Schema - Base class for schema definitions

=head1 Version

0.4.$Revision: 685 $

=head1 Synopsis

   package File::DataClass::ResultSource;

   use parent qw(File::DataClass::Base);
   use File::DataClass::Schema;
   use MRO::Compat;
   use Scalar::Util qw(weaken);

   __PACKAGE__->config( schema_class => q(File::DataClass::Schema) );

   __PACKAGE__->mk_accessors( qw(schema schema_class) );

   sub new {
      my ($self, $app, $attrs)  = @_;

      my $new = $self->next::method( $app, $attrs );

      $attrs  = { %{ $attrs->{schema_attributes} || {} }, source => $new };

      $new->schema( $new->schema_class->new( $app, $attrs ) );

      weaken( $new->schema->{source} );
      return $new;
   }

=head1 Description

This is the base class for schema definitions. Each element in a data file
requires a schema definition to define it's attributes that should
inherit from this

=head1 Subroutines/Methods

=head2 new

Creates a new instance of the storage class which defaults to
L<File::DataClass::Storage::XML::Simple>

If the schema is language dependent then an instance of
L<File::DataClass::Combinator> is created as a proxy for the
storage class

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Base>

=item L<File::DataClass::Combinator>

=item L<File::DataClass::Storage>

=item L<Scalar::Util>

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
