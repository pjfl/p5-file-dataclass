# @(#)$Id$

package CPANTesting;

use strict;
use warnings;

my $uname = qx(uname -a);

sub broken {
   $uname     =~ m{ bandsman       }mx and return 'Stopped Horne';
   $uname     =~ m{ higgsboson     }mx and return 'Stopped dcollins';
   $uname     =~ m{ profvince.com  }mx and return 'Stopped vpit';
   $ENV{PATH} =~ m{ \A /home/sand  }mx and return 'Stopped Konig';
   ($ENV{PERL5LIB} || q()) =~ m{ /home/cpan/pit }mx and return 'Stopped Bingos';
   return 0;
}

1;

__END__
