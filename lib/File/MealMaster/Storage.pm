# @(#)$Id$

package File::MealMaster::Storage;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Data::Section -setup;
use File::DataClass::Constants;
use MealMaster;
use Moose;
use Template;
use Template::Stash;

extends qw(File::DataClass::Storage);

has '+extn'          => default => q(.mmf);
has 'template'       => is => 'ro', isa => 'Object', lazy_build => TRUE;
has 'write_template' => is => 'ro', isa => 'Str',    lazy_build => TRUE;

augment '_read_file' => sub {
   my ($self, $rdr) = @_; return $self->_read_filter( $rdr );
};

augment '_write_file' => sub {
   my ($self, $wtr, $data) = @_; return $self->_write_filter( $wtr, $data );
};

sub make_key {
   my ($self, $title) = @_; my $key = $title || NUL;

   $key =~ s{ [^a-zA-Z0-9 ] }{}gmsx;
   $key =~ s{ \s+ }{ }gmsx;
   $key =~ s{ \A \s+ }{}msx;
   $key =~ s{ \s+ \z }{}msx;
   $key =  join q(_), map { ucfirst $_ } split SPC, lc $key;

   return $key;
}

# Private methods

sub _read_filter {
   my ($self, $path) = @_; my $recipes = {}; my $order = 0;

   for my $recipe (MealMaster->new()->parse( NUL.$path )) {
      $recipe->{ _order_by } = $order++;
      $recipes->{ $self->make_key( $recipe->title ) } = $recipe;
   }

   return { $self->schema->source_name => $recipes };
}

sub _write_filter {
   my ($self, $wtr, $data) = @_; $data ||= {};

   my $recipes       = $data->{ $self->schema->source_name } || {};
   my $template_data = $self->write_template;
   my $output        = NUL;

   for (sort { __original_order( $recipes, $a, $b ) } keys %{ $recipes }) {
      my $buffer = NUL;

      $self->template->process( \$template_data, $recipes->{ $_ }, \$buffer )
         or $self->throw( $self->template->error );
      $output .= $buffer;
   }

   $wtr->println( $output );
   return $data;
}

# Private methods

sub _build_template {
   my $self = shift;
   my $args = { INTERPOLATE => FALSE, COMPILE_DIR => $self->schema->tempdir };
   my $new  = Template->new( $args ) or $self->throw( Template->error );

   $Template::Stash::SCALAR_OPS->{sprintf} = sub {
      my ($val, $format) = @_; return sprintf $format, $val;
   };

   return $new;
}

sub _build_write_template {
   return ${ __PACKAGE__->section_data( q(write_template) ) };
}

# Private subroutines

sub __original_order {
   my ($hash, $lhs, $rhs) = @_;

   # New elements will be  added at the end
   return  1 unless (exists $hash->{ $lhs }->{_order_by});
   return -1 unless (exists $hash->{ $rhs }->{_order_by});

   return $hash->{ $lhs }->{_order_by} <=> $hash->{ $rhs }->{_order_by};
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

=pod

=head1 Name

File::MealMaster::Storage - MealMaster food recipe file storage

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::MealMaster::Storage;

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 make_key

=head1 Diagnostics

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

__DATA__
__[ write_template ]__
MMMMM----- Recipe via Meal-Master (tm) v8.05

      Title: [% title %]
 Categories: [% categories.sort.join(', ') %]
      Yield: [% yield %]

[% FOREACH ingredient IN ingredients -%]
[% ingredient.quantity.sprintf('%7.7s') -%]
 [% ingredient.measure.sprintf('%-2.2s') -%]
 [% ingredient.product.sprintf('%-29.29s') %]
[% END -%]

[% directions %]

MMMMM
