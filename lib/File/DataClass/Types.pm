# @(#)$Ident: Types.pm 2013-06-30 00:42 pjf ;

package File::DataClass::Types;

use strict;
use warnings;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.24.%d', q$Rev: 1 $ =~ /\d+/gmx );

use File::DataClass::IO;
use Scalar::Util            qw( blessed dualvar );
use Type::Library               -base, -declare =>
                            qw( Cache DummyClass HashRefOfBools Lock
                                OctalNum Result Path Directory File );
use Type::Utils             qw( as coerce extends from
                                message subtype via where );
use Unexpected::Functions   qw( inflate_message );

BEGIN { extends q(Unexpected::Types) };

subtype Cache, as Object,
   where   { $_->isa( 'File::DataClass::Cache' ) or $_->isa( 'Class::Null' ) },
   message { __exception_message_for_cache( $_ ) };

subtype DummyClass, as Str,
   where   { $_ eq q(none) },
   message { inflate_message( 'Dummy class [_1] is not "none"', $_ ) };

subtype HashRefOfBools, as HashRef;

subtype Lock, as Object,
   where   { ($_->can( 'set' ) and $_->can( 'reset' ) )
                                or $_->isa( 'Class::Null' ) },
   message { __exception_message_for_lock( $_ ) };

subtype OctalNum, as Str,
   where   { __constraint_for_octalnum( $_ ) },
   message { inflate_message( 'String [_1] is not an octal number', $_ ) };

subtype Path, as Object,
   where   { $_->isa( 'File::DataClass::IO' ) },
   message { __exception_message_for_path( $_ ) };

subtype Result, as Object,
   where   { $_->isa( 'File::DataClass::Result' ) },
   message { __exception_message_for_result( $_ ) };


subtype Directory, as Path,
   where   { $_->exists and $_->is_dir  },
   message { inflate_message( 'Path [_1] is not a directory', $_ ) };

subtype File, as Path,
   where   { $_->exists and $_->is_file },
   message { inflate_message( 'Path [_1] is not a file', $_ ) };

coerce HashRefOfBools, from ArrayRef,
   via { my %hash = map { $_ => 1 } @{ $_ }; return \%hash; };

coerce OctalNum, from Str,
   via { s{ \A 0 }{}mx; dualvar oct "0${_}", "0${_}" };

coerce Directory,
   from ArrayRef, via { io( $_ ) },
   from CodeRef,  via { io( $_ ) },
   from HashRef,  via { io( $_ ) },
   from Str,      via { io( $_ ) },
   from Undef,    via { io( $_ ) };

coerce File,
   from ArrayRef, via { io( $_ ) },
   from CodeRef,  via { io( $_ ) },
   from HashRef,  via { io( $_ ) },
   from Str,      via { io( $_ ) },
   from Undef,    via { io( $_ ) };

coerce Path,
   from ArrayRef, via { io( $_ ) },
   from CodeRef,  via { io( $_ ) },
   from HashRef,  via { io( $_ ) },
   from Str,      via { io( $_ ) },
   from Undef,    via { io( $_ ) };

# Private functions
sub __constraint_for_octalnum {
   my $x = shift; defined $x or return 0; my $strx;

   ($strx = $x.q()) =~ s{ [0-7]+ }{}mx; length $strx != 0 and return 0;

   ($strx = $x.q()) =~ s{ \A 0   }{}mx; return $strx eq $x + 0 ? 0 : 1;
}

sub __exception_message_for_cache {
   blessed $_[ 0 ] and return inflate_message
      ( 'Object [_1] is not of class File::DataClass::Cache', blessed $_[ 0 ] );

   return __exception_message_for_object_reference( $_[ 0 ] );
}

sub __exception_message_for_lock {
   blessed $_[ 0 ] and return inflate_message
      ( 'Object [_1] is missing set / reset methods', blessed $_[ 0 ] );

   return __exception_message_for_object_reference( $_[ 0 ] );
}

sub __exception_message_for_object_reference {
   return inflate_message( 'String [_1] is not an object reference', $_[ 0 ] );
}

sub __exception_message_for_path {
   blessed $_[ 0 ] and return inflate_message
      ( 'Object [_1] is not of class File::DataClass::IO', blessed $_[ 0 ] );

   return __exception_message_for_object_reference( $_[ 0 ] );
}

sub __exception_message_for_result {
   blessed $_[ 0 ] and return inflate_message
      ( 'Object [_1] is not of class File::DataClass::Result', blessed $_[ 0 ]);

   return __exception_message_for_object_reference( $_[ 0 ] );
}

1;

__END__

=pod

=head1 Name

File::DataClass::Types - Role defining package constraints

=head1 Version

This document describes version v0.24.$Rev: 1 $

=head1 Synopsis

   use Moo;
   use File::DataClass::Types q(Path Directory File);

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

=item L<Type::Tiny>

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
