# @(#)$Id$

package File::DataClass::ResultSet;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;

use File::DataClass::Element;
use File::DataClass::List;

with qw(File::DataClass::Util);

has 'element_class' => is => 'ro', isa => 'ClassName',
   default          => q(File::DataClass::Element);
has 'list_class'    => is => 'ro', isa => 'ClassName',
   default          => q(File::DataClass::List);
has 'source'        => is => 'ro', isa => 'Object',
   required         => TRUE, weak_ref => TRUE;
has '_elements'     => is => 'rw', isa => 'ArrayRef',
   default          => sub { return [] }, init_arg => undef;
has '_iterator'     => is => 'rw', isa => 'Int',
   default          => 0, init_arg => undef;
has '_operators'    => is => 'ro', isa => 'HashRef',
   lazy_build       => TRUE;

sub all {
   my $self = shift; return @{ $self->_elements };
}

sub create {
   my ($self, $args) = @_;

   my $name    = $self->_get_element_name( $args );
   my $attrs   = { %{ $args->{fields} || {} }, name => $name };
   my $updated = $self->_txn_do( sub {
      $self->_create_element( $attrs )->insert;
   } );

   return $updated ? $name : undef;
}

sub delete {
   my ($self, $args) = @_; my $name = $self->_get_element_name( $args );

   $self->_txn_do( sub {
      my ($element, $error);

      unless ($element = $self->_find( $name )) {
         $error = 'File [_1] element [_2] does not exist';
         $self->throw( error => $error, args => [ $self->path, $name ] );
      }

      unless ($element->delete) {
         $error = 'File [_1] element [_2] not deleted';
         $self->throw( error => $error, args => [ $self->path, $name ] );
      }
   } );

   return $name;
}

sub find {
   my ($self, $args) = @_; my $name = $self->_get_element_name( $args );

   return $self->_txn_do( sub { $self->_find( $name ) } );
}

sub find_and_update {
   my ($self, $name, $attrs) = @_;

   my $element = $self->_find( $name ) or return;

   $self->update_attributes( $element, $attrs );

   return $element->update;
}

sub first {
   my $self = shift; return $self->_elements ? $self->_elements->[0] : undef;
}

sub last {
   my $self = shift; return $self->_elements ? $self->_elements->[-1] : undef;
}

sub list {
   my ($self, $args) = @_;

   return $self->_txn_do( sub { $self->_list( $args->{name} ) } );
}

sub path {
   return shift->source->schema->path;
}

sub next {
   my $self  = shift;

   my $index = $self->_iterator || 0; $self->_iterator( $index + 1 );

   return $self->_elements ? $self->_elements->[ $index ] : undef;
}

sub push {
   my ($self, $args) = @_; my ($added, $attrs, $list);

   my $name = $self->_get_element_name( $args );

   $list = $args->{list} or $self->throw( 'No list name specified' );

   my $items = $args->{items} || [];

   $items->[0] or $self->throw( 'List contains no items' );

   my $res = $self->_txn_do( sub {
      ($attrs, $added) = $self->_push( $name, $list, $items );
      $self->find_and_update( $name, $attrs );
   } );

   return $res ? $added : undef;
}

sub reset {
   my $self = shift; return $self->_iterator( 0 );
}

sub select {
   my $self = shift;

   return $self->storage->select( $self->path, $self->source->name );
}

sub search {
   my ($self, $args) = @_;

   return $self->_txn_do( sub { $self->_search( $args->{where} ) } );
}

sub splice {
   my ($self, $args) = @_; my ($attrs, $list, $removed);

   my $name = $self->_get_element_name( $args );

   $list = $args->{list} or $self->throw( 'No list name specified' );

   my $items = $args->{items} || [];

   $items->[0] or $self->throw( 'List contains no items' );

   my $res = $self->_txn_do( sub {
      ($attrs, $removed) = $self->_splice( $name, $list, $items );
      $self->find_and_update( $name, $attrs );
   } );

   return $res ? $removed : undef;
}

sub storage {
   return shift->source->schema->storage;
}

sub update {
   my ($self, $args) = @_; my $name = $self->_get_element_name( $args );

   my $res = $self->_txn_do( sub {
      $self->find_and_update( $name, $args->{fields} || {} );
   } );

   return $res ? $name : undef;
}

sub update_attributes {
   my ($self, $element, $attrs) = @_;

   for my $attr (grep { exists $attrs->{ $_ } }
                 @{ $self->source->attributes }) {
      $element->$attr( $attrs->{ $attr } );
   }

   return;
}

