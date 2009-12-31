# @(#)$Id$

package File::MealMaster::ResultSet;

use strict;
use namespace::clean -except => 'meta';
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Data::Section -setup;
use File::DataClass::Constants;
use Moose;

extends qw(File::DataClass::ResultSet);

has 'render_template' => is => 'ro', isa => 'Str', lazy_build => TRUE;

sub make_key {
   my ($self, $title) = @_; return $self->storage->make_key( $title );
}

sub render {
   my ($self, $recipe) = @_;

   my $storage       = $self->storage;
   my $template_data = $self->render_template;
   my $buffer        = NUL;

   $storage->template->process( \$template_data, $recipe, \$buffer )
      or $buffer = $storage->template->error;

   return $buffer;
}

# Private methods

sub _build_render_template {
   return ${ __PACKAGE__->section_data( q(render_template) ) };
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

=pod

=head1 Name

File::MealMaster::ResultSet - MealMaster food recipes custom result set

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use File::MealMaster::ResultSet;

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 add_user_to_group

=head2 remove_user_from_group

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<File::DataClass::ResultSet>

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

__DATA__
__[ render_template ]__
<table class="recipe">
   <tr><td class="label">Title</td><td>[% title %]</td></tr>
   <tr><td class="label">Categories</td><td>
	   [% FOREACH category IN categories %][% category %] | [% END %]</td></tr>
   <tr><td class="label">Yield</td><td>[% yield %]</td></tr>
	<tr><td class="label">Ingredients</td><td><table class="recipe">
   [% FOREACH ingredient IN ingredients %]
     <tr><td nowrap="1" width="1%">[% ingredient.quantity %]</td>
         <td width="1%">[% ingredient.measure %]</td>
        <td>[% ingredient.product %]</td></tr>
   [% END %]</table></td></tr>
   <tr><td class="label">Directions</td>
     <td>[% directions | html_line_break %]</td></tr>
</table>
