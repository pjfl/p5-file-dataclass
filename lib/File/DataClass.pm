# @(#)$Id$

package File::DataClass;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use File::DataClass::Constants;
use File::DataClass::ResultSource;
use File::Spec;
use IPC::SRLock;
use Moose;

with qw(File::DataClass::Util);

has 'debug' =>
   ( is => q(rw), isa => q(Bool),    default => FALSE );
has 'log' =>
   ( is => q(rw), isa => q(Object),  default => sub { Class::Null->new } );
has 'tempdir' =>
   ( is => q(rw), isa => q(Str),     default => sub { File::Spec->tmpdir } );
has 'lock_attributes' =>
   ( is => q(ro), isa => q(HashRef), default => sub { return {} } );
has 'lock' =>
   ( is => q(rw), isa => q(Object),  lazy_build => TRUE );
has 'result_source_attributes' =>
   ( is => q(ro), isa => q(HashRef), default => sub { return {} } );
has 'result_source_class' =>
   ( is => q(ro), isa => q(ClassName),
     default => q(File::DataClass::ResultSource) );
has 'result_source' =>
   ( is => q(ro), isa => q(Object),  lazy_build => TRUE );

sub create {
   my ($self, $args) = @_; return $self->_resultset( $args )->create( $args );
}

sub delete {
   my ($self, $args) = @_; return $self->_resultset( $args )->delete( $args );
}

sub dump {
   my ($self, $args) = @_; return $self->_resultset( $args )->dump( $args );
}

sub find {
   my ($self, $args) = @_; return $self->_resultset( $args )->find( $args );
}

sub list {
   my ($self, $args) = @_; return $self->_resultset( $args )->list( $args );
}

sub load {
   my ($self, @paths) = @_; return $self->_resultset->load( @paths );
}

sub push_attribute {
   my ($self, $args) = @_;

   return $self->_resultset( $args )->push_attribute( $args );
}

sub search {
   my ($self, $args) = @_; return $self->_resultset( $args )->search( $args );
}

sub splice_attribute {
   my ($self, $args) = @_;

   return $self->_resultset( $args )->splice_attribute( $args );
}

sub translate {
   my ($self, $args) = @_;

   my $attrs  = {
      result_source_attributes => {
         schema_attributes => {
            %{ $self->result_source->schema_attributes },
            storage_class => $args->{from_class},
         }
      }
   };
   my $source = $self->new( $attrs );
   my $data   = $source->load( $args->{from} ) || {};

   $attrs->{result_source_attributes}->{schema_attributes}->{storage_class}
      = $args->{to_class};

   my $dest   = $self->new( $attrs );

   $dest->dump( { path => $args->{to}, data => $data } );

   return;
}

sub update {
   my ($self, $args) = @_; return $self->_resultset( $args )->update( $args );
}

# Private methods

my $_cache = {};
my $_lock;

sub _build_lock {
   my $self = shift;

   return $_lock if ($_lock);

   my $args = $self->lock_attributes;

   $args->{debug  } ||= $self->debug;
   $args->{log    } ||= $self->log;
   $args->{tempdir} ||= $self->tempdir;

   return $_lock = IPC::SRLock->new( $args );
}

sub _build_result_source {
   my $self    = shift;
   my $attrs   = $self->result_source_attributes || {};
   my $storage = $attrs->{schema_attributes}->{storage_attributes} ||= {};

   $storage->{cache} = $_cache;
   $storage->{debug} = $self->debug;
   $storage->{log  } = $self->log;
   $storage->{lock } = $self->lock;

   return $self->result_source_class->new( $attrs );
}

sub _resultset {
   my ($self, $args) = @_; $args ||= {};

   return $self->result_source->resultset( $args->{path} );
}

__PACKAGE__->meta->make_immutable;

no Moose;

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