# Private methods

sub _assert_clause {
   my ($self, $clause, $lhs) = @_;

   if (ref $clause eq HASH) {
      return ref $lhs eq ARRAY
           ? FALSE : $self->_eval_clause( $clause, $lhs );
   }

   if (ref $clause eq ARRAY) {
      return ref $lhs eq ARRAY
           ? FALSE : $self->is_member( $lhs, @{ $clause } );
   }

   return ref $lhs eq ARRAY
        ? $self->is_member( $clause, @{ $lhs } )
        : $clause eq $lhs ? TRUE : FALSE;
}

sub _build__operators {
   return {
      q(eq) => sub { return $_[0] eq $_[1] },
      q(==) => sub { return $_[0] == $_[1] },
      q(ne) => sub { return $_[0] ne $_[1] },
      q(!=) => sub { return $_[0] != $_[1] },
      q(>)  => sub { return $_[0] >  $_[1] },
      q(>=) => sub { return $_[0] >= $_[1] },
      q(<)  => sub { return $_[0] <  $_[1] },
      q(<=) => sub { return $_[0] <= $_[1] },
      q(=~) => sub { return $_[0] =~ $_[1] },
      q(!~) => sub { return $_[0] !~ $_[1] },
   };
}

sub _create_element {
   my ($self, $attrs) = @_;

   $attrs = { %{ $self->source->defaults }, %{ $attrs }, _resultset => $self };

   return $self->element_class->new( $attrs );
}

sub _eval_criteria {
   my ($self, $criteria, $attrs) = @_; my $lhs;

   for my $where_key (keys %{ $criteria }) {
      unless (defined ($lhs = $attrs->{ $where_key } )
              and $self->_assert_clause( $criteria->{ $where_key }, $lhs)) {
         return FALSE;
      }
   }

   return TRUE;
}

sub _eval_clause {
   my ($self, $clause, $lhs) = @_;

   for my $op (keys %{ $clause }) {
      my $subr = $self->_operators->{ $op } or return FALSE;

      $_ || return FALSE for (map { $subr->( $_, $clause->{ $op } ) }
                              ref $lhs eq ARRAY ? @{ $lhs } : ( $lhs ));
   }

   return TRUE;
}

sub _find {
   my ($self, $name) = @_; my $elements = $self->select;

   return unless ($name and exists $elements->{ $name });

   my $attrs = { %{ $elements->{ $name } }, name => $name };

   return $self->_create_element( $attrs );
}

sub _get_element_name {
   my ($self, $args) = @_; $args ||= {};

   my $name = $args->{name} or $self->throw( 'No element name specified' );

   return $name;
}

sub _list {
   my ($self, $name) = @_; my ($attr, $attrs);

   my $new = $self->list_class->new; my $elements = $self->select;

   $new->list( [ sort keys %{ $elements } ] );

   if ($attr = $self->source->label_attr) {
      my %labs = map { $_ => $elements->{ $_ }->{ $attr } } @{ $new->list };

      $new->labels( \%labs );
   }

   if ($name and exists $elements->{ $name }) {
      $attrs = { %{ $elements->{ $name } }, name => $name };
      $new->found( TRUE );
   }
   else { $attrs = { name => $name } }

   $new->element( $self->_create_element( $attrs ) );

   return $new;
}

sub _push {
   my ($self, $name, $attr, $items) = @_;

   my $attrs = { %{ $self->select->{ $name } || {} } };
   my $list  = [ @{ $attrs->{ $attr } || [] } ];
   my $in    = [];

   for my $item (grep { not $self->is_member( $_, @{ $list } ) } @{ $items }) {
      CORE::push @{ $list }, $item;
      CORE::push @{ $in   }, $item;
   }

   $attrs->{ $attr } = $list;
   return ($attrs, $in);
}

sub _search {
   my ($self, $where) = @_; my $elements = $self->_elements; my @tmp;

   unless ($self->_elements) {
      $self->_elements( [] ); $self->_iterator( 0 );
   }

   if (not defined $elements->[0]) {
      $elements = $self->select;

      for my $name (keys %{ $elements }) {
         my $attrs = { %{ $elements->{ $name } }, name => $name };

         if (not $where or $self->_eval_criteria( $where, $attrs )) {
            CORE::push @{ $self->_elements }, $self->_create_element( $attrs );
         }
      }
   }
   elsif ($where and defined $elements->[0]) {
      for my $attrs (@{ $elements }) {
         CORE::push @tmp, $attrs if ($self->_eval_criteria( $where, $attrs ));
      }

      $self->_elements( \@tmp );
   }

   return wantarray ? $self->all : $self;
}

