# @(#)$Id$

package File::DataClass::Constraints;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::IO;
use Moose::Role;
use Moose::Util::TypeConstraints;
use Scalar::Util qw(blessed);

subtype 'F_DC_Cache' => as 'Object' =>
   where   { $_->isa( q(File::DataClass::Cache) ) } =>
   message {
      'Object '.(blessed $_ || $_).' is not of class File::DataClass::Cache' };

subtype 'F_DC_DummyClass' => as 'Str' =>
   where   { $_ eq q(none) } =>
   message { "Class $_ is not 'none'" };

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

coerce 'F_DC_Path'      => from 'ArrayRef' => via { io( $_ ) };
coerce 'F_DC_Directory' => from 'ArrayRef' => via { io( $_ ) };
coerce 'F_DC_File'      => from 'ArrayRef' => via { io( $_ ) };
coerce 'F_DC_Path'      => from 'Str'      => via { io( $_ ) };
coerce 'F_DC_Directory' => from 'Str'      => via { io( $_ ) };
coerce 'F_DC_File'      => from 'Str'      => via { io( $_ ) };

no Moose::Util::TypeConstraints;
no Moose::Role;

1;

__END__

=pod

=head1 Name

File::DataClass::Constraints - Role defining package constraints

=head1 Version

0.3.$Revision$

=head1 Synopsis

   use Moose;

   with qw(File::DataClass::Constraints);

=head1 Description

Defines the constraints used in this distribution

=head1 Configuration and Environment

Defines these subtypes

=over 3

=item B<F_DC_Cache>

Is a L<File::DataClass::Cache>

=item B<F_DC_Exception>

Can C<throw>

=item B<F_DC_Lock>

Is a L<Class::Null> or can C<set> and C<reset>

=item B<F_DC_Path>

Is a L<File::DataClass::IO>. Can be coerced from either a string or
an array ref

=item B<F_DC_Result>

Is a L<File::DataClass::Result>

=item B<F_DC_Directory>

Subtype of C<F_DC_Path> which is a directory. Can be coerced from
either a string or an array ref

=item B<F_DC_File>

Subtype of C<F_DC_Path> which is a file. Can be coerced from either a
string or an array ref

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::IO>

=item L<Moose::Role>

=item L<Moose::Util::TypeConstraints>

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

Copyright (c) 2010 Peter Flanigan. All rights reserved

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
