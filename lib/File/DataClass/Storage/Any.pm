# @(#)$Id$

package File::DataClass::Storage::Any;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.10.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use File::DataClass::Constants;
use File::DataClass::Storage;

with qw(File::DataClass::Util);

has 'schema' => is => 'ro', isa => 'Object', required => TRUE, weak_ref => TRUE,
   handles   => [ qw(cache storage_attributes storage_base), ];

has 'stores' => is => 'ro', isa => 'HashRef', lazy => TRUE,
   builder   => '_build_stores';

sub delete {
   my ($self, $path, @rest) = @_;

   return $self->_get_store_from_extension( $path )->delete( $path, @rest );
}

sub dump {
   my ($self, $path, @rest) = @_;

   return $self->_get_store_from_extension( $path )->dump( $path, @rest );
}

sub extn {
   return sub {
      my $extn = ((split m{ \. (.+) \z }mx, $_[ 0 ])[ -1 ]);

      return $extn ? q(.).$extn : q();
   };
}

sub extensions {
   return File::DataClass::Storage->extensions;
}

sub insert {
   my ($self, $path, @rest) = @_;

   return $self->_get_store_from_extension( $path )->insert( $path, @rest );
}

sub load {
   my ($self, @paths) = @_; $paths[ 0 ] or return {};

   my ($data, $meta, $newest) = $self->cache->get_by_paths( \@paths );
   my $cache_mtime  = $self->meta_unpack( $meta );

   not $self->is_stale( $data, $cache_mtime, $newest ) and return $data;

   $data = {}; $newest = 0;

   for my $path (@paths) {
      my $store = $self->_get_store_from_extension( $path );
      my ($red, $path_mtime) = $store->read_file( $path, FALSE ); $red or next;

      $path_mtime > $newest and $newest = $path_mtime;
      $self->merge_hash_data( $data, $red );
   }

   $self->cache->set_by_paths( \@paths, $data, $self->meta_pack( $newest ) );
   return $data;
}

sub meta_pack {
   my ($self, $mtime) = @_; my $attr = $self->{_meta_cache} || {};

   $attr->{mtime} = $mtime; return $attr;
}

sub meta_unpack {
   my ($self, $attr) = @_; $self->{_meta_cache} = $attr;

   return $attr ? $attr->{mtime} : undef;
};

sub read_file {
   my ($self, $path, @rest) = @_;

   return $self->_get_store_from_extension( $path )->read_file( $path, @rest );
}

sub select {
   my ($self, $path, @rest) = @_;

   return $self->_get_store_from_extension( $path )->select( $path, @rest );
}

sub txn_do {
   my ($self, $path, @rest) = @_;

   return $self->_get_store_from_extension( $path )->txn_do( $path, @rest );
}

sub update {
   my ($self, $path, @rest) = @_;

   return $self->_get_store_from_extension( $path )->update( $path, @rest );
}

sub validate_params {
   my ($self, $path, @rest) = @_;

   my $store = $self->_get_store_from_extension( $path );

   return $store->validate_params( $path, @rest );
}

# Private methods

sub _build_stores {
   my $self = shift; my $stores = {}; my $extensions = $self->extensions;

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

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::Any - Selects storage class using the extension on the path

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::DataClass::Schema;

   my $schema = File::DataClass::Schema->new( storage_class => q(Any) );

   my $data = $schema->load( 'data_file1.xml', 'data_file2.json' );

=head1 Description

Selects storage class using the extension on the path

=head1 Subroutines/Methods

=head2 delete

=head2 dump

=head2 extn

=head2 extensions

Class method that proxies the call to L<File::DataClass::Storage/extensions>

=head2 insert

=head2 load

=head2 read_file

=head2 select

=head2 txn_do

=head2 update

=head2 validate_params

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
