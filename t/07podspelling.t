# @(#)Ident: 07podspelling.t 2013-07-04 13:26 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.22.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions qw(catdir catfile updir);
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   $ENV{AUTHOR_TESTING}
      or plan skip_all => 'POD spelling test only for developers';
}

eval "use Test::Spelling";

$EVAL_ERROR and plan skip_all => 'Test::Spelling required but not installed';

$ENV{TEST_SPELLING}
   or plan skip_all => 'Environment variable TEST_SPELLING not set';

my $checker = has_working_spellchecker(); # Aspell is prefered

if ($checker) { warn "Check using ${checker}\n" }
else { plan skip_all => 'No OS spell checkers found' }

add_stopwords( <DATA> );

all_pod_files_spelling_ok();

done_testing();

# Local Variables:
# mode: perl
# tab-width: 3
# End:

__DATA__
flanigan
ingy
appendln
autoclose
api
buildargs
canonpath
classname
cwd
datetime
dir
dirname
dtd
extn
filename
filenames
filepath
getline
getlines
gettext
io
json
mealmaster
metadata
mkpath
mta
NTFS
namespace
nulled
oo
pathname
Prepends
println
resultset
rmtree
splitdir
splitpath
stacktrace
stringifies
subdirectories
utf
or'ed
resultset's
