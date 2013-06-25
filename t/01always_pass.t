# @(#)Ident: 01always_pass.t 2013-05-19 12:02 pjf ;

use strict;
use warnings;

use Module::Build;
use Sys::Hostname;

my $osname  = lc $^O;
my $host    = lc hostname;
my $current = eval { Module::Build->current };
my $notes   = {}; $current and $notes = $current->notes || {};
my $version = defined $notes->{version} ? $notes->{version} : '< 1.6';

$notes->{is_cpan_testing}
   and warn "OS: ${osname}, Host: ${host}, Bob-Version: ${version}\n";

print "1..1\n";
print "ok\n";
exit 0;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
