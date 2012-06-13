# @(#)$Id$

package File::Gettext;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.10.%d', q$Rev$ =~ /\d+/gmx );

use Moose;
use Moose::Util::TypeConstraints;
use English qw(-no_match_vars);
use File::DataClass::Constants;
use File::DataClass::Constraints qw(Directory);
use File::DataClass::Functions   qw(throw);
use File::DataClass::IO;
use File::Gettext::Constants;
use File::Spec::Functions        qw(catfile tmpdir);

extends qw(File::DataClass::Schema);

subtype 'File::DataClass::Localedir', as Directory;

coerce 'File::DataClass::Localedir' =>
   from 'ArrayRef' => via { __build_localedir( $_ ) },
   from 'Str'      => via { __build_localedir( $_ ) },
   from 'Undef'    => via { __build_localedir( $_ ) };

has 'catagory_name'     => is => 'ro', isa => 'Str', default => q(LC_MESSAGES);
has 'charset'           => is => 'ro', isa => 'Str', default => q(iso-8859-1);
has 'default_po_header' => is => 'ro', isa => 'HashRef',
   default              => sub { {
      appname           => 'Your_Application',
      company           => 'ExampleCom',
      email             => '<translators@example.com>',
      lang              => 'en',
      team              => 'Translators',
      translator        => 'Athena', } };
has 'header_key_table'  => is => 'ro', isa => 'HashRef',
   default              => sub { {
      project_id_version        => [ 0,  q(Project-Id-Version)        ],
      report_msgid_bugs_to      => [ 1,  q(Report-Msgid-Bugs-To)      ],
      pot_creation_date         => [ 2,  q(POT-Creation-Date)         ],
      po_revision_date          => [ 3,  q(PO-Revision-Date)          ],
      last_translator           => [ 4,  q(Last-Translator)           ],
      language_team             => [ 5,  q(Language-Team)             ],
      language                  => [ 6,  q(Language)                  ],
      mime_version              => [ 7,  q(MIME-Version)              ],
      content_type              => [ 8,  q(Content-Type)              ],
      content_transfer_encoding => [ 9,  q(Content-Transfer-Encoding) ],
      plural_forms              => [ 10, q(Plural-Forms)              ], } };
has 'localedir'         => is => 'ro', isa => 'File::DataClass::Localedir',
   default              => NUL, coerce => TRUE;
has '+result_source_attributes' =>
   default           => sub { {
      mo             => {
         attributes  => [ qw(msgid_plural msgstr) ],
         defaults    => { msgstr => [], }, },
      po             => {
         attributes  =>
            [ qw(translator_comment extracted_comment reference flags
                 previous msgctxt msgid msgid_plural msgstr) ],
         defaults    => { 'flags' => [], 'msgstr' => [], },
         label_attr  => q(labels),
      }, } };
has '+storage_class' => default => q(+File::Gettext::Storage::PO);
has 'source_name'    => is => 'ro', isa => enum( [ qw(mo po) ] ),
   default           => q(po), trigger => \&_set_storage_class;

around 'source' => sub {
   my ($next, $self) = @_; return $self->$next( $self->source_name );
};

around 'resultset' => sub {
   my ($next, $self) = @_; return $self->$next( $self->source_name );
};

around 'load' => sub {
   my ($next, $self, $lang, @names) = @_;

   my @paths     = grep { $self->_is_file_or_log_debug( $_ ) }
                   map  { $self->_get_path_io( $lang, $_ ) } @names;
   my $data      = $self->$next( @paths );
   my $po_header = exists $data->{po_header}
                 ? $data->{po_header}->{msgstr} || {} : {};
   my $plural_func;

   # This is here because of the code ref. Cannot serialize (cache) a code ref
   # Determine plural rules. The leading and trailing space is necessary
   # to be able to match against word boundaries.
   if (exists $po_header->{plural_forms}) {
      my $code = SPC.$po_header->{plural_forms}.SPC;

      $code =~ s{ ([^_a-zA-Z0-9] | \A) ([_a-z][_A-Za-z0-9]*)
                     ([^_a-zA-Z0-9]) }{$1\$$2$3}gmsx;
      $code = "sub { my \$n = shift; my (\$plural, \$nplurals);
                     $code;
                     return (\$nplurals, \$plural ? \$plural : 0); }";

      # Now try to evaluate the code. There is no need to run the code in
      # a Safe compartment. The above substitutions should have destroyed
      # all evil code. Corrections are welcome!
      $plural_func = eval $code; ## no critic
      $EVAL_ERROR and $plural_func = undef;
   }

   # Default is Germanic plural (which is incorrect for French).
   $data->{plural_func} = $plural_func || sub { (2, shift > 1) };

   return $data;
};

sub get_path {
   my ($self, $lang, $file) = @_;

   $lang or throw 'Language not specified';
   $file or throw 'Language file path not specified';

   return catfile( $self->localedir, $lang,
                   $self->catagory_name, $file.$self->storage->extn );
}

sub set_path {
   my ($self, @rest) = @_; return $self->path( $self->_get_path_io( @rest ) );
}

# Private methods

sub _get_path_io {
   return io( $_[ 0 ]->get_path( $_[ 1 ], $_[ 2 ] ) );
}

sub _is_file_or_log_debug {
   my ($self, $path) = @_; $path->is_file and return TRUE;

   $self->debug and $self->log->debug( 'Path '.$path->pathname.' not found' );

   return FALSE;
}

sub _set_storage_class {
   my $self = shift;

   $self->source_name eq q(mo)
      and $self->storage_class( q(+File::Gettext::Storage::MO) );

   return;
}

# Private functions

sub __build_localedir {
   my $dir = shift; my $io;

   $dir and $io = io( $dir ) and $io->is_dir and return $io;

   for $dir (map { io( $_ ) } @{ DIRECTORIES() }) {
      $dir->is_dir and return $dir;
   }

   return io( tmpdir() );
}

__PACKAGE__->meta->make_immutable;

no Moose::Util::TypeConstraints;
no Moose;

1;

__END__

=pod

=head1 Name

File::Gettext - Read and write GNU gettext po/mo files

=head1 Version

0.10.$Revision$

=head1 Synopsis

   use File::Gettext;

=head1 Description

=head1 Subroutines/Methods

=head2 get_path

   $gettext->get_path( $lang, $file );

Returns the path to the po/mo file for the specified language

=head2 set_path

   $gettext->set_path( $lang, $file );

Sets the I<path> attribute on the parent class from C<$lang> and C<$file>

=head1 Configuration and Environment

=head1 Diagnostics

=head1 Dependencies

=over 3

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

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2011 Peter Flanigan. All rights reserved

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
