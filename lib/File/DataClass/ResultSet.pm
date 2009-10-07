# @(#)$Id: ResultSet.pm 674 2009-08-09 00:49:16Z pjf $

package File::DataClass::ResultSet;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev: 674 $ =~ /\d+/gmx );

use File::DataClass::Element;
use File::DataClass::List;
use File::DataClass::Constants;
use Moose;

extends qw(File::DataClass::Base);

has 'element_class' =>
   ( is => q(ro), isa => q(ClassName),
     default => q(File::DataClass::Element) );

has 'list_class' =>
   ( is => q(ro), isa => q(ClassName), default => q(File::DataClass::List) );

has 'source' =>
   ( is => q(ro), isa => q(Object), weak_ref => TRUE );

has '_elements' =>
   ( is => q(rw), isa => q(ArrayRef),
     default => sub { return [] }, init_arg => undef );

has '_iterator' =>
   ( is => q(rw), isa => q(Int), default => 0, init_arg => undef );

sub all {
   my $self = shift; return @{ $self->_elements };
}

sub create {
   my ($self, $attrs) = @_; my $class = $self->element_class;

   $attrs = { %{ $self->schema->defaults },
              %{ $attrs || {} }, resultset => $self };

   return $class->new( $attrs );
}

sub find {
   my ($self, $name) = @_; my $elements = $self->storage->select;

   return unless ($name && exists $elements->{ $name });

   my $class = $self->element_class; my $attrs = $elements->{ $name };

   $attrs->{name} = $name; $attrs->{resultset} = $self;

   return $class->new( $attrs );
}

sub find_and_update {
   my ($self, $name, $attrs) = @_; my $schema = $self->schema; my $element;

   if ($element = $self->find( $name )) {
      for my $attr (grep { exists $attrs->{ $_ } } @{ $schema->attributes }) {
         $element->$attr( $attrs->{ $attr } );
      }

      return $element->update;
   }

   return;
}

sub first {
   my $self = shift; return $self->_elements ? $self->_elements->[0] : undef;
}

sub list {
   my ($self, $name) = @_; my $attr;

   my $class    = $self->list_class;
   my $new      = $class->new;
   my $attrs    = { name => $name };
   my $elements = $self->storage->select;

   $new->list( [ sort keys %{ $elements } ] );

   if ($attr = $self->schema->label_attr) {
      $new->labels( { map { $_ => $elements->{ $_ }->{ $attr } }
                      @{ $new->list } } );
   }

   if ($name && exists $elements->{ $name }) {
      $attrs = $elements->{ $name };
      $attrs->{name} = $name; $attrs->{resultset} = $self;
      $class = $self->element_class;
      $new->element( $class->new( $attrs ) );
      $new->found( TRUE );
   }
   else { $new->element( $self->create( $attrs ) ) }

   return $new;
}

sub last {
   my $self = shift; return $self->_elements ? $self->_elements->[-1] : undef;
}

sub next {
   my $self  = shift;

   my $index = $self->_iterator || 0; $self->_iterator( $index + 1 );

   return $self->_elements ? $self->_elements->[ $index ] : undef;
}

sub push_attribute {
   my ($self, $name, $attr, $items) = @_;

   my $elements = $self->storage->select;
   my $attrs    = { %{ $elements->{ $name } } };
   my $list     = [ @{ $attrs->{ $attr } || [] } ];
   my $in       = [];

   for my $item (@{ $items }) {
      unless ($self->is_member( $item, @{ $list } )) {
         push @{ $list }, $item; push @{ $in }, $item;
      }
   }

   $attrs->{ $attr } = $list;
   return ($attrs, $in);
}

sub schema {
   return shift->source->schema;
}

sub search {
   my ($self, $criterion) = @_; my @tmp;

   unless ($self->_elements) {
      $self->_elements( [] ); $self->_iterator( 0 );
   }

   my $elements = $self->_elements;

   if (not defined $elements->[0]) {
      my $class = $self->element_class; $elements = $self->storage->select;

      for my $name (keys %{ $elements }) {
         my $attrs = $elements->{ $name };

         $attrs->{name} = $name; $attrs->{resultset} = $self;

         if (not $criterion or $self->_eval_criterion( $criterion, $attrs )) {
            push @{ $self->_elements }, $class->new( $attrs );
         }
      }
   }
   elsif ($criterion and defined $elements->[0]) {
      for my $attrs (@{ $elements }) {
         push @tmp, $attrs if ($self->_eval_criterion( $criterion, $attrs ));
      }

      $self->_elements( \@tmp );
   }

   return wantarray ? $self->all : $self;
}

