# @(#)$Id$

package CatalystX::Usul::MailAliases;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(CatalystX::Usul::File);

use CatalystX::Usul::Constants;
use English qw(-no_match_vars);
use File::Copy;
use MRO::Compat;

__PACKAGE__->config( cmd_suffix        => q(_cli),
                     commit            => FALSE,
                     file              => q(aliases),
                     newaliases        => q(newaliases),
                     schema_attributes => {
                        attributes     =>
                           [ qw(comment created owner recipients) ],
                        defaults       => {},
                        element        => q(aliases),
                        lang_dep       => FALSE,
                        storage_class  => q(MailAlias), },
                     system_aliases    => q(/etc/mail/aliases), );

__PACKAGE__->mk_accessors( qw(cmd_suffix commit commit_cmd file newaliases
                              system_aliases update_cmd) );

sub new {
   my ($self, $app, $config) = @_;

   my $ac   = $app->config || {};
   my $new  = $self->next::method( $app, $config );
   my $path = $self->catfile( $ac->{ctrldir}, $new->file );
   my $cmd  = $self->catfile( $ac->{binsdir}, $ac->{prefix}.$new->cmd_suffix );

   $new->commit_cmd( $new->commit_cmd || "$cmd -n -c vcs -- commit" );
   $new->path      ( $new->path       || $path                      );
   $new->update_cmd( $new->suid.' -n -c update_mail_aliases'        );

   return $new;
}

sub create {
   my ($self, $args) = @_;

   my $name = $self->next::method( $args );
   my $out  = $self->_run_update_cmd;

   return $name;
}

sub delete {
   my ($self, $args) = @_;

   my $name = $self->next::method( $args );
   my $out  = $self->_run_update_cmd;

   return $name;
}

sub update {
   my ($self, $args) = @_;

   my $name = $self->next::method( $args );
   my $out  = $self->_run_update_cmd;

   return $name;
}

sub update_as_root {
   my $self = shift; my $out = NUL;

   if (-x $self->newaliases) {
      unless (copy( $self->path, $self->system_aliases )) {
         $self->throw( $ERRNO );
      }

      $out .= $self->run_cmd( $self->newaliases, { err => q(out) } )->out;
   }

   return $out;
}

# Private methods

sub _run_update_cmd {
   my $self = shift; my $out = NUL;

   if ($self->commit) {
      my $cmd = $self->commit_cmd.SPC.$self->path;

      $out .= $self->run_cmd( $cmd, { err => q(out) } )->out;
   }

   if ($self->newaliases) {
      $out .= $self->run_cmd( $self->update_cmd, { err => q(out) } )->out;
   }

   return $out;
}

1;

__END__

=pod

=head1 Name

CatalystX::Usul::MailAliases - Manipulate the mail aliases file

=head1 Version

0.4.$Revision$

=head1 Synopsis

   use CatalystX::Usul::MailAliases;

   $alias_obj = CatalystX::Usul::MailAliases->new( $app, $config );

=head1 Description

Management model file the system mail alias file

=head1 Subroutines/Methods

=head2 new

Sets these attributes:

=over 3

=item system_aliases

The real mail alias file. Defaults to F</etc/mail/aliases>

=item commit

Boolean indicating whether source code control tracking is being
used. Defaults to I<false>

=item path

Path to the copy of the I<aliases> file that this module works on. Defaults
to I<aliases> in the I<ctrldir>

=item prog

Path to the I<appname>_misc program which is optionally used to
commit changes to the local copy of the aliases file to a source
code control repository

=item new_aliases

Path to the C<newaliases> program that is used to update the MTA
when changes are made

=item suid

Path to the C<suid> root wrapper program that is called to enable update
access to the real mail alias file

=back

=head2 create

   $alias_obj->create( $fields );

Create a new mail alias. Passes the fields to the C<suid> root
wrapper on the command line. The wrapper calls the L</update_as_root> method
to get the job done. Adds the text from the wrapper call to the results
section on the stash

=head2 delete

   $alias_obj->delete( $name );

Deletes the named mail alias. Calls L</update_as_root> via the C<suid>
wrapper. Adds the text from the wrapper call to the results section on
the stash

=head2 retrieve

   $response_obj = $alias_obj->retrieve( $name );

Returns an object containing a list of alias names and the fields pertaining
to the requested alias if it exists

=head2 update

   $alias_obj->update( $fields );

Update an existing mail alias. Calls L</update_as_root> via the
C<suid> wrapper

=head2 update_as_root

   $alias_obj->update_as_root( $alias, $recipients, $owner, $comment );

Called from the C<suid> root wrapper this method updates the local copy
of the alias file as required and then copies the changed file to the
real system alias file. It will also run the C<newaliases> program and
commit the changes to a source code control system if one is being used

=head2 _init

Initialises these attributes in the object returned by
L<CatalystX::Usul::File/find>

=over 3

=item aliases

List of alias names

=item comment

Creation comment associated with the selected alias

=item created

Date the selected alias was created

=item owner

Who created the selected alias

=item recipients

List of recipients for the selected owner

=back

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<CatalystX::Usul::File>

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

Copyright (c) 2008 Peter Flanigan. All rights reserved

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
