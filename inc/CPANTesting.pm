# @(#)$Id$

package CPANTesting;

use strict;
use warnings;

my $osname = lc $^O; my $uname = qx(uname -a);

sub broken_toolchain {
   return 0;
}

sub exceptions {
   $osname eq q(cygwin)     and return 'Cygwin OS unsupported';
   $osname eq q(mirbsd)     and return 'Mirbsd OS unsupported';
   $osname eq q(mswin32)    and return 'Mswin  OS unsupported';
   $osname eq q(netbsd)     and return 'Netbsd OS unsupported';
   $uname =~ m{ slack64 }mx and return 'Stopped Bingos slack64';
   return 0;
}

1;

__END__
