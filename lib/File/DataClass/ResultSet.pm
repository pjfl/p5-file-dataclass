# @(#)$Id$

package File::DataClass::ResultSet;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;
use Scalar::Util qw(blessed);
use TryCatch;

use File::DataClass::List;

with qw(File::DataClass::Util);

has 'path'       => is => 'rw', isa => 'Maybe[DataClassPath]';
has 'source'     => is => 'ro', isa => 'Object',   weak_ref => TRUE;
has 'list_class' => is => 'ro', isa => 'ClassName',
   default       => q(File::DataClass::List);
has '_elements'  => is => 'rw', isa => 'ArrayRef', init_arg => undef,
   default       => sub { return [] };
has '_iterator'  => is => 'rw', isa => 'Int',      init_arg => undef,
   default       => 0;

sub all {
   my $self = shift; return @{ $self->_elements };
}

sub create {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $updated = $self->_txn_do( $self->path, sub {
      my $attrs = { %{ $args->{fields} || {} }, name => $name };

      $self->schema->create_element( $self->path, $attrs )->insert;
   } );

   return $updated ? $name : undef;
}

sub delete {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   $self->_txn_do( $self->path, sub {
      my ($element, $error);

      unless ($element = $self->_find( $name )) {
         $error = 'File [_1] element [_2] does not exist';
         $self->throw( error => $error,
                       args  => [ $self->path->pathname, $name ] );
      }

      unless ($element->delete) {
         $error = 'File [_1] element [_2] not deleted';
         $self->throw( error => $error,
                       args  => [ $self->path->pathname, $name ] );
      }
   } );

   return $name;
}

sub dump {
   my ($self, $args) = @_;

   return $self->storage->dump( $self->path, $args->{data} || {} );
}

sub find {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   return $self->_txn_do( $self->path, sub { $self->_find( $name ) } );
}

sub first {
   my $self = shift; return $self->_elements ? $self->_elements->[0] : undef;
}

sub last {
   my $self = shift; return $self->_elements ? $self->_elements->[-1] : undef;
}

sub list {
   my ($self, $args) = @_;

   return $self->_txn_do( $self->path, sub { $self->_list( $args->{name} ) } );
}

sub load {
   my ($self, @paths) = @_;

   @paths = map { blessed $_ ? $_ : $self->io( $_ ) } @paths;

   return $self->storage->load( @paths ) || {};
}

sub next {
   my $self  = shift;

   my $index = $self->_iterator || 0; $self->_iterator( $index + 1 );

   return $self->_elements ? $self->_elements->[ $index ] : undef;
}

sub push {
   my ($self, $args) = @_; my ($added, $attrs, $list);

   my $name = $self->_validate_params( $args );

   $self->throw( 'No list name specified' ) unless ($list = $args->{list});

   my $items = $args->{items} || [];

   $self->throw( 'List contains no items' ) unless ($items->[0]);

   $self->_txn_do( $self->path, sub {
      ($attrs, $added) = $self->_push( $name, $list, $items );
      $self->_find_and_update( $name, $attrs );
   } );

   return $added;
}

sub schema {
   return shift->source->schema;
}

sub search {
   my ($self, $args) = @_;

   return $self->_txn_do( $self->path, sub {
      $self->_search( $args->{where} );
   } );
}

sub splice {
   my ($self, $args) = @_; my ($attrs, $list, $removed);

   my $name = $self->_validate_params( $args );

   $self->throw( 'No list name specified' ) unless ($list = $args->{list});

   my $items = $args->{items} || [];

   $self->throw( 'List contains no items' ) unless ($items->[0]);

   $self->_txn_do( $self->path, sub {
      ($attrs, $removed) = $self->_splice( $name, $list, $items );
      $self->_find_and_update( $name, $attrs );
   } );

   return $removed;
}

sub storage {
   return shift->schema->storage;
}

sub update {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   $self->_txn_do( $self->path, sub {
      $self->_find_and_update( $name, $args->{fields} || {} );
   } );

   return $name;
}

# Private methods

sub _eval_criterion {
   my ($self, $where, $attrs) = @_; my $lhs;

   for my $attr (keys %{ $where }) {
      return FALSE unless (exists  $attrs->{ $attr });
      return FALSE unless (defined ($lhs = $attrs->{ $attr }));

      if (ref $where->{ $attr } eq HASH) {
         while (my ($op, $rhs) = each %{ $where->{ $attr } }) {
            return FALSE unless ($self->_eval_op( $lhs, $op, $rhs ));
         }
      }
      else {
         if (ref $lhs eq ARRAY) {
            unless ($self->is_member( $where->{ $attr }, @{ $lhs })) {
               return FALSE;
            }
         }
         else { return FALSE unless ($lhs eq $where->{ $attr }) }
      }
   }

   return TRUE;
}

sub _eval_op {
   my ($self, $lhs, $op, $rhs) = @_;

   my $subr = $self->_operators->{ $op };

   return $subr ? $subr->( $lhs, $rhs ) : undef;
}

