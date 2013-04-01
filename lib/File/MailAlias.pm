# @(#)$Id$

package File::MailAlias;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use IPC::Cmd qw( can_run run );
use English  qw( -no_match_vars );
use File::DataClass::Constants;
use File::DataClass::Functions qw(throw);
use File::DataClass::IO ();
use File::Copy;
use File::Spec::Functions qw(catfile);

extends qw(File::DataClass::Schema);

has 'mail_domain'    => is => 'ro', isa => 'Str',
   builder           => '_build_mail_domain', lazy => TRUE;

has 'newaliases'     => is => 'ro', isa => 'ArrayRef',
   default           => sub { [ q(newaliases) ] };

has 'system_aliases' => is => 'ro', isa => 'ArrayRef',
   default           => sub { [ NUL, qw(etc mail aliases) ] };


has 'commit'     => is => 'rw', isa => 'Bool', default => FALSE;

has 'commit_cmd' => is => 'ro', isa => 'ArrayRef',
   default       => sub { [ qw(svn ci -m "Updated") ] };


has 'root_update'       => is => 'rw', isa => 'Bool', default => FALSE;

has 'root_update_cmd'   => is => 'ro', isa => 'Maybe[Str]';

has 'root_update_attrs' => is => 'ro', isa => 'ArrayRef',
   default              => sub { [ qw(-qnc update_mail_aliases) ] };


has '+result_source_attributes' =>
   default           => sub { {
      aliases        => {
         attributes  => [ qw(comment created owner recipients) ],
         defaults    => { comment => [ '-' ], recipients => [] } }, } };

has 'source_name'    => is => 'ro', isa => 'Str', default => q(aliases);

has '+storage_class' =>
   default           => q(+File::MailAlias::Storage);

around 'BUILDARGS' => sub {
   my ($next, $self, $car, @cdr) = @_;

   my $attr = {}; not $car and return $attr;

   if (ref $car eq HASH) { $attr = $car }
   else { $attr->{path} = $car }

   $cdr[ 0 ] and $attr->{system_aliases} = [ $cdr[ 0 ] ];
   $cdr[ 1 ] and $attr->{newaliases    } = [ $cdr[ 1 ] ];

   return $self->$next( $attr );
};

around 'resultset' => sub {
   my ($orig, $self) = @_; return $self->$orig( $self->source_name );
};

{  my $map = {}; my $mtime = 0;

   sub aliases_map {
      my $self = shift; my (undef, $meta) = $self->cache->get( $self->path );

      ($meta and defined $meta->{mtime}) or $meta = { mtime => 1 };
      $meta->{mtime} > $mtime and $mtime = $meta->{mtime}
         and $map = { map { $_ => TRUE } @{ $self->list( 'nobody' )->list } };

      return $map;
   }
}

sub create {
   my ($self, $args) = @_;

   my $name = $self->resultset->create( $args );
   my $out  = $self->_run_update_cmd;

   return ($name, $out);
}

sub delete {
   my ($self, $args) = @_;

   my $name = $self->resultset->delete( $args );
   my $out  = $self->_run_update_cmd;

   return ($name, $out);
}

sub email_address {
   my ($self, $username) = @_; $username or return NUL; my $alias;

   exists $self->aliases_map->{ $username }
      and $alias = $self->find( $username )
      and return $alias->recipients->[ 0 ];

   return $username.q(@).$self->mail_domain;
}

sub find {
   my ($self, $name) = @_; return $self->resultset->find( { name => $name } );
}

sub list {
   my ($self, $name) = @_; return $self->resultset->list( { name => $name } );
}

sub update {
   my ($self, $args) = @_;

   my $name = $self->resultset->update( $args );
   my $out  = $self->_run_update_cmd;

   return ($name, $out);
}

sub update_as_root {
   my $self = shift; my $cmd = shift @{ $self->newaliases };

   $cmd = can_run( $cmd )
      or throw error => 'Path [_1] cannot execute', args => [ $cmd ];

   copy( NUL.$self->path, catfile( @{ $self->system_aliases } ) )
      or throw $ERRNO;

   return $self->_run_cmd( [ $cmd, @{ $self->newaliases } ] );
}

