# @(#)$Id$

package File::DataClass::Constants;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.6.%d', q$Rev$ =~ /\d+/gmx );

my @constants;

BEGIN {
   @constants = ( qw(ARRAY CODE EVIL FALSE HASH LANG LOCALIZE NO_UMASK_STACK
                     NUL PERMS SPC STAT_FIELDS TRUE) );
}

use Sub::Exporter -setup => {
   exports => [ @constants ], groups => { default => [ @constants ], },
};

sub ARRAY () {
   return q(ARRAY);
}

sub CODE () {
   return q(CODE);
}

sub EVIL () {
   return q(MSWin32);
}

sub FALSE () {
   return 0;
}

sub HASH () {
   return q(HASH);
}

sub LANG () {
   return q(en);
}

sub LOCALIZE () {
   return q([_);
}

sub NO_UMASK_STACK () {
   return -1;
}

sub NUL () {
   return q();
}

sub PERMS () {
   return oct q(0660);
}

sub SPC () {
   return q( );
}

sub STAT_FIELDS () {
   return qw(device inode mode nlink uid gid device_id size atime
             mtime ctime blksize blocks);
}

sub TRUE () {
   return 1;
}

1;

__END__

=pod

=head1 Name

File::DataClass::Constants - Definitions of constant values

=head1 Version

0.6.$Rev$

=head1 Synopsis

   use File::DataClass::Constants;

   my $bool = TRUE;

=head1 Description

Exports a list of subroutines each of which returns a constants value

=head1 Subroutines/Methods

=head2 ARRAY

String ARRAY

=head2 CODE

String CODE

=head2 EVIL

The devil's spawn

=head2 FALSE

Digit 0

=head2 HASH

String HASH

=head2 LANG

Default language code, en

=head2 LOCALIZE

The character sequence that introduces a localization substitution
parameter. Left square bracket underscore

=head2 NO_UMASK_STACK

Prevent the IO object from pushing and restoring umasks by pushing this
value onto the I<_umask> array ref attribute

=head2 NUL

Empty string

=head2 PERMS

Default file creation permissions

=head2 SPC

Space character

=head2 STAT_FIELDS

The list of fields returned by the core C<stat> function

=head2 TRUE

Digit 1

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

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
