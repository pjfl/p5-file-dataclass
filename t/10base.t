# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   if ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
       || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) {
      plan skip_all => q(CPAN Testing stopped);
   }

   plan tests => 8;
}

use File::DataClass;

my $file = File::DataClass->new( tempdir => q(t) );

isa_ok( $file, 'File::DataClass' );

my $cfg = eval { $file->load( qw(nonexistant_file) ) };

my $e = $EVAL_ERROR; $EVAL_ERROR = undef;

is( $e, 'Cannot open nonexistant_file', 'Cannot open nonexistant_file' );

$cfg = $file->load( qw(t/default.xml t/default_en.xml) );

ok( $cfg->{ '_cvs_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 1' );
ok( $cfg->{ '_cvs_lang_default' } =~ m{ @\(\#\)\$Id: }mx,
    'Has reference element 2' );
ok( ref $cfg->{levels}->{entrance}->{acl} eq q(ARRAY), 'Detects arrays' );

eval { $file->create }; $e = $EVAL_ERROR; $EVAL_ERROR = undef;

is( $e, 'No element name specified', 'No element name specified' );

my $args = {}; $args->{name} = q(dummy);

eval { $file->create( $args ) }; $e = $EVAL_ERROR; $EVAL_ERROR = undef;

is( $e, 'No file path specified', 'No file path specified' );

$args->{path} = q(t/default.xml);

my $res = $file->create( $args );

ok( defined $res && !$res, 'Creates dummy element but does not insert' );

#$model = $context->model( q(Config::Levels) );

#isa_ok( $model, 'MyApp::Model::Config::Levels' );

#$args->{name} = q(dummy);

#eval { $model->create( $args ) }; $e = $model->catch; $EVAL_ERROR = undef;

#ok ( !$e, 'Creates dummy level' );

#$cfg = $model->load( qw(t/default.xml t/default_en.xml) );

#ok( $cfg->{levels}->{dummy}->{acl}->[0] eq q(any), 'Dummy level defaults' );

#eval { $model->create( $args ) }; $e = $model->catch; $EVAL_ERROR = undef;

#ok( $e->as_string eq 'File [_1] element [_2] already exists',
#    'Detects existing record' );

#eval { $model->delete( $args ) }; $e = $model->catch; $EVAL_ERROR = undef;

#ok ( !$e, 'Deletes dummy level' );

#eval { $model->delete( $args ) }; $e = $model->catch; $EVAL_ERROR = undef;

#ok( $e->as_string eq 'File [_1] element [_2] not deleted',
#    'Detects non existance on delete' );

#my @res = $model->search( q(t/default.xml), { acl => q(@support) } );

#ok( $res[0] && $res[0]->{name} eq q(admin), 'Can search' );

# Local Variables:
# mode: perl
# tab-width: 3
# End:
