package File::DataClass::Schema;

use namespace::autoclean;

use Moo;
use Class::Null;
use File::DataClass::Cache;
use File::DataClass::Constants;
use File::DataClass::Functions qw( ensure_class_loaded first_char
                                   qualify_storage_class map_extension2class
                                   merge_attributes supported_extensions
                                   throw );
use File::DataClass::IO;
use File::DataClass::ResultSource;
use File::DataClass::Storage;
use File::DataClass::Types     qw( Bool Cache ClassName Directory DummyClass
                                   HashRef Lock Num Object Path Str );
use File::Spec;
use Scalar::Util               qw( blessed );
use Unexpected::Functions      qw( Unspecified );

extends q(File::DataClass);

has 'cache'                    => is => 'lazy', isa => Cache;

has 'cache_attributes'         => is => 'ro',   isa => HashRef,
   default                     => sub { {
      page_size                => 131_072,
      num_pages                => 89,
      unlink_on_exit           => TRUE, } };

has 'cache_class'              => is => 'ro',   isa => ClassName | DummyClass,
   default                     => 'File::DataClass::Cache';

has 'debug'                    => is => 'ro',   isa => Bool, default => FALSE;

has 'lock'                     => is => 'lazy', isa => Lock,
   default                     => sub { Class::Null->new };

has 'log'                      => is => 'lazy', isa => Object,
   default                     => sub { Class::Null->new };

has 'path'                     => is => 'rw',   isa => Path,
   coerce                      => Path->coercion;

has 'perms'                    => is => 'rw',   isa => Num, default => PERMS;

has 'result_source_attributes' => is => 'ro',   isa => HashRef,
   default                     => sub { {} };

has 'result_source_class'      => is => 'ro',   isa => ClassName,
   default                     => 'File::DataClass::ResultSource';

has 'source_registrations'     => is => 'lazy', isa => HashRef[Object];

has 'storage'                  => is => 'rw',   isa => Object,
   builder                     => '_build_storage', lazy => TRUE;

has 'storage_attributes'       => is => 'ro',   isa => HashRef,
   default                     => sub { {} };

has 'storage_class'            => is => 'rw',   isa => Str,
   default                     => 'JSON', lazy => TRUE;

has 'tempdir'                  => is => 'ro',   isa => Directory,
   coerce                      => Directory->coercion,
   default                     => sub { File::Spec->tmpdir };

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $class, @args) = @_; my $attr = $orig->( $class, @args );

   my $builder = delete $attr->{builder} or return $attr;
   my $config  = $builder->can( 'config' ) ? $builder->config : {};

   merge_attributes $attr, $builder, [ qw( debug lock log tempdir ) ];
   merge_attributes $attr, $config,  [ qw( tempdir ) ];

   return $attr;
};

sub _build_cache {
   my $self  = shift; (my $ns = lc __PACKAGE__) =~ s{ :: }{-}gmx; my $cache;

   my $attrs = { cache_attributes => { %{ $self->cache_attributes } },
                 builder          => $self };

   $ns    = $attrs->{cache_attributes}->{namespace} ||= $ns;
   $cache = $self->F_DC_Cache;
   exists $cache->{ $ns } and return $cache->{ $ns };
   $self->cache_class eq 'none' and return Class::Null->new;
   $attrs->{cache_attributes}->{share_file}
        ||= NUL.$self->tempdir->catfile( "${ns}.dat" );

   return $self->F_DC_Cache->{ $ns } = $self->cache_class->new( $attrs );
}

sub _build_source_registrations {
   my $self = shift; my $sources = {};

   for my $moniker (keys %{ $self->result_source_attributes }) {
      my $attrs = { %{ $self->result_source_attributes->{ $moniker } } };
      my $class = delete $attrs->{result_source_class}
               || $self->result_source_class;

      $attrs->{name} = $moniker; $attrs->{schema} = $self;

      $sources->{ $moniker } = $class->new( $attrs );
   }

   return $sources;
}

sub _build_storage {
   my $self = shift; my $class = $self->storage_class;

   if (first_char $class eq '+') { $class = substr $class, 1 }
   else { $class = qualify_storage_class $class }

   ensure_class_loaded $class;

   return $class->new( { %{ $self->storage_attributes }, schema => $self } );
}

# Public methods
sub dump {
   my ($self, $args) = @_; blessed $self or $self = $self->_constructor;

   my $path = $args->{path} || $self->path;

   blessed $path or $path = io( $path );

   return $self->storage->dump( $path, $args->{data} );
}

sub extensions { # Deprecated
   my $extns = {};

   warn "DEPRECATED: Calling F::DC::Schema::extensions as a class method\n";

   $extns->{ $_ } = map_extension2class( $_ ) for (supported_extensions());

   return $extns;
}

sub load {
   my ($self, @paths) = @_; blessed $self or $self = $self->_constructor;

   $paths[ 0 ] or $paths[ 0 ] = $self->path;

   @paths = map { blessed $_ ? $_ : io( $_ ) } @paths;

   return $self->storage->load( @paths );
}

