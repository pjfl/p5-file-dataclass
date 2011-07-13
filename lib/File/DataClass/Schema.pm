# @(#)$Id$

package File::DataClass::Schema;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use File::DataClass::Constants;
use File::Spec;
use Moose;

use File::DataClass::Cache;
use File::DataClass::Exception;
use File::DataClass::ResultSource;
use File::DataClass::Storage;
use IPC::SRLock;

extends qw(File::DataClass);

has 'cache'                    => is => 'ro', isa => 'F_DC_Cache',
   lazy_build                  => TRUE;
has 'cache_attributes'         => is => 'ro', isa => 'HashRef',
   default                     => sub { {
      driver                   => q(FastMmap),
      unlink_on_exit           => TRUE, } };
has 'cache_class'              => is => 'ro',
   isa                         => 'F_DC_DummyClass | ClassName',
   default                     => q(File::DataClass::Cache);
has 'debug'                    => is => 'ro', isa => 'Bool',
   default                     => FALSE;
has 'exception_class'          => is => 'ro', isa => 'F_DC_Exception',
   default                     => q(File::DataClass::Exception);
has 'lock'                     => is => 'ro', isa => 'F_DC_Lock',
   lazy_build                  => TRUE;
has 'lock_attributes'          => is => 'ro', isa => 'HashRef',
   default                     => sub { {} };
has 'lock_class'               => is => 'ro',
   isa                         => 'F_DC_DummyClass | ClassName',
   default                     => q(IPC::SRLock);
has 'log'                      => is => 'ro', isa => 'Object',
   default                     => sub { Class::Null->new };
has 'path'                     => is => 'rw', isa => 'F_DC_Path',
   coerce                      => TRUE;
has 'perms'                    => is => 'rw', isa => 'Num',
   default                     => PERMS;
has 'result_source_attributes' => is => 'ro', isa => 'HashRef',
   default                     => sub { {} };
has 'result_source_class'      => is => 'ro', isa => 'ClassName',
   default                     => q(File::DataClass::ResultSource);
has 'source_registrations'     => is => 'ro', isa => 'HashRef[Object]',
   lazy_build                  => TRUE;
has 'storage_attributes'       => is => 'ro', isa => 'HashRef',
   default                     => sub { {} };
has 'storage_base'             => is => 'ro', isa => 'ClassName',
   default                     => q(File::DataClass::Storage);
has 'storage_class'            => is => 'ro', isa => 'Str',
   default                     => q(XML::Simple);
has 'storage'                  => is => 'rw', isa => 'Object',
   lazy_build                  => TRUE;
has 'tempdir'                  => is => 'ro', isa => 'F_DC_Directory',
   default                     => File::Spec->tmpdir,
   coerce                      => TRUE;

with qw(File::DataClass::Util);

around BUILDARGS => sub {
   my ($orig, $class, @args) = @_; my $attrs = $class->$orig( @args );

   exists $attrs->{ioc_obj} or return $attrs;

   my $ioc   = delete $attrs->{ioc_obj};
   my @attrs = ( qw(debug exception_class lock log tempdir) );

   $attrs->{ $_ } ||= $ioc->$_() for (grep { $ioc->can( $_ ) } @attrs);

   $ioc->can( q(config) ) and $attrs->{tempdir} ||= $ioc->config->{tempdir};

   return $attrs;
};

sub dump {
   my ($self, $args) = @_;

   my $path = $args->{path} || $self->path;

   blessed $path or $path = $self->io( $path );

   return $self->storage->dump( $path, $args->{data} || {} );
}

sub load {
   my ($self, @paths) = @_;

   $paths[ 0 ] or $paths[ 0 ] = $self->path;

   @paths = map { blessed $_ ? $_ : $self->io( $_ ) } @paths;

   return $self->storage->load( @paths ) || {};
}

sub resultset {
   my ($self, $moniker) = @_; return $self->source( $moniker )->resultset;
}

sub source {
   my ($self, $moniker) = @_;

   $moniker or $self->throw( 'Result source not specified' );

   my $source = $self->source_registrations->{ $moniker }
      or $self->throw( error => 'Result source [_1] unknown',
                       args  => [ $moniker ] );

   return $source;
}

sub sources {
   return keys %{ shift->source_registrations };
}

sub translate {
   my ($self, $args) = @_;

   my $class = blessed $self || $self;
   my $attrs = { path => $args->{from}, storage_class => $args->{from_class} };
   my $data  = $class->new( $attrs )->load;

   $attrs = { path => $args->{to}, storage_class => $args->{to_class} };
   $class->new( $attrs )->dump( { data => $data } );
   return;
}

# Private methods

sub _build_cache {
   my $self  = shift; (my $ns = lc __PACKAGE__) =~ s{ :: }{-}gmx; my $cache;

   my $attrs = { cache_attributes => $self->cache_attributes, schema => $self };

   $ns = $attrs->{cache_attributes}->{namespace} ||= $ns;

   $cache = $self->Cache and exists $cache->{ $ns } and return $cache->{ $ns };

   $self->cache_class eq q(none) and return Class::Null->new;

   $attrs->{cache_attributes}->{root_dir} ||= NUL.$self->tempdir;

   return $self->Cache->{ $ns } = $self->cache_class->new( $attrs );
}

