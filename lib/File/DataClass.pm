# @(#)$Ident: DataClass.pm 2013-08-16 22:27 pjf ;

package File::DataClass;

use 5.010001;
use version; our $VERSION = qv( sprintf '0.24.%d', q$Rev: 3 $ =~ /\d+/gmx );

use Moo;

my $F_DC_Cache = {};

sub F_DC_Cache {
   return $F_DC_Cache;
}

1;

__END__

=pod

=head1 Name

File::DataClass - Structured data file IO with OO paradigm

=head1 Version

This document describes version v0.24.$Rev: 3 $ of L<File::DataClass>

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

Provides methods for manipulating structured data stored in files of
different formats

The documentation for this distribution starts in the class
L<File::DataClass::Schema>

L<File::DataClass::IO> is a L<Moo> based implementation of L<IO::All>s API.
It implements the file and directory methods only

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

=head2 F_DC_Cache

   $hash_ref_of_CHI_objects = File::DataClass->F_DC_Cache;

A class method which returns a hash ref of L<CHI> objects which are
used to cache the results of reading files

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

=back

=head1 Incompatibilities

On C<MSWin32> and C<Cygwin> it is assumed that NTFS is being used and
that it does not support C<mtime> so caching on those platforms is
disabled

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=File-DataClass. Patches are
welcome

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
