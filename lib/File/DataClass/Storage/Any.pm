# @(#)$Ident: Any.pm 2013-04-30 01:32 pjf ;

package File::DataClass::Storage::Any;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.19.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Moose;
use File::Basename             qw(basename);
use File::DataClass::Constants;
use File::DataClass::Functions qw(ensure_class_loaded is_stale merge_hash_data
                                  throw);
use File::DataClass::Storage;

has 'schema' => is => 'ro', isa => 'Object', required => TRUE, weak_ref => TRUE,
   handles   => [ qw(cache storage_attributes storage_base), ];

has 'stores' => is => 'ro', isa => 'HashRef', lazy => TRUE,
   builder   => '_build_stores';

sub create_or_update {
   return shift->_get_store_from_extension( $_[ 0 ] )->create_or_update( @_ );
}

sub delete {
   return shift->_get_store_from_extension( $_[ 0 ] )->delete( @_ );
}

sub dump {
   return shift->_get_store_from_extension( $_[ 0 ] )->dump( @_ );
}

sub extn {
   return sub {
      my $path = shift || NUL; my ($extn) = $path =~ m{ \. ([^\.]+) \z }mx;

      return $extn ? q(.).$extn : NUL;
   };
}

sub insert {
   return shift->_get_store_from_extension( $_[ 0 ] )->insert( @_ );
}

sub load {
   my ($self, @paths) = @_; $paths[ 0 ] or return {};

   my ($data, $meta, $newest) = $self->cache->get_by_paths( \@paths );
   my $cache_mtime  = $self->meta_unpack( $meta );

   not is_stale $data, $cache_mtime, $newest and return $data;

   $data = {}; $newest = 0;

   for my $path (@paths) {
      my $store = $self->_get_store_from_extension( $path );
      my ($red, $path_mtime) = $store->read_file( $path, FALSE ); $red or next;

      $path_mtime > $newest and $newest = $path_mtime;
      merge_hash_data $data, $red;
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
   return shift->_get_store_from_extension( $_[ 0 ] )->read_file( @_ );
}

sub select {
   return shift->_get_store_from_extension( $_[ 0 ] )->select( @_ );
}

sub txn_do {
   return shift->_get_store_from_extension( $_[ 0 ] )->txn_do( @_ );
}

sub update {
   return shift->_get_store_from_extension( $_[ 0 ] )->update( @_ );
}

sub validate_params {
   return shift->_get_store_from_extension( $_[ 0 ] )->validate_params( @_ );
}

# Private methods

sub _build_stores {
   my $self = shift; my $stores = {};

   for my $extn (keys %{ EXTENSIONS() }) {
      my $class = EXTENSIONS()->{ $extn }->[ 0 ];

      if (q(+) eq substr $class, 0, 1) { $class = substr $class, 1 }
      else { $class = $self->storage_base.q(::).$class }

      ensure_class_loaded $class;

      $stores->{ $extn } = $class->new( { %{ $self->storage_attributes },
                                          schema => $self->schema } );
   }

   return $stores;
}

sub _get_store_from_extension {
   my ($self, $path) = @_; my $file = basename( NUL.$path );

   my $extn = (split m{ \. }mx, $file)[ -1 ]
      or throw error => 'File [_1] has no extension', args => [ $file ];

   my $store = $self->stores->{ q(.).$extn }
      or throw error => 'Extension [_1] has no store', args => [ $extn ];

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

This document describes version v0.19.$Rev: 1 $

=head1 Synopsis

   use File::DataClass::Schema;

   my $schema = File::DataClass::Schema->new( storage_class => q(Any) );

   my $data = $schema->load( 'data_file1.xml', 'data_file2.json' );

=head1 Description

Selects storage class using the extension on the path

=head1 Subroutines/Methods

=head2 create_or_update

=head2 delete

=head2 dump

=head2 extn

=head2 insert

=head2 load

=head2 meta_pack

=head2 meta_unpack

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

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
