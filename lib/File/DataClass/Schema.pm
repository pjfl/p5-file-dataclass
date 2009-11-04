# @(#)$Id$

package File::DataClass::Schema;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use File::DataClass::Constants;
use File::Spec;
use Moose;

use File::DataClass::Cache;
use File::DataClass::ResultSource;
use File::DataClass::Storage;
use IPC::SRLock;

extends qw(File::DataClass);
with    qw(File::DataClass::Util);

has 'cache'                    => is => 'ro', isa => 'F_DC_Cache',
   lazy_build                  => TRUE;
has 'cache_attributes'         => is => 'ro', isa => 'HashRef',
   default                     => sub { return {} };
has 'debug'                    => is => 'ro', isa => 'Bool',
   default                     => FALSE;
has 'lock'                     => is => 'ro', isa => 'F_DC_Lock',
   lazy_build                  => TRUE;
has 'lock_attributes'          => is => 'ro', isa => 'HashRef',
   default                     => sub { return {} };
has 'lock_class'               => is => 'ro', isa => 'ClassName',
   default                     => q(IPC::SRLock);
has 'log'                      => is => 'ro', isa => 'Object',
   default                     => sub { Class::Null->new };
has 'path'                     => is => 'rw', isa => 'F_DC_Path',
   coerce                      => TRUE;
has 'perms'                    => is => 'rw', isa => 'Num',
   default                     => PERMS;
has 'result_source_attributes' => is => 'ro', isa => 'HashRef',
   default                     => sub { return {} };
has 'result_source_class'      => is => 'ro', isa => 'ClassName',
   default                     => q(File::DataClass::ResultSource);
has 'source_registrations'     => is => 'ro', isa => 'HashRef[Object]',
   lazy_build                  => TRUE;
has 'storage_attributes'       => is => 'ro', isa => 'HashRef',
   default                     => sub { return {} };
has 'storage_base'             => is => 'ro', isa => 'ClassName',
   default                     => q(File::DataClass::Storage);
has 'storage_class'            => is => 'ro', isa => 'Str',
   default                     => q(XML::Simple);
has 'storage'                  => is => 'rw', isa => 'Object',
   lazy_build                  => TRUE;
has 'tempdir'                  => is => 'ro', isa => 'F_DC_Directory',
   default                     => sub { __PACKAGE__->io( File::Spec->tmpdir )},
   coerce                      => TRUE;

sub dump {
   my ($self, $args) = @_;

   my $path = $args->{path} || $self->path;

   blessed $path or $path = $self->io( $path );

   return $self->storage->dump( $path, $args->{data} || {} );
}

sub load {
   my ($self, @paths) = @_;

   $paths[0] or $paths[0] = $self->path;

   @paths = map { blessed $_ ? $_ : $self->io( $_ ) } @paths;

   return $self->storage->load( @paths ) || {};
}

sub resultset {
   my ($self, $moniker) = @_; return $self->source( $moniker )->resultset;
}

sub source {
   my ($self, $moniker) = @_;

   $moniker or $self->throw( 'No result source specified' );

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
   my $self  = shift;

   $self->Cache and return $self->Cache;

   my $attrs = {}; (my $ns = lc __PACKAGE__) =~ s{ :: }{-}gmx;

   $attrs->{cache_attributes}                 = $self->cache_attributes;
   $attrs->{cache_attributes}->{cache_root} ||= $self->tempdir;
   $attrs->{cache_attributes}->{namespace } ||= $ns;

   return $self->Cache( File::DataClass::Cache->new( $attrs ) );
}

sub _build_lock {
   my $self = shift;

   $self->Lock and return $self->Lock;

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

      $attrs->{name} = $moniker; $attrs->{schema} = $self;

      $sources->{ $moniker } = $self->result_source_class->new( $attrs );
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

0.1.$Revision$

=head1 Synopsis

   use File::DataClass;

   $attrs = { result_source_attributes => { schema_attributes => { ... } } };

   $result_source = File::DataClass->new( $attrs )->result_source;

   $schema = $result_source->schema;

=head1 Description

This is the base class for schema definitions. Each element in a data file
requires a schema definition to define it's attributes that should
inherit from this

=head1 Subroutines/Methods

=head2 dump

   $schema->dump( { path => $to_file, data => $data_hash } );

Dumps the data structure to a file

=head2 load

   $schema->load( @paths );

Returns the merged data structure from the named files

=head2 resultset

=head2 source

=head2 sources

=head2 translate

=head1 Configuration and Environment

Creates a new instance of the storage class which defaults to
L<File::DataClass::Storage::XML::Simple>

If the schema is language dependent then an instance of
L<File::DataClass::Combinator> is created as a proxy for the
storage class

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Element>

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
