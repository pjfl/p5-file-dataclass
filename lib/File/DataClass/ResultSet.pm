package File::DataClass::ResultSet;

use namespace::sweep;

use Moo;
use File::DataClass::Constants;
use File::DataClass::Functions qw( is_arrayref is_hashref is_member throw );
use File::DataClass::List;
use File::DataClass::Result;
use File::DataClass::Types     qw( ArrayRef ClassName HashRef Int Object );
use Scalar::Util               qw( blessed );
use Unexpected::Functions      qw( RecordNotFound Unspecified );

has 'list_class'   => is => 'ro',   isa => ClassName,
   default         => 'File::DataClass::List';

has 'result_class' => is => 'ro',   isa => ClassName,
   default         => 'File::DataClass::Result';

has 'source'       => is => 'ro',   isa => Object,
   handles         => [ qw( attributes defaults label_attr path storage ) ],
   required        => TRUE, weak_ref => TRUE;


has '_iterator'    => is => 'rw',   isa => Int, default => 0, init_arg => undef;

has '_operators'   => is => 'lazy', isa => HashRef;

has '_results'     => is => 'rw',   isa => ArrayRef,
   default         => sub { [] }, init_arg => undef;

sub all {
   my $self = shift; return @{ $self->_results };
}

sub create {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $res = $self->_txn_do( sub { $self->_create_result( $args )->insert } );

   return $res ? $name : undef;
}

sub create_or_update {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $res = $self->_txn_do( sub {
      my $result = $self->_find( $name )
         or return $self->_create_result( $args )->insert;

      return $self->_update_result( $result, $args );
   } );

   return $res ? $name : undef;
}

sub delete {
   my ($self, $args) = @_; my $optional = $args->{optional};

   my $name = $self->_validate_params( $args ); my $path = $self->path;

   my $res = $self->_txn_do( sub {
      my $result; unless ($result = $self->_find( $name )) {
         $optional and return FALSE;
         throw class => RecordNotFound, args => [ $path, $name ];
      }

      $result->delete or throw error => 'File [_1] element [_2] not deleted',
                               args  => [ $path, $name ];
      return TRUE;
   } );

   return $res ? $name : undef;
}

sub find {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   return $self->_txn_do( sub { $self->_find( $name ) } );
}

sub first {
   my $self = shift; return $self->_results->[ 0 ];
}

sub last {
   my $self = shift; return $self->_results->[ -1 ];
}

sub list {
   my ($self, $args) = @_;

   return $self->_txn_do( sub { $self->_list( $args->{name} ) } );
}

sub next {
   my $self  = shift;
   my $index = $self->_iterator; $self->_iterator( $index + 1 );

   return $self->_results->[ $index ];
}

