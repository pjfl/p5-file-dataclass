# @(#)$Id$

package File::DataClass;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Null;
use File::DataClass::Constants;
use File::Spec;
use Moose;

use File::DataClass::Cache;
use File::DataClass::ResultSource;
use IPC::SRLock;

with qw(File::DataClass::Util);

has 'debug'   =>
   is => 'ro', isa => 'Bool',      default    => FALSE;
has 'log'     =>
   is => 'ro', isa => 'Object',    default    => sub { Class::Null->new };
has 'tempdir' =>
   is => 'ro', isa => 'Str',       default    => sub { File::Spec->tmpdir };

has 'cache_attributes' =>
   is => 'ro', isa => 'HashRef',   default    => sub { return {} };
has 'cache'            =>
   is => 'rw', isa => 'Object',    lazy_build => TRUE;

has 'lock_attributes'  =>
   is => 'ro', isa => 'HashRef',   default    => sub { return {} };
has 'lock_class'       =>
   is => 'ro', isa => 'ClassName', default    => q(IPC::SRLock);
has 'lock'             =>
   is => 'rw', isa => 'Object',    lazy_build => TRUE;

has 'result_source_attributes' =>
   is => 'ro', isa => 'HashRef',   default    => sub { return {} };
has 'result_source_class'      =>
   is => 'ro', isa => 'ClassName', default => q(File::DataClass::ResultSource);
has 'result_source'            =>
   is => 'ro', isa => 'Object',    lazy_build => TRUE, init_arg => undef;

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
   my $source = $class->new( $attrs )->result_source;
   my $data   = $source->load( $args->{from} ) || {};

   $attrs->{result_source_attributes}->{schema_attributes}->{storage_class}
      = $args->{to_class};

   my $dest   = $class->new( $attrs )->result_source;

   $dest->dump( { path => $args->{to}, data => $data } );

   return;
}

# Private methods

my ($_Cache, $_Lock);

sub _build_cache {
   my $self = shift;

   return $_Cache if ($_Cache);

   my $attrs = {}; (my $ns = lc __PACKAGE__) =~ s{ :: }{-}gmx;

   $attrs->{cache_attributes}                 = $self->cache_attributes;
   $attrs->{cache_attributes}->{cache_root} ||= $self->tempdir;
   $attrs->{cache_attributes}->{namespace } ||= $ns;

   return $_Cache = File::DataClass::Cache->new( $attrs );
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

   my $object = File::DataClass->new( tempdir => '/var/yourapp/tmp' );

=head1 Description

Provides CRUD methods reading and writing files in different
formats. For each schema a subclass is defined that inherits from
the L<File::DataClass::Schema>

=head1 Configuration and Environment

This class defines these attributes

=over 3

=item B<debug>

=item B<log>

=item B<tempdir>

=item B<cache_attributes>

=item B<cache>

=item B<lock_attributes>

=item B<lock_class>

=item B<lock>

=item B<result_source_attributes>

=item B<result_source_class>

=item B<result_source>

=back

=head1 Subroutines/Methods

=head2 translate

   $object->translate( { from => $source_path, to => $dest_path } );

Reads a file in one format and writes it back out in another format

=head1 Diagnostics

Setting the B<debug> attribute to true will cause the log object's
debug method to be called with useful information

=head1 Dependencies

=over 3

=item L<Class::Null>

=item L<File::DataClass::Cache>

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
