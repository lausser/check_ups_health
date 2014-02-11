package UPS::APC;
our @ISA = qw(UPS::Device);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