sub push {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $list  = $args->{list} or throw class => Unspecified, args => [ 'list' ];
   my $items = $args->{items} || []; my ($added, $attrs);

   $items->[ 0 ] or throw 'List contains no items';

   my $res = $self->_txn_do( sub {
      ($attrs, $added) = $self->_push( $name, $list, $items );
      $self->_find_and_update( $attrs );
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

   return $self->_txn_do( sub { $self->_search( $args ) } );
}

sub splice {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $list  = $args->{list} or throw class => Unspecified, args => [ 'list' ];
   my $items = $args->{items} || []; my ($attrs, $removed);

   $items->[ 0 ] or throw 'List contains no items';

   my $res = $self->_txn_do( sub {
      ($attrs, $removed) = $self->_splice( $name, $list, $items );
      $self->_find_and_update( $attrs );
   } );

   return $res ? $removed : undef;
}

sub update {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $res = $self->_txn_do( sub { $self->_find_and_update( $args ) } );

   return $res ? $name : undef;
}

# Private methods
sub _build__operators {
   return {
      q(eq) => sub { return $_[ 0 ] eq $_[ 1 ] },
      q(==) => sub { return $_[ 0 ] == $_[ 1 ] },
      q(ne) => sub { return $_[ 0 ] ne $_[ 1 ] },
      q(!=) => sub { return $_[ 0 ] != $_[ 1 ] },
      q(>)  => sub { return $_[ 0 ] >  $_[ 1 ] },
      q(>=) => sub { return $_[ 0 ] >= $_[ 1 ] },
      q(<)  => sub { return $_[ 0 ] <  $_[ 1 ] },
      q(<=) => sub { return $_[ 0 ] <= $_[ 1 ] },
      q(=~) => sub { my $re = $_[ 1 ]; return $_[ 0 ] =~ qr{ $re }mx },
      q(!~) => sub { my $re = $_[ 1 ]; return $_[ 0 ] !~ qr{ $re }mx },
   };
}

sub _create_result {
   my ($self, $args) = @_;

   my $attrs = { %{ $self->defaults }, _resultset => $self };

   for (grep { exists $args->{ $_ } and defined $args->{ $_ } }
            @{ $self->attributes }, 'name') {
      $attrs->{ $_ } = $args->{ $_ };
   }

   return $self->result_class->new( $attrs );
}

sub _eval_clause {
   my ($self, $clause, $lhs) = @_;

   if (is_hashref $clause) {
      for (keys %{ $clause }) {
         $self->_eval_op( $lhs, $_, $clause->{ $_ } ) or return FALSE;
      }

      return TRUE;
   }
   elsif (is_arrayref $clause) { # TODO: Handle case of 2 arrays
      return (is_arrayref $lhs) ? FALSE : (is_member $lhs, $clause);
   }

   return (is_arrayref $lhs) ? ((is_member $clause, $lhs) ? TRUE : FALSE)
                             : ($clause eq $lhs           ? TRUE : FALSE);
}

sub _eval_criteria {
   my ($self, $criteria, $attrs) = @_; my $lhs;

   for (keys %{ $criteria }) {
      defined ($lhs = $attrs->{ $_ }) or return FALSE;
      $self->_eval_clause( $criteria->{ $_ }, $lhs ) or return FALSE;
   }

   return TRUE;
}

sub _eval_op {
   my ($self, $lhs, $op, $rhs) = @_;

   my $subr = $self->_operators->{ $op } or return FALSE;

   $_ or return FALSE for (map { $subr->( $_, $rhs ) ? 1 : 0 }
                           (is_arrayref $lhs) ? @{ $lhs } : ( $lhs ));

   return TRUE;
}

sub _find {
   my ($self, $name) = @_; my $results = $self->select;

   ($name and exists $results->{ $name }) or return;

   my $attrs = { %{ $results->{ $name } }, name => $name };

   return $self->_create_result( $attrs );
}

sub _find_and_update {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $result = $self->_find( $name )
      or throw class => RecordNotFound, args => [ $self->path, $name ];

   return $self->_update_result( $result, $args );
}

sub _list {
   my ($self, $name) = @_; my ($attr, $attrs, $labels); my $found = FALSE;

   my $results = $self->select; my $list = [ sort keys %{ $results } ];

   $attr = $self->label_attr
      and $labels = { map { $_ => $results->{ $_ }->{ $attr } } @{ $list } };

   if ($name and exists $results->{ $name }) {
      $attrs = { %{ $results->{ $name } }, name => $name }; $found = TRUE;
   }
   else { $attrs = { name => $name } }

   my $result = $self->_create_result( $attrs );

   $attrs = { found => $found, list => $list, result => $result, };
   $labels and $attrs->{labels} = $labels;
   return $self->list_class->new( $attrs );
}

sub _push {
   my ($self, $name, $attr, $items) = @_;

   my $attrs = { %{ $self->select->{ $name } || {} }, name => $name };
   my $list  = [ @{ $attrs->{ $attr } || [] } ];
   my $in    = [];

   for my $item (grep { not is_member $_, $list } @{ $items }) {
      CORE::push @{ $list }, $item; CORE::push @{ $in }, $item;
   }

   $attrs->{ $attr } = $list;
   return ($attrs, $in);
}

sub _search {
   my ($self, $where) = @_; my $results = $self->_results; my @tmp;

   if (not defined $results->[ 0 ]) {
      $results = $self->select;

      for (keys %{ $results }) {
         my $attrs = { %{ $results->{ $_ } }, name => $_ };

         if (not $where or $self->_eval_criteria( $where, $attrs )) {
            CORE::push @{ $self->_results }, $self->_create_result( $attrs );
         }
      }
   }
   elsif ($where and defined $results->[ 0 ]) {
      for (@{ $results }) {
         $self->_eval_criteria( $where, $_ ) and CORE::push @tmp, $_;
      }

      $self->_results( \@tmp );
   }

   return wantarray ? $self->all : $self;
}

sub _splice {
   my ($self, $name, $attr, $items) = @_;

   my $attrs = { %{ $self->select->{ $name } || {} }, name => $name };
   my $list  = [ @{ $attrs->{ $attr } || [] } ];
   my $out   = [];

   for my $item (@{ $items }) {
      last unless (defined $list->[ 0 ]);

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

sub _update_result {
   my ($self, $result, $args) = @_;

   for my $attr (grep { exists $args->{ $_ } } @{ $self->attributes }) {
      $result->$attr( $args->{ $attr } );
   }

   return $result->update;
}

sub _validate_params {
   my ($self, $args) = @_; $args //= {};

   my $name = (is_hashref $args) ? $args->{name} : $args;

   $name or throw class => Unspecified, args => [ 'record name' ], level => 2;

   return $name;
}

1;

__END__

=pod

=head1 Name

File::DataClass::ResultSet - Core element methods

=head1 Synopsis

   use File:DataClass;

   $attrs = { result_source_attributes => { schema_attributes => { ... } } };

   $result_source = File::DataClass->new( $attrs )->result_source;

   $rs = $result_source->resultset( { path => q(path_to_data_file) } );

   $result = $rs->search( $hash_ref_of_where_clauses );

   for $result_object ($result->next) {
      # Do something with the result object
   }

=head1 Description

Find, search and update methods for element objects

=head1 Configuration and Environment

Defines these attributes

=over 3

=item C<list_class>

List class name, defaults to L<File::DataClass::List>

=item C<result_class>

Result class name, defaults to L<File::DataClass::Result>

=item C<source>

An object reference to the L<File::DataClass::ResultSource> instance
that created this result set

=item C<_iterator>

Contains the integer count of the position within the C<_results> hash.
Incremented by each call to L</next>

=item C<_operators>

A hash ref of coderefs that implement the comparison operations performed
by the L</search> method

=item C<_results>

An array of result objects. Produced by calling L</search>

=back

=head1 Subroutines/Methods

=head2 all

   @elements = $rs->search()->all;

Returns all the elements that are returned by the L</search> call

=head2 create

   $new_element_name = $rs->create( $args );

Creates and inserts an new element. The C<$args> hash requires these
keys; C<name> of the element to create and C<fields> is a hash
containing the attributes of the new element. Missing attributes are
defaulted from the C<defaults> attribute of the
L<File::DataClass::Schema> object. Returns the new element's name

=head2 create_or_update

   $element_name = $rs->create_or_update( $args );

Creates a new element if it does not already exist, updates the existing
one if it does. Calls L</_find_and_update>

=head2 delete

   $rs->delete( { name => $of_element_to_delete } );

Deletes an element

=head2 find

   $result_object = $rs->find( { name => $of_element_to_find } );

Finds the named element and returns an
L<element|File::DataClass::Result> object for it

=head2 _find_and_update

   $updated_element_name = $rs->_find_and_update( $args );

Finds the named element object and updates it's attributes. Does not wrap
the find and update in a transaction

=head2 first

   $result_object = $rs->search( $where_clauses )->first;

Returns the first element object that is the result of the search call

=head2 list

   $list_obect = $rs->list( { name => $name } );

Returns a L<list|File::DataClass::List> object

Retrieves the named element and a list of elements

=head2 last

   $result_object = $rs->search( $where_clauses )->last;

Returns the last element object that is the result of the search call

=head2 next

   $result_object = $rs->search( $where_clauses )->next;

Iterate over the elements returned by the search call

=head2 path

   $path = $rs->path;

Attribute L<File::DataClass::Schema/path>

=head2 push

   $added = $rs->push( { name => $name, list => $list, items => $items } );

Adds items to the attribute list. The C<$args> hash requires these
keys; C<name> the element to edit, C<list> the attribute of the named
element containing the list of existing items, C<req> the request
object and C<items> the field on the request object containing the
list of new items

=head2 reset

   $rs->reset

Resets the resultset's cursor, so you can iterate through the elements again

=head2 search

   $result = $rs->search( $hash_ref_of_where_clauses );

Search for elements that match the given criterion. The criterion is a hash
ref whose keys are element attribute names. The criterion values are either
scalar values or hash refs. The scalar values are tested for equality with
the corresponding element attribute values. Hash ref keys are treated as
comparison operators, the hash ref values are compared with the element
attribute values, e.g.

   { 'some_element_attribute_name' => { '>=' => 0 } }

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

=head2 _txn_do

Calls L<File::DataClass::Storage/txn_do>

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::List>

=item L<File::DataClass::Result>

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
