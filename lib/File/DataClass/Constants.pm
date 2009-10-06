# @(#)$Id$

package File::DataClass::Constants;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );

my @constants;

BEGIN {
 @constants = ( qw(ARRAY CODE FALSE HASH LSB NUL SPC TRUE) );
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

sub FALSE () {
   return 0;
}

sub HASH () {
   return q(HASH);
}

sub LSB () {
   return q([);
}

sub NUL () {
   return q();
}

sub SPC () {
   return q( );
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

0.4.$Rev$

=head1 Synopsis

   use File::DataClass::Constants;

   my $bool = TRUE;

=head1 Description

Exports a list of subroutines each of which returns a constants value

=head1 Subroutines/Methods

=head2 ACCESS_OK

Access to an action has been granted

=head2 ACCESS_NO_UGRPS

No list of users/groups for selected action

=head2 ACCESS_UNKNOWN_USER

The current user is unknown and anonymous access is not allowed

=head2 ACCESS_DENIED

Access to the selected action for this user is denied

=head2 ACTION_OPEN

Then action is available

=head2 ACTION_HIDDEN

The action is available but does not appear in the navigation menus

=head2 ACTION_CLOSED

The action is not available

=head2 ARRAY

String ARRAY

=head2 BRK

Separate leader (: ) from message

=head2 CODE

String CODE

=head2 DEFAULT_ACTION

All controllers should implement this method as a redirect

=head2 DOTS

Multiple dots ....

=head2 FALSE

Digit 0

=head2 GT

=head2 HASH

String HASH

=head2 HASH_CHAR

Hash character

=head2 LANG

Default language code

=head2 LSB

Left square bracket

=head2 NUL

Empty string

=head2 ROOT

Root namespace symbol

=head2 SEP

Slash (/) character

=head2 SPC

Space character

=head2 TRUE

Digit 1

=head2 TTS

Help tips title separator string

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
