# @(#)$Ident: DataClass.pm 2013-04-30 22:09 pjf ;

package File::DataClass;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.18.%d', q$Rev: 6 $ =~ /\d+/gmx );

use Moose;
use MooseX::ClassAttribute;
use MooseX::Types::Moose qw(HashRef);
use File::DataClass::Constraints qw(Cache);

class_has 'F_DC_Cache' => is => 'ro', isa => HashRef[Cache],
   default             => sub { {} };

__PACKAGE__->meta->make_immutable;

no Moose;
no MooseX::ClassAttribute;

1;

__END__

=pod

=head1 Name

File::DataClass - Structured data file IO with OO paradigm

=head1 Version

This document describes version v0.18.$Rev: 6 $ of L<File::DataClass>

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

Defines these class attributes. They are set on first use when an instance
of L<File::DataClass::Schema> is created

=over 3

=item B<Cache>

This is a L<Cache::Cache> object which is used to cache the results of
reading a file. Maybe of type C<Cache>

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::autoclean>

=item L<MooseX::ClassAttribute>

=back

=head1 Incompatibilities

On C<MSWin32> and C<Cygwin> it is assumed that NTFS is being used and
that it does not support C<mtime> so caching on those platforms is
disabled

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to the
address below. Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

The class structure and API where taken from L<DBIx::Class>

The API for the file IO was taken from L<IO::All>

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

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
