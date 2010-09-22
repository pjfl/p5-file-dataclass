# @(#)$Id$

package File::MealMaster::Result;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Data::Section -setup;
use File::DataClass::Constants;
use Moose;

extends qw(File::DataClass::Result);

has '_render_template' => is => 'rw', isa => 'Str', lazy_build => TRUE;

sub render {
   my $self          = shift;
   my $template      = $self->_storage->template;
   my $template_data = $self->_render_template;
   my $buffer        = NUL;

   $template->process( \$template_data, $self, \$buffer )
      or $buffer = $template->error;

   return $buffer;
}

# Private methods

sub _build__render_template {
   my $self = shift; return ${ $self->section_data( q(render_template) ) };
}

no Moose;

1;

=pod

=head1 Name

File::MealMaster::Result - MealMaster food recipes custom methods

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::MealMaster::Result;

=head1 Description

Adds custom methods to the recipe result class

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 render

Return the HTML representation of this recipe. Uses the internal template
in the data block at the end of this file

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Data::Section>

=item L<File::DataClass::Result>

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

__DATA__
__[ render_template ]__
<table class="recipe">
   <tr><td class="label">Title</td><td>[% title | html %]</td></tr>
   <tr><td class="label">Categories</td><td>
	   [% FOREACH category IN categories %][% category | html %] | [% END %]
   </td></tr>
   <tr><td class="label">Yield</td><td>[% yield | html %]</td></tr>
	<tr><td class="label">Ingredients</td><td><table class="recipe">
   [% FOREACH ingredient IN ingredients %]
     <tr><td class="nowrap" width="1%">[% ingredient.quantity | html %]</td>
         <td width="1%">[% ingredient.measure | html %]</td>
        <td>[% ingredient.product | html %]</td></tr>
   [% END %]</table></td></tr>
   <tr><td class="label">Directions</td>
     <td>[% directions | html | html_line_break %]</td></tr>
</table>
