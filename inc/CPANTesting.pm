# @(#)$Id$

package CPANTesting;

use strict;
use warnings;

my $osname = lc $^O; my $uname = qx(uname -a);

sub should_abort {
   return 0;
}

sub test_exceptions {
   my $p = shift; __is_testing() or return 0;

   $p->{stop_tests} and return 'CPAN Testing stopped in Build.PL';

   $osname eq q(mirbsd) and return 'Mirbsd OS unsupported';
   return 0;
}

# Private functions

sub __is_testing { !! ($ENV{AUTOMATED_TESTING} || $ENV{PERL_CR_SMOKER_CURRENT}
                   || ($ENV{PERL5OPT} || q()) =~ m{ CPAN-Reporter }mx) }

1;

__END__
