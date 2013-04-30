# @(#)Ident: Simple.pm 2013-04-30 21:47 pjf ;

package File::DataClass::Exception::Simple;

use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.18.%d', q$Rev: 4 $ =~ /\d+/gmx );

use Moose;

extends q(File::DataClass::Exception);
with    q(File::DataClass::TraitFor::ThrowingExceptions);
with    q(File::DataClass::TraitFor::TracingStacks);
with    q(File::DataClass::TraitFor::PrependingErrorLeader);

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf8

=head1 Name

File::DataClass::Exception::Simple - Applies roles to base class

=head1 Synopsis

   use File::DataClass::Exception::Simple;

   File::DataClass::Exception::Simple->throw 'Die in a pit of fire';

=head1 Version

This documents version v0.18.$Rev: 4 $ of L<File::DataClass::Exception::Simple>

=head1 Description

Applies exception roles to the exception base class
L<File::DataClass::Exception>. See L</Dependencies> for the list of
roles that are applied

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<namespace::autoclean>

=item L<File::DataClass::Exception>

=item L<File::DataClass::TraitFor::ThrowingExceptions>

=item L<File::DataClass::TraitFor::TracingStacks>

=item L<File::DataClass::TraitFor::PrependingErrorLeader>

=item L<Moose>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

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