sub splice_attribute {
   my ($self, $name, $attr, $items) = @_;

   my $elements = $self->storage->select || {};
   my $attrs    = { %{ $elements->{ $name } } };
   my $list     = [ @{ $attrs->{ $attr } || [] } ];
   my $out      = [];

   for my $item (@{ $items }) {
      last unless (defined $list->[0]);

      for (0 .. $#{ $list }) {
         if ($list->[ $_ ] eq $item) {
            splice @{ $list }, $_, 1; push @{ $out }, $item;
            last;
         }
      }
   }

   $attrs->{ $attr } = $list;
   return ($attrs, $out);
}

sub storage {
   return shift->schema->storage;
}

# Private methods

sub _eval_criterion {
   my ($self, $criterion, $attrs) = @_; my $lhs;

   for my $attr (keys %{ $criterion }) {
      return FALSE unless (exists  $attrs->{ $attr });
      return FALSE unless (defined ($lhs = $attrs->{ $attr }));

      if (ref $criterion->{ $attr } eq HASH) {
         while (my ($op, $rhs) = each %{ $criterion->{ $attr } }) {
            return FALSE unless ($self->_eval_op( $lhs, $op, $rhs ));
         }
      }
      else {
         if (ref $lhs eq ARRAY) {
            unless ($self->is_member( $criterion->{ $attr }, @{ $lhs })) {
               return FALSE;
            }
         }
         else { return FALSE unless ($lhs eq $criterion->{ $attr }) }
      }
   }

   return TRUE;
}

sub _eval_op {
   my ($self, $lhs, $op, $rhs) = @_;

   my $subr = $self->_operators->{ $op };

   return $subr ? $subr->( $lhs, $rhs ) : undef;
}

sub _operators {
   return { q(eq) => sub { return $_[0] eq $_[1] },
            q(==) => sub { return $_[0] == $_[1] },
            q(ne) => sub { return $_[0] ne $_[1] },
            q(!=) => sub { return $_[0] != $_[1] },
            q(>)  => sub { return $_[0] >  $_[1] },
            q(>=) => sub { return $_[0] >= $_[1] },
            q(<)  => sub { return $_[0] <  $_[1] },
            q(<=) => sub { return $_[0] <= $_[1] }, };
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::ResultSet - Core element methods

=head1 Version

0.4.$Revision: 674 $

=head1 Synopsis

   my $attrs  = { schema_attributes => $schema_attributes };
   my $source = File::DataClass::ResultSource->new( $attrs ) );
   my $rs     = $source->resultset( $path, $lang );
   my $result = $rs->search( $criterion );

   for $element_obj ($result->next) {
      # Do something with the element object
   }

=head1 Description

Find, search and update methods for element objects

=head1 Subroutines/Methods

=head2 new

Constructor returns a result set object

=head2 all

   @elements = $rs->search()->all;

Returns all the elements that are returned by the L</search> call

=head2 create

   $element_obj = $rs->create( $attrs );

Creates and returns a new L<element|File::DataClass::Element>
object from the attributes provided

=head2 find

   $element_obj = $rs->find( $name );

Finds the named element and returns an
L<element|File::DataClass::Element> object for it

=head2 find_and_update

   $element_obj = $rs->find_and_update( $name, $attrs );

Finds the named element object and updates it's attributes

=head2 first

   $element_obj = $rs->search( $criterion )->first;

Returns the first element object that is the result of the search call

=head2 list

   $list = $rs->list( $name );

Returns a L<list|File::DataClass::List> object

=head2 last

   $element_obj = $rs->search( $criterion )->last;

Returns the last element object that is the result of the search call

=head2 next

   $element_obj = $rs->search( $criterion )->next;

Iterate over the elements returned by the search call

=head2 push_attribute

   ($attrs, $added) = $rs->push_attribute( $name, $list, $items );

Adds items to the attribute list

=head2 schema

   $schema = $rs->schema;

Returns the source schema object

=head2 search

   $result = $rs->search( $criterion );

Search for elements that match the given criterion. The criterion is a hash
ref whose keys are element attribute names. The criterion values are either
scalar values or hash refs. The scalar values are tested for equality with
the corresponding element attribute values. Hash ref keys are treated as
comparison operators, the hash ref values are compared with the element
attribute values, e.g.

   $criterion = { quick_links => { '>=' => 0 } };

=head2 splice_attribute

   ($attrs, $removed) = $rs->splice_attribute( $name, $list, $items );

Removes items from the attribute list

=head2 storage

Returns the schema storage object

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Base>

=item L<File::DataClass::Element>

=item L<File::DataClass::List>

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
