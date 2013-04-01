# @(#)$Id$

package File::MealMaster::Storage;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use Template;
use Template::Stash;
use English qw( -no_match_vars );
use File::DataClass::Constants;
use File::DataClass::Functions qw(throw);

extends qw(File::DataClass::Storage);

my $DATA = do { local $RS = undef; <DATA> };

has '+extn'          => default => q(.mmf);
has 'template'       => is => 'ro', isa => 'Object', lazy    => TRUE,
   builder           => '_build_template';
has 'write_template' => is => 'ro', isa => 'Str',    default => $DATA;

augment '_read_file' => sub {
   my ($self, $rdr) = @_;

   $self->encoding and $rdr->encoding( $self->encoding );

   return $rdr->all;
};

around '_read_file' => sub {
   my ($orig, $self, @args) = @_;

   my ($data, $mtime) = $self->$orig( @args ); my $order = 0; my $recipes = {};

   for my $recipe (MealMasterMashup->new()->parse( $data )) {
      $recipe->{ _order_by } = $order++;
      $recipes->{ $self->make_key( $recipe->title ) } = $recipe;
   }

   return ({ $self->schema->source_name => $recipes }, $mtime);
};

augment '_write_file' => sub {
   my ($self, $wtr, $data) = @_;

   $self->encoding and $wtr->encoding( $self->encoding );

   return $self->_write_filter( $wtr, $data );
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

sub _write_filter {
   my ($self, $wtr, $data) = @_; $data ||= {};

   my $recipes       = $data->{ $self->schema->source_name } || {};
   my $template_data = $self->write_template;
   my $output        = NUL;

   for (sort { __original_order( $recipes, $a, $b ) } keys %{ $recipes }) {
      my $buffer = NUL;

      $self->template->process( \$template_data, $recipes->{ $_ }, \$buffer )
         or throw $self->template->error;
      $output .= $buffer;
   }

   $wtr->println( $output );
   return $data;
}

# Private methods

sub _build_template {
   my $self = shift;
   my $args = { INTERPOLATE => FALSE, COMPILE_DIR => $self->schema->tempdir };
   my $new  = Template->new( $args ) or throw Template->error;

   $Template::Stash::SCALAR_OPS->{sprintf} = sub {
      my ($val, $format) = @_; return sprintf $format, $val;
   };

   return $new;
}

# Private subroutines

sub __original_order {
   my ($hash, $lhs, $rhs) = @_;

   # New elements will be  added at the end
   exists $hash->{ $lhs }->{_order_by} or return  1;
   exists $hash->{ $rhs }->{_order_by} or return -1;
   return $hash->{ $lhs }->{_order_by} <=> $hash->{ $rhs }->{_order_by};
}

__PACKAGE__->meta->make_immutable;

no Moose;

package # Hide from indexer
   MealMasterMashup;

use parent q(MealMaster);

sub parse {
   # Copyright (C) 2005, Leon Brocard
   # Needed a version that takes scalar data
   # Also patched to handle whitespace better
   my ($self, $data) = @_;

   $data and $data =~ /^(MMMMM|-----).+Meal-Master/ or return;

   my @parts = split /^(?:MMMMM|-----).+Meal-Master.+$/m, $data;
   my @recipes;

   foreach my $part (@parts) {
      $part =~ s/^\s+//;
      my $recipe = MealMaster::Recipe->new;
      my $lines  = [ split /\n/, $part ];

      my $line;

      while (1) {
         $line = $self->_newline($lines);
         last unless defined $line;
         last if $line =~ /Title:/;
      }
      next unless defined $line;

      my ($title) = $line =~ /Title: (.+)$/;
      next unless $title;
      $title =~ s/^ +//;
      $title =~ s/ +$//;
      $recipe->title($title);

      $line = $self->_newline($lines);
      my ($categories) = $line =~ /Categories: (.+)$/;

      my @categories;
      @categories = split ', ', $categories if $categories;
      $recipe->categories(\@categories);

      $line = $self->_newline($lines);
      my ($yield) = $line =~ /(?:Yield|Servings): +(.+)$/;
      next unless $yield;
      $recipe->yield($yield);

      my $dflag = 0;
      my $ingredients;
      my $directions;

      while (defined($line = $self->_newline($lines))) {
         next unless $line;

         last if (!defined $line);
         next if (($dflag == 0) && ($line =~ m|^\s*$|));

         if ($line =~ /^[M-]+$/) {
            last;
         } elsif ($line =~ m(^[M|-]{4,})) {
            $line =~ s|^MMMMM||;
            $line =~ s|^\-+||;
            $line =~ s|\-+$||;
            $line =~ s|^ +||;
            $line =~ s|:$||;
            $directions .= "$line\n";
         } elsif ($line =~ m/^ *([A-Z ]+):$/) {
            $line =~ s|^\s+||;
            $directions .= "$line\n";
         } elsif (length($line) > 12
                  && (substr($line, 0, 7) =~ m|^[ 0-9\.\/]+$|)
                  && (substr($line, 7, 4) =~ m|^ .. $|))
         {
            $ingredients .= "$line\n";
         } else {
            if ($line) {
               $line =~ s|^\s+||;
               $directions .= "$line\n";
               $dflag = 1;
            }
         }
      }

      $ingredients = $self->_parse_ingredients($ingredients);

      $recipe->ingredients($ingredients);
      $recipe->directions($directions);

      push @recipes, $recipe;
   }
   return @recipes;
}

package File::MealMaster::Storage;

1;

=pod

=head1 Name

File::MealMaster::Storage - MealMaster food recipe file storage

=head1 Version

0.15.$Revision$

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

__DATA__
MMMMM----- Recipe via Meal-Master (tm) v8.05
 
      Title: [% title %]
 Categories: [% categories.join(', ') %]
      Yield: [% yield %]
 
[% FOREACH ingredient IN ingredients -%]
[% ingredient.quantity.sprintf('%7.7s') -%]
 [% ingredient.measure.sprintf('%-2.2s') -%]
 [% ingredient.product.sprintf('%-.29s') %]
[% END -%]
 
  [% directions.split('\n').join("\n  ") %]
 
MMMMM
 
