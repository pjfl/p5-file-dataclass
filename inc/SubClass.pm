# @(#)Ident: SubClass.pm 2013-03-27 23:41 pjf ;
# Bob-Version: 1.8

use Pod::Select;

sub ACTION_distmeta {
   my $self = shift;

   $self->notes->{create_readme_md} and $self->_create_readme_md();

   $self->notes->{create_readme_pod} and podselect( {
      -output => q(README.pod) }, $self->dist_version_from );

   return $self->SUPER::ACTION_distmeta;
}

# Private methods

sub _create_readme_md {
   print "Creating README.md using Pod::Markdown\n"; require Pod::Markdown;

   my $self   = shift;
   my $parser = Pod::Markdown->new;
   my $path   = $self->dist_version_from;

   open my $in,  '<', $path       or die "Path ${path} cannot open: ${!}";
   open my $out, '>', 'README.md' or die "File README.md cannot open: ${!}";
   $parser->parse_from_filehandle( $in );
   print {$out} $parser->as_markdown;
   close $in; close $out;
   return;
}
