# @(#)$Id$

package File::DataClass::Cache;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Cache::FileCache;
use File::DataClass::Constants;
use Moose;

has 'cache_attributes' => is => 'ro', isa => 'HashRef',
   default             => sub { return {} };
has 'cache_class'      => is => 'ro', isa => 'ClassName',
   default             => q(Cache::FileCache);
has 'cache'            => is => 'ro', isa => 'Object', lazy_build => TRUE;

sub get {
   my ($self, $key) = @_;

   my $cached = $key    ? $self->cache->get( $key ) : FALSE;
   my $data   = $cached ? $cached->{data}           : undef;
   my $meta   = $cached ? $cached->{meta}           : { mtime => 0 };

   return ($data, $meta);
}

sub get_by_paths {
   my ($self, $paths) = @_;
   my ($key, $newest) = $self->_get_key_and_newest( $paths );
   my ($data, $meta)  = $self->get( $key );

   return ($data, $meta->{mtime} < $newest);
}

sub remove {
   my ($self, $key) = @_; $key || return;

   my $mtimes = $self->cache->get( q(mtimes) ) || {};

   delete $mtimes->{ $key };
   $self->cache->set( q(mtimes), $mtimes );
   $self->cache->remove( $key );
   return;
}

sub set {
   my ($self, $key, $data, $meta) = @_; $meta ||= {}; $meta->{mtime} ||= 0;

   if ($key and defined $data) {
      $self->cache->set( $key, { data => $data, meta => $meta } );

      my $mtimes = $self->cache->get( q(mtimes) ) || {};

      $mtimes->{ $key } = $meta->{mtime} || 0;
      $self->cache->set( q(mtimes), $mtimes );
   }

   return ($data, $meta);
}

sub set_by_paths {
   my ($self, $paths, $data) = @_;

   my ($key, $newest) = $self->_get_key_and_newest( $paths );

   return $self->set( $key, $data, { mtime => $newest } );
}

# Private methods

sub _build_cache {
   my $self = shift; return $self->cache_class->new( $self->cache_attributes );
}

sub _get_key_and_newest {
   my ($self, $paths) = @_; my ($key, $pathname); my $newest = 0;

   my $mtimes = $self->cache->get( q(mtimes) ) || {};

   for my $path (@{ $paths }) {
      next unless ($pathname = $path->pathname);

      $key .= $key ? q(~).$pathname : $pathname;

      my $mtime = $mtimes->{ $pathname } || 0;

      $newest = $mtime if ($mtime > $newest);
   }

   return ($key, $newest);
}

1;

__END__

=pod

=head1 Name

File::DataClass::Cache - Adds extra methods to the Cache::Cache API

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::DataClass::Cache;

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 get

=head2 get_by_paths

=head2 remove

=head2 set

=head2 set_by_paths

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Accessor::Fast>

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