sub _find {
   my ($self, $name) = @_;

   my $elements = $self->storage->select( $self->path );

   return unless ($name and exists $elements->{ $name });

   my $attrs = { %{ $elements->{ $name } }, name => $name };

   return $self->schema->create_element( $self->path, $attrs );
}

sub _find_and_update {
   my ($self, $name, $attrs) = @_; my $element;

   return unless ($element = $self->_find( $name ));

   $self->schema->update_attributes( $element, $attrs );

   return $element->update;
}

sub _list {
   my ($self, $name) = @_; my ($attr, $attrs);

   my $elements = $self->storage->select( $self->path );
   my $new      = $self->list_class->new;

   $new->list( [ sort keys %{ $elements } ] );

   if ($attr = $self->schema->label_attr) {
      $new->labels
         ( { map { $_ => $elements->{ $_ }->{ $attr } } @{ $new->list } } );
   }

   if ($name && exists $elements->{ $name }) {
      $attrs = { %{ $elements->{ $name } }, name => $name };
      $new->found( TRUE );
   }
   else { $attrs = { name => $name } }

   $new->element( $self->schema->create_element( $self->path, $attrs ) );

   return $new;
}

sub _operators {
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

sub _push {
   my ($self, $name, $attr, $items) = @_;

   my $elements = $self->storage->select( $self->path );
   my $attrs    = { %{ $elements->{ $name } } };
   my $list     = [ @{ $attrs->{ $attr } || [] } ];
   my $in       = [];

   for my $item (@{ $items }) {
      next if ($self->is_member( $item, @{ $list } ));

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
      $elements = $self->storage->select( $self->path );

      for my $name (keys %{ $elements }) {
         my $attrs = { %{ $elements->{ $name } }, name => $name };

         if (not $where or $self->_eval_criterion( $where, $attrs )) {
            CORE::push @{ $self->_elements },
               $self->schema->create_element( $self->path, $attrs );
         }
      }
   }
   elsif ($where and defined $elements->[0]) {
      for my $attrs (@{ $elements }) {
         CORE::push @tmp, $attrs if ($self->_eval_criterion( $where, $attrs ));
      }

      $self->_elements( \@tmp );
   }

   return wantarray ? $self->all : $self;
}

sub _splice {
   my ($self, $name, $attr, $items) = @_;

   my $elements = $self->storage->select( $self->path ) || {};
   my $attrs    = { %{ $elements->{ $name } } };
   my $list     = [ @{ $attrs->{ $attr } || [] } ];
   my $out      = [];

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
   my ($self, $path, $code_ref) = @_; my $wantarray = wantarray;

   $self->throw( 'No file path specified' ) unless ($path);

   my $key = q(txn:).$path->pathname; my $res;

   try {
      $self->storage->lock->set( k => $key );

      if ($wantarray) { @{ $res } = $code_ref->() }
      else { $res = $code_ref->() }

      $self->storage->lock->reset( k => $key );
   }
   catch ($e) { $self->storage->lock->reset( k => $key ); $self->throw( $e ) }

   return $wantarray ? @{ $res } : $res;
}

sub _validate_params {
   my ($self, $args) = @_; $args ||= {}; my $name;

   $self->throw( 'No element name specified' ) unless ($name = $args->{name});

   return $name;
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

   my $attrs  = { schema_attributes => $schema_attributes };
   my $source = File::DataClass::ResultSource->new( $attrs ) );
   my $rs     = $source->resultset( $path );
   my $result = $rs->search( $where );

   for $element_obj ($result->next) {
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

   $element_obj = $rs->create( $attrs );

Creates and returns a new L<element|File::DataClass::Element>
object from the attributes provided

=head2 delete

=head2 dump

=head2 find

   $element_obj = $rs->find( $name );

Finds the named element and returns an
L<element|File::DataClass::Element> object for it

=head2 find_and_update

   $element_obj = $rs->find_and_update( $name, $attrs );

Finds the named element object and updates it's attributes

=head2 first

   $element_obj = $rs->search( $where )->first;

Returns the first element object that is the result of the search call

=head2 list

   $list = $rs->list( $name );

Returns a L<list|File::DataClass::List> object

=head2 last

   $element_obj = $rs->search( $where )->last;

Returns the last element object that is the result of the search call

=head2 load

=head2 next

   $element_obj = $rs->search( $where )->next;

Iterate over the elements returned by the search call

=head2 push
   ($attrs, $added) = $rs->push( $name, $list, $items );

Adds items to the attribute list

=head2 schema

   $schema = $rs->schema;

Returns the source schema object

=head2 search

   $result = $rs->search( $where );

Search for elements that match the given criterion. The criterion is a hash
ref whose keys are element attribute names. The criterion values are either
scalar values or hash refs. The scalar values are tested for equality with
the corresponding element attribute values. Hash ref keys are treated as
comparison operators, the hash ref values are compared with the element
attribute values, e.g.

   $where = { quick_links => { '>=' => 0 } };

=head2 splice

   ($attrs, $removed) = $rs->splice( $name, $list, $items );

Removes items from the attribute list

=head2 storage

Returns the schema storage object

=head2 update

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
