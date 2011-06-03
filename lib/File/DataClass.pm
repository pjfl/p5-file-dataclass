# @(#)$Id$

package File::DataClass;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.5.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use MooseX::ClassAttribute;
use File::DataClass::Exception;

with qw(File::DataClass::Constraints);

class_has 'Cache' => is => 'rw', isa => 'HashRef[F_DC_Cache]',
   default        => sub { {} };

class_has 'Exception_Class' => is => 'rw', isa => 'F_DC_Exception',
   default                  => 'File::DataClass::Exception';

class_has 'Lock'  => is => 'rw', isa => 'Maybe[F_DC_Lock]';

with qw(File::DataClass::Util);

__PACKAGE__->meta->make_immutable;

no MooseX::ClassAttribute;
no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass - Structured data file IO with OO paradigm

=head1 Version

This document describes File::DataClass version 0.5.$Revision$

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

Provides CRUD methods for structured data stored in files of different formats

The documentation for this distribution starts in the class
L<File::DataClass::Schema>

=head1 Configuration and Environment

Defines these class attributes. They are set on first use by
methods in L<File::DataClass::Schema>

=over 3

=item B<Cache>

This is a L<Cache::Cache> object which is used to cache the results of
reading a file. Maybe of type C<F_DC_Cache>

=item B<Exception_Class>

A classname that is expected to have a class method C<throw>. Defaults to
L<File::DataClass::Exception> and is of type C<F_DC_Exception>

=item B<Lock>

A lock object that has the methods C<set> and C<reset>. Maybe of type
C<F_DC_Lock>

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::autoclean>

=item L<File::DataClass::Exception>

=item L<MooseX::ClassAttribute>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

The class structure and API where taken from L<DBIx::Class>

The API for the file IO was taken from L<IO::All>

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2011 Peter Flanigan. All rights reserved

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
