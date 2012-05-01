# @(#)$Id$

package File::DataClass::Storage::Any;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use File::DataClass::Constants;
use File::DataClass::Storage;

with qw(File::DataClass::Util);

has 'schema' => is => 'ro', isa => 'Object', required => TRUE, weak_ref => TRUE,
   handles   => [ qw(cache storage_attributes storage_base), ];

has 'stores' => is => 'ro', isa => 'HashRef', lazy => TRUE,
   builder   => '_build_stores';

sub delete {
   my $self = shift;

   $self->throw( 'Delete method not implimented in multiclass storage' );
   return; # Not reached
}

sub dump {
   my $self = shift;

   $self->throw( 'Dump method not implimented in multiclass storage' );
   return; # Not reached
}

sub insert {
   my $self = shift;

   $self->throw( 'Insert method not implimented in multiclass storage' );
   return; # Not reached
}

sub load {
   my ($self, @paths) = @_; $paths[ 0 ] or return {};

   my ($data, $meta, $newest) = $self->cache->get_by_paths( \@paths );
   my $cache_mtime  = $self->_meta_unpack( $meta );

   not $self->is_stale( $data, $cache_mtime, $newest ) and return $data;

   ($data, $newest) = $self->_load( \@paths );
   $self->_meta_pack( $meta, $newest );
   $self->cache->set_by_paths( \@paths, $data, $meta );
   return $data;
}

sub select {
   my $self = shift;

   $self->throw( 'Select method not implimented in multiclass storage' );
   return; # Not reached
}

sub update {
   my $self = shift;

   $self->throw( 'Update method not implimented in multiclass storage' );
   return; # Not reached
}

# Private methods

sub _build_stores {
   my $self = shift; my $stores = {};

   my $extensions = File::DataClass::Storage->extensions;

   for my $extn (keys %{ $extensions }) {
       my $class = $extensions->{ $extn }->[ 0 ];

       if (q(+) eq substr $class, 0, 1) { $class = substr $class, 1 }
       else { $class = $self->storage_base.q(::).$class }

       $self->ensure_class_loaded( $class );

       $stores->{ $extn } = $class->new( { %{ $self->storage_attributes },
                                           schema => $self->schema } );
   }

   return $stores;
}

sub _get_store_from_extension {
   my ($self, $path) = @_; my $file = $self->basename( $path );

   my $extn = (split m{ \. }mx, $file)[ -1 ]
      or $self->throw( error => 'File [_1] has no extension',
                       args  => [ $file ] );

   my $store = $self->stores->{ q(.).$extn }
      or $self->throw( error => 'Extension [_1] has no store',
                       args  => [ $extn ] );

   return $store;
}

sub _load {
   my ($self, $paths) = @_; my $data = {}; my $newest = 0;

   for my $path (@{ $paths }) {
      my $store = $self->_get_store_from_extension( $path );
      my ($red, $path_mtime) = $store->_read_file( $path, FALSE ); $red or next;

      $path_mtime > $newest and $newest = $path_mtime;
      $self->merge_hash_data( $data, $red );
   }

   return ($data, $newest);
}

sub _meta_pack {
   my ($self, $attrs, $mtime) = @_; $attrs->{mtime} = $mtime;
}

sub _meta_unpack {
   my ($self, $attrs) = @_; return $attrs ? $attrs->{mtime} : undef;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::Any - Loads and merges data from multiply storage classes

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::DataClass::Schema;

   my $schema = File::DataClass::Schema->new( storage_class => q(Any) );

   my $data = $schema->load( 'data_file1.xml', 'data_file2.json' );

=head1 Description

Loads and merges data from multiply storage classes

=head1 Subroutines/Methods

=head2 delete

=head2 dump

=head2 insert

=head2 load

=head2 select

=head2 update

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Storage>

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

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