sub resultset {
   my ($self, $moniker) = @_; return $self->source( $moniker )->resultset;
}

sub source {
   my ($self, $moniker) = @_;

   $moniker or throw Unspecified, args => [ 'result source' ];

   my $source = $self->source_registrations->{ $moniker }
      or throw 'Result source [_1] unknown', args => [ $moniker ];

   return $source;
}

sub sources {
   return keys %{ shift->source_registrations };
}

sub translate {
   my ($self, $args) = @_;

   my $class      = blessed $self       || $self;
   my $from_class = $args->{from_class} || 'Any';
   my $to_class   = $args->{to_class  } || 'Any';
   my $attrs      = { path => $args->{from}, storage_class => $from_class };
   my $data       = $class->new( $attrs )->load;

   $attrs = { path => $args->{to}, storage_class => $to_class };
   $class->new( $attrs )->dump( { data => $data } );
   return;
}

# Private methods
sub _constructor {
   my $class = shift;
   my $attr  = { cache_class => 'none', storage_class => 'Any' };

   return $class->new( $attr );
}

1;

__END__

=pod

=head1 Name

File::DataClass::Schema - Base class for schema definitions

=head1 Synopsis

   use File::DataClass::Schema;

   $schema = File::DataClass::Schema->new
      ( path    => [ qw( path to a file ) ],
        result_source_attributes => { source_name => {}, },
        tempdir => [ qw( path to a directory ) ] );

   $schema->source( q(source_name) )
          ->attributes( [ qw( list of attr names ) ] );
   $rs = $schema->resultset( 'source_name' );
   $result = $rs->find( { name => 'id of field element to find' } );
   $result->$attr_name( $some_new_value );
   $result->update;
   @result = $rs->search( { 'attr name' => 'some value' } );

=head1 Description

Base class for schema definitions. Each record in a data file requires
a result source to define it's attributes

=head1 Configuration and Environment

Registers all result sources defined by the result source attributes

Creates a new instance of the storage class which defaults to
L<File::DataClass::Storage::JSON>

Defines these attributes

=over 3

=item C<cache>

Instantiates and returns the L<Cache|File::DataClass/Cache> class
attribute. Built on demand

=item C<cache_attributes>

Passed to the L<Cache::Cache> constructor

=item C<cache_class>

Classname used to create the cache object. Defaults to
L<File::DataClass::Cache>

=item C<debug>

Writes debug information to the log object if set to true

=item C<lock>

Defaults to L<Class::Null>. Can be set via the C<builder>
attribute. Built on demand

=item C<log>

Log object. Typically an instance of L<Log::Handler>

=item C<path>

Path to the file. This is a L<File::DataClass::IO> object that can be
coerced from either a string or an array ref

=item C<perms>

Permissions to set on the file if it is created. Defaults to
L<PERMS|File::DataClass::Constants/PERMS>

=item C<result_source_attributes>

A hash ref of result sources. See L<File::DataClass::ResultSource>

=item C<result_source_class>

The class name used to create result sources when the source registration
attribute is instantiated. Acts as a schema wide default of not overridden
in the C<result_source_attributes>

=item C<source_registrations>

A hash ref or registered result sources, i.e. the keys of the
C<result_source_attributes> hash

=item C<storage>

An instance of a subclass of L<File::DataClass::Storage>

=item C<storage_attributes>

Attributes passed to the storage object's constructor

=item C<storage_base>

If the storage class is only a partial classname then this attribute is
prepended to it

=item C<storage_class>

The name of the storage class to instantiate

=item C<tempdir>

Temporary directory used to store the cache and lock objects disk
representation

=back

=head1 Subroutines/Methods

=head2 BUILDARGS

Constructs the attribute hash passed to the constructor method

=head2 dump

   $schema->dump( { path => $to_file, data => $data_hash } );

Dumps the data structure to a file. Path defaults to the one specified in
the schema definition. Returns the data that was written to the file if
successful. Can be called a class or an object method

=head2 extensions

   \%extension_map = $self->extensions;

B<DEPRECATED>: Use the function C<extension2class> instead

Returns a hash ref that maps filename extensions (keys) onto storage
subclasses (values)

=head2 load

   $data_hash = $schema->load( @paths );

Loads and returns the merged data structure from the named
files. Paths defaults to the one specified in the schema
definition. Data will be read from cache if available and not
stale. Can be called a class or an object method

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

Setting the C<debug> attribute to true will cause the log object's
debug method to be called with useful information

=head1 Dependencies

=over 3

=item L<namespace::autoclean>

=item L<Class::Null>

=item L<File::DataClass>

=item L<File::DataClass::Cache>

=item L<File::DataClass::Constants>

=item L<File::DataClass::Functions>

=item L<File::DataClass::ResultSource>

=item L<File::DataClass::Storage>

=item L<File::DataClass::Types>

=item L<Moo>

=item L<Unexpected>

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

Peter Flanigan, C<< <pjfl@cpan.org> >>

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
