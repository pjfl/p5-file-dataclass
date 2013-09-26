# @(#)$Ident: Constants.pm 2013-09-13 17:19 pjf ;

package File::DataClass::Constants;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.26.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Exporter 5.57 qw( import );
use File::DataClass::Exception;

our @EXPORT = qw( ARRAY CODE CURDIR CYGWIN EVIL EXCEPTION_CLASS EXTENSIONS
                  FALSE HASH LANG LOCALIZE NO_UMASK_STACK NUL PERMS SPC
                  STAT_FIELDS TILDE TRUE );

my $Exception_Class = 'File::DataClass::Exception';

sub ARRAY    () { q(ARRAY)    }
sub CODE     () { q(CODE)     }
sub CURDIR   () { q(.)        }
sub CYGWIN   () { q(cygwin)   }
sub EVIL     () { q(mswin32)  }
sub FALSE    () { 0           }
sub HASH     () { q(HASH)     }
sub LANG     () { q(en)       }
sub LOCALIZE () { q([_)       }
sub NUL      () { q()         }
sub PERMS    () { oct q(0660) }
sub SPC      () { q( )        }
sub TILDE    () { q(~)        }
sub TRUE     () { 1           }

sub EXCEPTION_CLASS () { __PACKAGE__->Exception_Class }
sub EXTENSIONS      () { { '.json' => [ q(JSON) ],
                           '.xml'  => [ q(XML::Simple), q(XML::Bare) ], } }
sub NO_UMASK_STACK  () { -1 }
sub STAT_FIELDS     () { qw( device inode mode nlink uid gid device_id
                             size atime mtime ctime blksize blocks ) }

sub Exception_Class {
   my ($self, $class) = @_; defined $class or return $Exception_Class;

   $class->can( q(throw) )
       or die "Class ${class} is not loaded or has no throw method";

   return $Exception_Class = $class;
}

1;

__END__

=pod

=head1 Name

File::DataClass::Constants - Definitions of constant values

=head1 Version

This document describes version v0.26.$Rev: 1 $

=head1 Synopsis

   use File::DataClass::Constants;

   my $bool = TRUE;

=head1 Description

Exports a list of subroutines each of which returns a constants value

=head1 Subroutines/Methods

=head2 Exception_Class

Class method. An accessor/mutator for the classname returned by the
L</EXCEPTION_CLASS> method

=head2 C<ARRAY>

String ARRAY

=head2 C<CODE>

String CODE

=head2 C<CURDIR>

Symbol representing the current working directory. A dot

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

=head2 C<TILDE>

The (~) tilde character

=head2 C<TRUE>

Digit 1

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<Exporter>

=item L<File::DataClass::Exception>

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
