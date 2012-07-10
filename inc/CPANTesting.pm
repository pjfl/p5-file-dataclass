# @(#)$Id$

package CPANTesting;

use strict;
use warnings;

my $osname = lc $^O; my $uname = qx(uname -a);

sub broken_toolchain {
   return 0;
}

sub exceptions {
   $osname eq q(cygwin)     and return 'Cygwin not supported';
   $osname eq q(mirbsd)     and return 'Mirbsd not supported';
   $osname eq q(mswin32)    and return 'Mswin  not supported';
   $osname eq q(netbsd)     and return 'Netbsd not supported';
   $uname =~ m{ slack64 }mx and return 'Stopped Bingos slack64';
   return 0;
}

1;

__END__
