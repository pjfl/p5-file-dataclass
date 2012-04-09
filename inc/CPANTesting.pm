# @(#)$Id$

package CPANTesting;

use strict;
use warnings;

my $uname = qx(uname -a);

sub broken_toolchain {
   return 0;
}

sub exceptions {
   lc $^O eq q(cygwin)      and return 'Cygwin not supported';
   lc $^O eq q(mirbsd)      and return 'Mirbsd not supported';
   lc $^O eq q(mswin32)     and return 'Mswin  not supported';
   lc $^O eq q(netbsd)      and return 'Netbsd not supported';
   $uname =~ m{ slack64 }mx and return 'Stopped Bingos slack64';
   return 0;
}

1;

__END__
