# @(#)$Id$

package File::DataClass;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use File::DataClass::Constants;
use File::Spec;
use Moose;
use Scalar::Util qw(blessed);

use Cache::FileCache;
use File::DataClass::ResultSource;
use IPC::SRLock;

with qw(File::DataClass::Util);

has 'path'    => is => 'rw', isa => 'Maybe[DataClassPath]';
has 'debug'   => is => 'ro', isa => 'Bool', default => FALSE;
has 'log'     => is => 'ro', isa => 'Object',
   default    => sub { Class::Null->new };
has 'tempdir' => is => 'ro', isa => 'Str',
   default    => sub { File::Spec->tmpdir };

has 'cache_attributes' => is => 'ro', isa => 'HashRef',
   default             => sub { return {} };
has 'cache_class'      => is => 'ro', isa => 'ClassName',
   default             => q(Cache::FileCache);
has 'cache'            => is => 'rw', isa => 'Object', lazy_build => TRUE;

has 'lock_attributes'  => is => 'ro', isa => 'HashRef',
   default             => sub { return {} };
has 'lock_class'       => is => 'ro', isa => 'ClassName',
   default             => q(IPC::SRLock);
has 'lock'             => is => 'rw', isa => 'Object', lazy_build => TRUE;

has 'result_source_attributes' => is => 'ro', isa => 'HashRef',
   default                     => sub { return {} };
has 'result_source_class'      => is => 'ro', isa => 'ClassName',
   default                     => q(File::DataClass::ResultSource);
has 'result_source'            => is => 'ro', isa => 'Object',
   lazy_build                  => TRUE;

sub create {
   my ($self, $args) = @_; return $self->_resultset( $args )->create( $args );
}

sub delete {
   my ($self, $args) = @_; return $self->_resultset( $args )->delete( $args );
}

sub dump {
   my ($self, $args) = @_; $args->{path} ||= $self->path;

   return $self->result_source->schema->dump( $args );
}

sub find {
   my ($self, $args) = @_; return $self->_resultset( $args )->find( $args );
}

sub list {
   my ($self, $args) = @_; return $self->_resultset( $args )->list( $args );
}

sub load {
   my ($self, @paths) = @_;

   push @paths, $self->path unless ($paths[0]);

   return $self->result_source->schema->load( @paths );
}

sub push {
   my ($self, $args) = @_; return $self->_resultset( $args )->push( $args );
}

sub search {
   my ($self, $args) = @_; return $self->_resultset( $args )->search( $args );
}

sub splice {
   my ($self, $args) = @_; return $self->_resultset( $args )->splice( $args );
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
   my $class  = blessed $self;
   my $source = $class->new( $attrs );
   my $data   = $source->load( $args->{from} ) || {};

   $attrs->{result_source_attributes}->{schema_attributes}->{storage_class}
      = $args->{to_class};

   my $dest   = $class->new( $attrs );

   $dest->dump( { path => $args->{to}, data => $data } );

   return;
}

sub update {
   my ($self, $args) = @_; return $self->_resultset( $args )->update( $args );
}

# Private methods

my ($_Cache, $_Lock);

sub _build_cache {
   my $self = shift;

   return $_Cache if ($_Cache);

   my $attrs = $self->cache_attributes;
   (my $ns   = lc __PACKAGE__) =~ s{ :: }{-}gmx;

   $attrs->{cache_root} ||= $self->tempdir;
   $attrs->{namespace } ||= $ns;

   return $_Cache = $self->cache_class->new( $attrs );
}

sub _build_lock {
   my $self = shift;

   return $_Lock if ($_Lock);

   my $attrs = $self->lock_attributes;

   $attrs->{debug  } ||= $self->debug;
   $attrs->{log    } ||= $self->log;
   $attrs->{tempdir} ||= $self->tempdir;

   return $_Lock = $self->lock_class->new( $attrs );
}

sub _build_result_source {
   my $self    = shift;
   my $attrs   = $self->result_source_attributes;
   my $storage = $attrs->{schema_attributes}->{storage_attributes} ||= {};

   $storage->{cache} ||= $self->cache;
   $storage->{debug} ||= $self->debug;
   $storage->{log  } ||= $self->log;
   $storage->{lock } ||= $self->lock;

   return $self->result_source_class->new( $attrs );
}

sub _resultset {
   my ($self, $args) = @_; $args ||= {};

   my $path = $args->{path} || $self->path;

   return $self->result_source->resultset( $path );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass - Read and write structured data files

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::DataClass;

   my $file_obj = File::DataClass->new( tempdir => '/var/yourapp/tmp' );

=head1 Description

Provides CRUD methods reading and writing files in different
formats. For each schema a subclass is defined that inherits from
the L<File::DataClass::Schema>

=head1 Configuration and Environment

This class defines these attributes

=over 3

=item B<path>

=item B<debug>

=item B<log>

=item B<tempdir>

=item B<cache_attributes>

=item B<cache_class>

=item B<cache>

=item B<lock_attributes>

=item B<lock_class>

=item B<lock>

=item B<result_source_attributes>

=item B<result_source_class>

=item B<result_source>

=back

=head1 Subroutines/Methods

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

=head2 push

   $file_obj->push( $args );

Add new items to an attribute list. The C<$args> hash requires these
keys; I<path> the file to edit, I<name> the element to edit, I<list>
the attribute of the named element containing the list of existing
items, I<req> the request object and I<items> the field on the request
object containing the list of new items

=head2 search

   $file_obj->search( { path => $to_file, where => $to_search_for } );

Search for elements that match the supplied criteria

=head2 splice

   $file_obj->splice( $args );

Removes items from an attribute list

=head2 translate

   $file_obj->translate( { from => $source_path, to => $dest_path } );

Reads a file in one format and writes it back out in another format

=head2 update

   $file_obj->update(  { path => $to_file, name => $of_element, fields => $attr_hash } );

Updates the named element

=head1 Diagnostics

Setting the B<debug> attribute to true will cause the log object's
debug method to be called with useful information

=head1 Dependencies

=over 3

=item L<Cache::FileCache>

=item L<Class::Null>

=item L<File::DataClass::Constants>

=item L<File::DataClass::ResultSource>

=item L<IPC::SRLock>

=item L<Moose>

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
