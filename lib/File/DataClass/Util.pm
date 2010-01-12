# @(#)$Id$

package File::DataClass::Util;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::MOP;
use File::DataClass::Constants;
use File::DataClass::IO ();
use File::Spec;
use List::Util qw(first);
use Moose::Role;
use Moose::Util::TypeConstraints;
use Scalar::Util qw(blessed);
use TryCatch;

subtype 'F_DC_Cache' => as 'Object' =>
   where   { $_->isa( q(File::DataClass::Cache) ) } =>
   message {
      'Object '.(blessed $_ || $_).' is not of class File::DataClass::Cache' };

subtype 'F_DC_Exception' => as 'ClassName' =>
   where   { $_->can( q(throw) ) } =>
   message { "Class $_ is not loaded or has no throw method" };

subtype 'F_DC_Lock' => as 'Object' =>
   where   { $_->isa( q(Class::Null) )
                or ($_->can( q(set) ) and $_->can( q(reset) ) ) } =>
   message { 'Object '.(blessed $_ || $_).' is missing set or reset methods' };

subtype 'F_DC_Path' => as 'Object' =>
   where   { $_->isa( q(File::DataClass::IO) ) } =>
   message {
      'Object '.(blessed $_ || $_).' is not of class File::DataClass::IO' };

subtype 'F_DC_Result' => as 'Object' =>
   where   { $_->isa( q(File::DataClass::Result) ) } =>
   message {
      'Object '.(blessed $_ || $_).' is not of class File::DataClass::Result'
   };

subtype 'F_DC_Directory' => as 'F_DC_Path' =>
   where   { $_->is_dir  } =>
   message { 'Path '.($_ ? $_.' is not a directory' : 'not specified') };

subtype 'F_DC_File'      => as 'F_DC_Path' =>
   where   { $_->is_file } =>
   message { 'Path '.($_ ? $_.' is not a file' : 'not specified') };

coerce 'F_DC_Path'      => from 'ArrayRef' => via { __PACKAGE__->io( $_ ) };
coerce 'F_DC_Directory' => from 'ArrayRef' => via { __PACKAGE__->io( $_ ) };
coerce 'F_DC_File'      => from 'ArrayRef' => via { __PACKAGE__->io( $_ ) };
coerce 'F_DC_Path'      => from 'Str'      => via { __PACKAGE__->io( $_ ) };
coerce 'F_DC_Directory' => from 'Str'      => via { __PACKAGE__->io( $_ ) };
coerce 'F_DC_File'      => from 'Str'      => via { __PACKAGE__->io( $_ ) };

sub basename {
   my ($self, $path, @suffixes) = @_;

   return $self->io( NUL.$path )->basename( @suffixes );
}

sub catdir {
   my ($self, @rest) = @_; return File::Spec->catdir( @rest );
}

sub catfile {
   my ($self, @rest) = @_; return File::Spec->catfile( @rest );
}

sub dirname {
   my ($self, $path) = @_; return $self->io( NUL.$path )->dirname;
}

sub ensure_class_loaded {
   my ($self, $class, $opts) = @_; $opts ||= {};

   my $package_defined = sub { Class::MOP::is_class_loaded( $class ) };

   return TRUE if (not $opts->{ignore_loaded} and $package_defined->());

   try        { Class::MOP::load_class( $class ) }
   catch ($e) { $self->throw( $e ) }

   return TRUE if ($package_defined->());

   my $e = 'Class [_1] loaded but package undefined';

   $self->throw( error => $e, args => [ $class ] );
   return;
}

sub io {
   my ($self, @rest) = @_; my $io = File::DataClass::IO->new( @rest );

   $io->exception_class( File::DataClass->Exception_Class );

   return $io;
}

sub is_member {
   my ($self, $candidate, @rest) = @_; $candidate or return;

   return (first { $_ eq $candidate } @rest) ? TRUE : FALSE;
}

sub throw {
   my ($self, @rest) = @_;

   return File::DataClass->Exception_Class->throw( @rest );
}

no Moose::Util::TypeConstraints;
no Moose::Role;

1;

__END__

=pod

=head1 Name

File::DataClass::Base - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use parent qw(File::DataClass::Base);

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 basename

=head2 catdir

=head2 catfile

=head2 dirname

=head2 ensure_class_loaded

=head2 io

=head2 is_member

=head2 throw

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
