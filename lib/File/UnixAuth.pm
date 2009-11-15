# @(#)$Id$

package File::UnixAuth;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;

extends qw(File::DataClass::Schema);

has '+result_source_attributes' =>
   default            => sub { return {
      group           => {
         attributes   => [ qw(password gid members) ],
         defaults     => { password => q(x) }, },
      passwd          => {
         attributes   => [ qw(password id pgid gecos homedir shell) ],
         defaults     => { password => q(x) }, },
      shadow          => {
         attributes   => [ qw(password pwlast pwnext pwafter
                              pwwarn pwexpires pwdisable reserved) ],
         defaults     => { password => q(*),   pwlast => 0, pwnext    => 0,
                           pwafter  => 99_999, pwwarn => 7, pwexpires => 90 },
         }, } };
has '+storage_attributes' =>
   default            => sub { return { backup => q(.bak), } };
has '+storage_class'  =>
   default            => q(+File::UnixAuth::Storage);
has 'source_name'     => is => 'ro', isa => 'Str', required => 1;

around 'source' => sub {
   my ($orig, $self) = @_; return $self->$orig( $self->source_name );
};

around 'resultset' => sub {
   my ($orig, $self) = @_; return $self->$orig( $self->source_name );
};

1;

__END__

=pod

=head1 Name

File::UnixAuth - Result source definitions for the Unix auth files

=head1 Version

0.1.$Revision$

=head1 Synopsis

=head1 Description

=head1 Configuration and Environment

Sets these attributes:

=over 3

=back

=head1 Subroutines/Methods

=head2 group

=head2 passwd

=head2 shadow

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Schema>

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
