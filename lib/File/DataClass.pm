# @(#)$Id$

package File::DataClass;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(File::DataClass::Base);

use File::DataClass::ResultSource;
use MRO::Compat;
use Scalar::Util qw(blessed);
use TryCatch;

__PACKAGE__->config
   ( path                => undef,
     result_source_class => q(File::DataClass::ResultSource),
     schema_attributes   => {} );

__PACKAGE__->mk_accessors( qw(path result_source result_source_class
                              schema_attributes ) );

sub new {
   my ($self, $app, @rest) = @_;

   my $new   = $self->next::method( $app, @rest );
   my $attrs = { schema_attributes => $new->schema_attributes };

   $new->result_source( $new->result_source_class->new( $app, $attrs ) );

   return $new;
}

sub create {
   my ($self, $args) = @_;

   my ($rs, $path, $name) = $self->_validate_params( $args );

   $args->{fields} ||= {}; $args->{fields}->{name} = $name;

   $self->_txn_do( $path, sub { $rs->create( $args->{fields} )->insert } );

   return $name;
}

sub delete {
   my ($self, $args) = @_;

   my ($rs, $path, $name) = $self->_validate_params( $args );

   $self->_txn_do( $path, sub {
      my ($element, $error);

      unless ($element = $rs->find( $name )) {
         $error = 'File [_1] element [_2] does not exist';
         $self->throw( error => $error, args => [ $path, $name ] );
      }

      unless ($element->delete) {
         $error = 'File [_1] element [_2] not deleted';
         $self->throw( error => $error, args => [ $path, $name ] );
      }
   } );

   return $name;
}

sub dump {
   my ($self, $args) = @_;

   my ($rs, $path) = $self->_resultset( $args );

   return $rs->storage->dump( $path, $args->{data} || {} );
}

sub find {
   my ($self, $args) = @_;

   my ($rs, $path, $name) = $self->_validate_params( $args );

   return $self->_txn_do( $path, sub { $rs->find( $name ) } );
}

sub list {
   my ($self, $args) = @_;

   my ($rs, $path) = $self->_resultset( $args );

   return $self->_txn_do( $path, sub { $rs->list( $args->{name} ) } );
}

sub load {
   my ($self, @paths) = @_;

   my $rs = $self->result_source->resultset;

   @paths = map { blessed $_ ? $_ : $self->io( $_ ) } @paths;

   return $rs->storage->load( @paths ) || {};
}

sub push_attribute {
   my ($self, $args) = @_; my ($added, $attrs, $list);

   my ($rs, $path, $name) = $self->_validate_params( $args );

   $self->throw( 'No list name specified' ) unless ($list = $args->{list});

   my $items = $args->{items} || [];

   $self->throw( 'List contains no items' ) unless ($items->[0]);

   $self->_txn_do( $path, sub {
      ($attrs, $added) = $rs->push_attribute( $name, $list, $items );
      $rs->find_and_update( $name, $attrs );
   } );

   return $added;
}

sub search {
   my ($self, $args) = @_;

   my ($rs, $path) = $self->_resultset( $args );

   return $self->_txn_do( $path, sub { $rs->search( $args->{criterion} ) } );
}

sub splice_attribute {
   my ($self, $args) = @_; my ($attrs, $list, $removed);

   my ($rs, $path, $name) = $self->_validate_params( $args );

   $self->throw( 'No list name specified' ) unless ($list = $args->{list});

   my $items = $args->{items} || [];

   $self->throw( 'List contains no items' ) unless ($items->[0]);

   $self->_txn_do( $path, sub {
      ($attrs, $removed) = $rs->splice_attribute( $name, $list, $items );
      $rs->find_and_update( $name, $attrs );
   } );

   return $removed;
}

sub translate {
   my ($self, $args) = @_;

   my $attrs  = {
      schema_attributes => {
         %{ $self->schema_attributes },
         storage_class => $args->{from_class} } };
   my $source = $self->new( $self, $attrs );
   my $data   = $source->load( $args->{from} ) || {};

   $attrs->{schema_attributes}->{storage_class} = $args->{to_class};

   my $dest   = $self->new( $self, $attrs );

   $dest->dump( { path => $args->{to}, data => $data } );

   return;
}

sub update {
   my ($self, $args) = @_;

   my ($rs, $path, $name) = $self->_validate_params( $args );

   $self->_txn_do( $path, sub {
      $rs->find_and_update( $name, $args->{fields} || {} );
   } );

   return $name;
}

# Private methods

sub _txn_do {
   my ($self, $path, $code_ref) = @_;

   my $key = q(txn:).$path->pathname; my $res;

   try {
      $self->lock->set( k => $key );

      if (wantarray) { @{ $res } = $code_ref->() }
      else { $res = $code_ref->() }

      $self->lock->reset( k => $key );
   }
   catch ($e) { $self->lock->reset( k => $key ); $self->throw( $e ) }

   return wantarray ? @{ $res } : $res;
}

sub _resultset {
   my ($self, $args) = @_;

   my $path = $args->{path} || $self->path;

   $self->throw( 'No file path specified' ) unless ($path);

   $path = $self->io( $path ) unless (blessed $path);

   return ($self->result_source->resultset( $path, $args->{lang} ), $path);
}

sub _validate_params {
   my ($self, $args) = @_; my $name;

   $self->throw( 'No element name specified' ) unless ($name = $args->{name});

   return ($self->_resultset( $args ), $name);
}

1;

__END__

=pod

=head1 Name

File::DataClass - Read and write configuration files

=head1 Version

0.4.$Revision$

=head1 Synopsis

   use File::DataClass;

=head1 Description

Provides CRUD methods for read and write configuration files. For each
schema a subclass is defined that inherits from this class

=head1 Subroutines/Methods

=head2 new

Creates a new result source

=head2 create

   $file_obj->create( { path => $to_file, name => $of_element, fields => $attr_hash } );

Creates a new element. The args hash requires these keys; I<path>
of the file to edit, I<name> of the element to edit and I<fields> is a hash
containing the attributes of the new element. Missing attributes are
defaulted from the I<defaults> attribute of the
L<File::DataClass::Schema> object

=head2 delete

   $file_obj->delete( { path => $to_file, name => $of_element } );

Deletes an element

=head2 dump

   $file_obj->dump( { path => $to_file, data => $data_hash } );

Dumps the data structure to a file

=head2 find

   $file_obj->find( { path => $to_file, name => $of_element } );

Retrieves the named element

=head2 list

   $file_obj->list( { path => $to_file, name => $of_element } );

Retrieves the named element and a list of elements

=head2 load

   $file_obj->load( @paths );

Returns the merged data structure from the named files

=head2 push_attribute

   $file_obj->push_attribute( $args );

Add new items to an attribute list. The C<$args> hash requires these
keys; I<path> the file to edit, I<name> the element to edit, I<list>
the attribute of the named element containing the list of existing
items, I<req> the request object and I<items> the field on the request
object containing the list of new items

=head2 search

   $file_obj->search( { path => $to_file, criterion => $to_search_for } );

Search for elements that match the supplied criteria

=head2 splice_attribute

   $file_obj->splice_attribute( $args );

Removes items from an attribute list

=head2 translate

   $file_obj->translate( { from => $source_path, to => $dest_path } );

Reads a file in one format and writes it back out in another format

=head2 update

   $file_obj->update(  { path => $to_file, name => $of_element, fields => $attr_hash } );

Updates the named element

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Base>

=item L<File::DataClass::ResultSource>

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
