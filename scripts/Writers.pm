package Writers;

use strict;
use warnings;

use Data::Dumper;

use POSIX;
use Exporter;

require Utils;  # Must use require, to get INC updated
import Utils qw( &get_progname &get_progpath );

BEGIN {
    @Writers::ISA = ('Exporter');
    @Writers::EXPORT_OK = qw( &write_xlc );
}


# Export XLC format
sub write_xlc()
{
    my ($opts, $xlc) = @_;
    print("$xlc->{NV}\n");
    print("$xlc->{W0}\n");
    print("$xlc->{NReal}\n");
    for (my $i=0; $i<$xlc->{NReal}; ++$i) {
        print("${$xlc->{RVs}}[$i]\n");
    }
    print("$xlc->{NCat}\n");
    for (my $i=0; $i<$xlc->{NCat}; ++$i) {
        my $cvi = "CVs$i";
        print("${$xlc->{CDs}}[$i] ");
        print("@{$xlc->{$cvi}}\n");
    }
}


END {
}

1;  # to ensure that the 'require' or 'use' succeeds