sub _build_lock {
   my $self = shift;

   $self->Lock and return $self->Lock;

   $self->lock_class eq q(none) and return Class::Null->new;

   my $attrs = $self->lock_attributes;

   $attrs->{debug  } ||= $self->debug;
   $attrs->{log    } ||= $self->log;
   $attrs->{tempdir} ||= $self->tempdir;

   return $self->Lock( $self->lock_class->new( $attrs ) );
}

sub _build_source_registrations {
   my $self = shift; my $sources = {};

   for my $moniker (keys %{ $self->result_source_attributes }) {
      my $attrs = $self->result_source_attributes->{ $moniker };
      my $class = delete $attrs->{result_source_class}
               || $self->result_source_class;

      $attrs->{name} = $moniker; $attrs->{schema} = $self;

      $sources->{ $moniker } = $class->new( $attrs );
   }

   return $sources;
}

sub _build_storage {
   my $self = shift; my $class = $self->storage_class;

   if (q(+) eq substr $class, 0, 1) { $class = substr $class, 1 }
   else { $class = $self->storage_base.q(::).$class }

   $self->ensure_class_loaded( $class );

   return $class->new( { %{ $self->storage_attributes }, schema => $self } );
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Schema - Base class for schema definitions

=head1 Version

0.6.$Revision$

=head1 Synopsis

   use File::DataClass::Schema;

   $schema = File::DataClass::Schema->new
      ( path    => [ qw(path to a file) ],
        result_source_attributes => { source_name => {}, },
        tempdir => [ qw(path to a directory) ] );

   $schema->source( q(source_name) )->attributes( [ qw(list of attr names) ] );
   $rs = $schema->resultset( q(source_name) );
   $result = $rs->find( { name => q(id of field element to find) } );
   $result->$attr_name( $some_new_value );
   $result->update;
   @result = $rs->search( { 'attr name' => q(some value) } );

=head1 Description

Base class for schema definitions. Each element in a data file
requires a result source to define it's attributes

=head1 Configuration and Environment

Registers all result sources defined by the result source attributes

Creates a new instance of the storage class which defaults to
L<File::DataClass::Storage::XML::Simple>

Defines these attributes

=over 3

=item B<cache>

Instantiates and returns the L<Cache|File::DataClass/Cache> class
attribute. Built on demand

=item B<cache_attributes>

Passed to the L<Cache::Cache> constructor

=item B<debug>

Writes debug information to the log object if set to true

=item B<exception_class>

A classname that is expected to have a class method C<throw>. Defaults to
L<File::DataClass::Exception> and is of type C<F_DC_Exception>

=item B<ioc_obj>

An optional object that provides these methods; C<debug>,
C<exception_class>, C<lock>, C<log>, and C<tempdir>. Their values are
or'ed with values in the attributes hash before being passed to the
constructor

=item B<lock>

Instantiates and returns the L<Lock|File::DataClass/Lock> class
attribute. Built on demand

=item B<lock_attributes>

Passed to the L<IPC::SRLock> constructor

=item B<lock_class>

Defaults to L<IPC::SRLock>

=item B<log>

Log object. Typically an instance of L<Log::Handler>

=item B<path>

Path to the file. This is a L<File::DataClass::IO> object that can be
coerced from either a string or an array ref

=item B<perms>

Permissions to set on the file if it is created. Defaults to
L<PERMS|File::DataClass::Constants/PERMS>

=item B<result_source_attributes>

A hash ref of result sources. See L<File::DataClass::ResultSource>

=item B<result_source_class>

The class name used to create result sources when the source registration
attribute is instantiated. Acts as a schema wide default of not overridden
in the B<result_source_attributes>

=item B<source_registrations>

A hash ref or resgistered result sources, i.e. the keys of the
B<result_source_attributes> hash

=item B<storage>

An instance of a subclass of L<File::DataClass::Storage>

=item B<storage_attributes>

Attributes passed to the storage object's constructor

=item B<storage_base>

If the storage class is only a partial classname then this attribute is
prepended to it

=item B<storage_class>

The name of the storage class to instantiate

=item B<tempdir>

Temporary directory used to store the cache and lock objects disk
representation

=back

=head1 Subroutines/Methods

=head2 dump

   $schema->dump( { path => $to_file, data => $data_hash } );

Dumps the data structure to a file. Path defaults to the one specified in
the schema definition. Returns the data that was written to the file if
successful

=head2 load

   $data_hash = $schema->load( @paths );

Loads and returns the merged data structure from the named
files. Paths defaults to the one specified in the schema
definition. Data will be read from cache if available and not stale

=head2 resultset

   $rs = $schema->resultset( $source_name );

Returns a resultset object which by default is an instance of
L<File::DataClass::Resultset>

=head2 source

   $source = $schema->source( $source_name );

Returns a result source object which by default is an instance of
L<File::DataClass::ResultSource>

=head2 sources

   @sources = $schema->sources;

Returns a list of all registered result source names

=head2 translate

   $schema->translate( $args );

Reads a file in one format and writes it back out in another format

=head1 Diagnostics

Setting the B<debug> attribute to true will cause the log object's
debug method to be called with useful information

=head1 Dependencies

=over 3

=item L<namespace::autoclean>

=item L<Class::Null>

=item L<File::DataClass>

=item L<File::DataClass::Cache>

=item L<File::DataClass::Constants>

=item L<File::DataClass::Exception>

=item L<File::DataClass::ResultSource>

=item L<File::DataClass::Storage>

=item L<File::DataClass::Util>

=item L<IPC::SRLock>

=item L<Moose>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2010 Peter Flanigan. All rights reserved

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