# Private methods

sub _build_mail_domain {
   my $io = File::DataClass::IO->new( [ NUL, qw(etc mailname) ] );

   my $domain; $io->is_file and $domain = $io->chomp->getline;

   return $domain ? $domain : q(localhost);
}

sub _run_update_cmd {
   my $self = shift; my $out = NUL;

   if ($self->commit and $self->commit_cmd) {
      $out .= $self->_run_cmd( [ @{ $self->commit_cmd }, NUL.$self->path ] );
   }

   if ($self->root_update and $self->root_update_cmd) {
      my $cmd  = [ $self->root_update_cmd,
                   @{ $self->root_update_attrs },
                   NUL.$self->path,
                   catfile( @{ $self->system_aliases } ),
                   catfile( @{ $self->newaliases } ) ];

      $out .= $self->_run_cmd( $cmd );
   }

   return $out;
}

sub _run_cmd {
   my ($self, $cmd) = @_; my ($ok, $err, $out) = run( command => $cmd );

   $out and ref $out eq ARRAY and $out = join "\n", @{ $out };
   $ok or throw error => "Could not run [_1] -- [_2]\n[_3]",
                args  => [ $err, $ERRNO, $out ];
   return $out;
}

1;

__END__

=pod

=head1 Name

File::MailAlias - Domain model for the system mail aliases file

=head1 Version

0.15.$Revision$

=head1 Synopsis

   use File::MailAlias;

=head1 Description

Domain model for the system mail aliases file

=head1 Configuration and Environment

Sets these attributes:

=over 3

=item C<system_aliases>

The real mail alias file. Defaults to F</etc/mail/aliases>

=item C<commit>

Boolean indicating whether source code control tracking is being
used. Defaults to C<false>

=item C<path>

Path to the copy of the C<aliases> file that this module works on. Defaults
to C<aliases> in the C<ctrldir>

=item C<prog>

Path to the C<appname>_misc program which is optionally used to
commit changes to the local copy of the aliases file to a source
code control repository

=item C<new_aliases>

Path to the C<newaliases> program that is used to update the MTA
when changes are made

=item C<suid>

Path to the C<suid> root wrapper program that is called to enable update
access to the real mail alias file

=back

=head1 Subroutines/Methods

=head2 BUILD

=head2 aliases_map

   $alias_obj->aliases_map;

Returns a hash ref of aliases. Caches the result and updates automatically
by reading the cache mod time

=head2 create

   $alias_obj->create( { name => $name, fields => $fields } );

Create a new mail alias. Passes the fields to the C<suid> root
wrapper on the command line. The wrapper calls the L</update_as_root> method
to get the job done. Adds the text from the wrapper call to the results
section on the stash

=head2 delete

   $alias_obj->delete( { name => $name } );

Deletes the named mail alias. Calls L</update_as_root> via the C<suid>
wrapper. Adds the text from the wrapper call to the results section on
the stash

=head2 email_address

   $email_address = $alias_obj->email_address( $username );

Takes a user returns a guess as to what the users email address might
be

=head2 find

   $f_dc_element_obj = $alias_obj->list( $name );

Initialises these attributes in the returned object

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

=head2 list

   $f_dc_list_obj = $alias_obj->list( $name );

Returns an object containing a list of alias names and the fields pertaining
to the requested alias if it exists

=head2 update

   $alias_obj->update( { name => $name, fields => $fields } );

Update an existing mail alias. Calls L</update_as_root> via the
C<suid> wrapper

=head2 update_as_root

   $alias_obj->update_as_root( $alias, $recipients, $owner, $comment );

Called from the C<suid> root wrapper this method updates the local copy
of the alias file as required and then copies the changed file to the
real system alias file. It will also run the C<newaliases> program and
commit the changes to a source code control system if one is being used

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass>

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