sub _splice {
   my ($self, $name, $attr, $items) = @_;

   my $attrs = { %{ $self->select->{ $name } || {} } };
   my $list  = [ @{ $attrs->{ $attr } || [] } ];
   my $out   = [];

   for my $item (@{ $items }) {
      last unless (defined $list->[0]);

      for (0 .. $#{ $list }) {
         if ($list->[ $_ ] eq $item) {
            CORE::splice @{ $list }, $_, 1;
            CORE::push   @{ $out  }, $item;
            last;
         }
      }
   }

   $attrs->{ $attr } = $list;
   return ($attrs, $out);
}

sub _txn_do {
   my ($self, $coderef) = @_;

   return $self->storage->txn_do( $self->path, $coderef );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::ResultSet - Core element methods

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File:DataClass;

   $attrs = { result_source_attributes => { schema_attributes => { ... } } };

   $result_source = File::DataClass->new( $attrs )->result_source;

   $rs = $result_source->resultset( { path => q(path_to_data_file) } );

   $result = $rs->search( { where => $hash_ref_of_where_clauses } );

   for $element_object ($result->next) {
      # Do something with the element object
   }

=head1 Description

Find, search and update methods for element objects

=head1 Configuration and Environment

Constructor returns a result set object

=head1 Subroutines/Methods

=head2 all

   @elements = $rs->search()->all;

Returns all the elements that are returned by the L</search> call

=head2 create

   $new_element_name = $rs->create( $args );

Creates and inserts an new element. The C<$args> hash requires these
keys; I<name> of the element to create and I<fields> is a hash
containing the attributes of the new element. Missing attributes are
defaulted from the I<defaults> attribute of the
L<File::DataClass::Schema> object. Returns the new element's name

=head2 delete

   $rs->delete( { name => $of_element_to_delete } );

Deletes an element

=head2 find

   $element_object = $rs->find( { name => $of_element_to_find } );

Finds the named element and returns an
L<element|File::DataClass::Element> object for it

=head2 find_and_update

   $updated_element_name = $rs->_find_and_update( $name, $attrs );

Finds the named element object and updates it's attributes. Does not wrap
the find and update in a transaction

=head2 first

   $element_object = $rs->search( { where => $where_clauses } )->first;

Returns the first element object that is the result of the search call

=head2 list

   $list_obect = $rs->list( { name => $name } );

Returns a L<list|File::DataClass::List> object

Retrieves the named element and a list of elements

=head2 last

   $element_object = $rs->search( { where => $where } )->last;

Returns the last element object that is the result of the search call

=head2 next

   $element_object = $rs->search( { where => $where } )->next;

Iterate over the elements returned by the search call

=head2 path

   $path = $rs->path;

Attribute L<File::DataClass::Schema/path>

=head2 push

   $added = $rs->push( { name => $name, list => $list, items => $items } );

Adds items to the attribute list. The C<$args> hash requires these
keys; I<name> the element to edit, I<list> the attribute of the named
element containing the list of existing items, I<req> the request
object and I<items> the field on the request object containing the
list of new items

=head2 reset

   $rs->reset

Resets the resultset's cursor, so you can iterate through the elements again

=head2 search

   $result = $rs->search( { where => $hash_ref_of_where_clauses } );

Search for elements that match the given criterion. The criterion is a hash
ref whose keys are element attribute names. The criterion values are either
scalar values or hash refs. The scalar values are tested for equality with
the corresponding element attribute values. Hash ref keys are treated as
comparison operators, the hash ref values are compared with the element
attribute values, e.g.

   $where = { 'some_element_attribute_name' => { '>=' => 0 } };

=head2 select

   $hash = $rs->select;

Returns a hash ref of elements

=head2 splice

   $removed = $rs->splice( { name => $name, list => $list, items => $items } );

Removes items from the attribute list

=head2 storage

   $storage = $rs->storage;

Attribute L<File::DataClass::Schema/storage>

=head2 update

   $rs->update( { name => $of_element, fields => $attr_hash } );

Updates the named element

=head2 update_attributes

   $rs->update_attributes( $element, $attributes );

Updates an elements attributes

=head2 _txn_do

Calls L<File::DataClass::Storage/txn_do>

=head1 Diagnostics

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
