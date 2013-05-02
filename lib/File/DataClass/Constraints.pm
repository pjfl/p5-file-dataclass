# @(#)$Ident: Constraints.pm 2013-04-30 01:31 pjf ;

package File::DataClass::Constraints;

use strict;
use warnings;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.19.%d', q$Rev: 1 $ =~ /\d+/gmx );

use MooseX::Types -declare => [ qw(Cache DummyClass HashRefOfBools Lock Path
                                   Directory File OctalNum Result Symbol) ];
use MooseX::Types::Moose        qw(ArrayRef CodeRef HashRef Object Str Undef);
use File::DataClass::IO ();
use Scalar::Util qw(blessed dualvar);

subtype Cache, as Object,
   where   { $_->isa( q(File::DataClass::Cache) ) || $_->isa( q(Class::Null) )},
   message {
      'Object '.(blessed $_ || $_).' is not of class File::DataClass::Cache'
   };

subtype DummyClass, as Str,
   where   { $_ eq q(none) }, message { "Class ${_} is not 'none'" };

subtype HashRefOfBools, as HashRef;

coerce HashRefOfBools, from ArrayRef,
   via     { my %hash = map { $_ => 1 } @{ $_ }; return \%hash; };

subtype Lock, as Object,
   where   { $_->isa( q(Class::Null) )
                or ($_->can( q(set) ) and $_->can( q(reset) ) ) },
   message {
      'Object '.(blessed $_ || $_ || 'undef').' is missing set or reset methods'
   };

subtype OctalNum, as Str, where {
   (my $x = $_.'') =~ s{ [0-7]+ }{}mx; length $x != 0 and return 0;
      ($x = $_.'') =~ s{ \A 0   }{}mx; return $x eq $_ + 0 ? 0 : 1; },
   message { 'Not an octal number '.($_ // '<undef>') };

coerce OctalNum, from Str, via { s{ \A 0 }{}mx; dualvar oct "0${_}", "0${_}" };

subtype Result, as Object,
   where   { $_->isa( q(File::DataClass::Result) ) },
   message {
      'Object '.(blessed $_ || $_).' is not of class File::DataClass::Result'
   };

subtype Path, as Object,
   where   { $_->isa( q(File::DataClass::IO) ) },
   message {
      'Object '.(blessed $_ || $_).' is not of class File::DataClass::IO'
   };

coerce Path,
   from ArrayRef, via { File::DataClass::IO->new( $_ ) },
   from CodeRef,  via { File::DataClass::IO->new( $_ ) },
   from Str,      via { File::DataClass::IO->new( $_ ) },
   from Undef,    via { File::DataClass::IO->new( $_ ) };

subtype Directory, as Path,
   where   { $_->is_dir  },
   message { 'Path '.($_ ? $_.' is not a directory' : 'not specified') };

coerce Directory,
   from ArrayRef, via { File::DataClass::IO->new( $_ ) },
   from CodeRef,  via { File::DataClass::IO->new( $_ ) },
   from Str,      via { File::DataClass::IO->new( $_ ) },
   from Undef,    via { File::DataClass::IO->new( $_ ) };

subtype File, as Path,
   where   { $_->is_file },
   message { 'Path '.($_ ? $_.' is not a file' : 'not specified') };

coerce File,
   from ArrayRef, via { File::DataClass::IO->new( $_ ) },
   from CodeRef,  via { File::DataClass::IO->new( $_ ) },
   from Str,      via { File::DataClass::IO->new( $_ ) },
   from Undef,    via { File::DataClass::IO->new( $_ ) };

no MooseX::Types;

1;

__END__

=pod

=head1 Name

File::DataClass::Constraints - Role defining package constraints

=head1 Version

This document describes version v0.19.$Rev: 1 $

=head1 Synopsis

   use Moose;
   use File::DataClass::Constraints q(Path Directory File);

=head1 Description

Defines the constraints used in this distribution

=head1 Configuration and Environment

Defines these subtypes

=over 3

=item C<Cache>

Is a L<File::DataClass::Cache>

=item C<Exception>

Can C<throw>

=item C<Lock>

Is a L<Class::Null> or can C<set> and C<reset>

=item C<Path>

Is a L<File::DataClass::IO>. Can be coerced from either a string or
an array ref

=item C<Result>

Is a L<File::DataClass::Result>

=item C<Directory>

Subtype of C<Path> which is a directory. Can be coerced from
either a string or an array ref

=item C<File>

Subtype of C<Path> which is a file. Can be coerced from either a
string or an array ref

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::IO>

=item L<MooseX::Types>

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
