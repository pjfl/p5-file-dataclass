# @(#)$Id$

package File::DataClass;

use strict;
use warnings;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Exception;
use MooseX::ClassAttribute;

class_has 'Cache'           => is => 'rw', isa => 'Maybe[F_DC_Cache]';
class_has 'Exception_Class' => is => 'rw', isa => 'F_DC_Exception',
   default                  => q(File::DataClass::Exception);
class_has 'Lock'            => is => 'rw', isa => 'Maybe[F_DC_Lock]';

no MooseX::ClassAttribute;

1;

__END__

=pod

=head1 Name

File::DataClass - Read and write structured data files

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::DataClass;

   my $object = File::DataClass::Schema->new( tempdir => '/var/yourapp/tmp' );

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
