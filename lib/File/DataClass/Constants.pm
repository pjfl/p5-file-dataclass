# @(#)$Ident: Constants.pm 2013-05-01 19:39 pjf ;

package File::DataClass::Constants;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.19.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Moose;
use MooseX::ClassAttribute;
use MooseX::Types -declare => [ q(ExceptionTC) ];
use MooseX::Types::Moose       qw(ClassName);
use File::DataClass::Exception;

subtype ExceptionTC, as ClassName,
   where   { $_->can( q(throw) ) },
   message { "Class ${_} is not loaded or has no throw method" };

class_has 'Exception_Class' => is => 'rw', isa => ExceptionTC,
   default                  => q(File::DataClass::Exception);

my @constants;

BEGIN {
   @constants = ( qw(ARRAY CODE CYGWIN EVIL EXCEPTION_CLASS EXTENSIONS FALSE
                     HASH LANG LOCALIZE NO_UMASK_STACK NUL PERMS SPC
                     STAT_FIELDS TRUE) );
}

use Sub::Exporter::Progressive -setup => {
   exports => [ @constants ], groups => { default => [ @constants ], },
};

sub ARRAY    () { q(ARRAY)    }
sub CODE     () { q(CODE)     }
sub CYGWIN   () { q(cygwin)   }
sub EVIL     () { q(mswin32)  }
sub FALSE    () { 0           }
sub HASH     () { q(HASH)     }
sub LANG     () { q(en)       }
sub LOCALIZE () { q([_)       }
sub NUL      () { q()         }
sub PERMS    () { oct q(0660) }
sub SPC      () { q( )        }
sub TRUE     () { 1           }

sub EXCEPTION_CLASS () { __PACKAGE__->Exception_Class }
sub EXTENSIONS      () { { '.json' => [ q(JSON) ],
                           '.xml'  => [ q(XML::Simple), q(XML::Bare) ], } }
sub NO_UMASK_STACK  () { -1 }
sub STAT_FIELDS     () { qw(device inode mode nlink uid gid device_id
                            size atime mtime ctime blksize blocks) }

__PACKAGE__->meta->make_immutable;

no MooseX::ClassAttribute;
no Moose::Util::TypeConstraints;

1;

__END__

=pod

=head1 Name

File::DataClass::Constants - Definitions of constant values

=head1 Version

This document describes version v0.19.$Rev: 1 $

=head1 Synopsis

   use File::DataClass::Constants;

   my $bool = TRUE;

=head1 Description

Exports a list of subroutines each of which returns a constants value

=head1 Subroutines/Methods

=head2 C<ARRAY>

String ARRAY

=head2 C<CODE>

String CODE

=head2 C<CYGWIN>

The devil's spawn with compatibility library loaded

=head2 C<EVIL>

The devil's spawn

=head2 C<EXCEPTION_CLASS>

The class to use when throwing exceptions

=head2 C<EXTENSIONS>

Hash ref that map filename extensions (keys) onto storage subclasses (values)

=head2 C<FALSE>

Digit 0

=head2 C<HASH>

String HASH

=head2 C<LANG>

Default language code, C<en>

=head2 C<LOCALIZE>

The character sequence that introduces a localization substitution
parameter. Left square bracket underscore

=head2 C<NO_UMASK_STACK>

Prevent the IO object from pushing and restoring umasks by pushing this
value onto the I<_umask> array ref attribute

=head2 C<NUL>

Empty string

=head2 C<PERMS>

Default file creation permissions

=head2 C<SPC>

Space character

=head2 C<STAT_FIELDS>

The list of fields returned by the core C<stat> function

=head2 C<TRUE>

Digit 1

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<MooseX::ClassAttribute>

=item L<Sub::Exporter>

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
