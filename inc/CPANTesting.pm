# @(#)$Id$

package CPANTesting;

use strict;
use warnings;

my $uname = qx(uname -a);

sub broken_toolchain {
   $ENV{PATH} =~ m{ \A /home/sand }mx and return 'Stopped Konig';
   $uname     =~ m{ bandsman      }mx and return 'Stopped Horne';
   return 0;
}

sub exceptions {
   $uname =~ m{ higgsboson    }mx and return 'Stopped dcollins';
   $uname =~ m{ profvince.com }mx and return 'Stopped vpit';
   $uname =~ m{ fremen        }mx and return 'Stopped bingos';
   $uname =~ m{ nexus         }mx and return 'Stopped bingos';
   $uname =~ m{ oatcake       }mx and return 'Stopped bingos';
   $uname =~ m{ oliphant      }mx and return 'Stopped bingos';
   $uname =~ m{ slack64       }mx and return 'Stopped bingos';
   return 0;
}

1;

__END__
