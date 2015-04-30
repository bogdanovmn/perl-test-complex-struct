package Test::ComplexStruct::Options;

use strict;
use warnings;
use utf8;

use Getopt::Long;

use base('Exporter');
our @EXPORT = qw(
	IS_OPTION_TOTAL
	IS_OPTION_SOFT
	IS_OPTION_DEBUG
	IS_OPTION_STRICT
	IS_OPTION_HELP
	IS_OPTION_WARN
);


my $_TOTAL;
my $_SOFT;
my $_DEBUG;
my $_STRICT = 1;
my $_WARN;
my $_HELP;

GetOptions(
	total  => \$_TOTAL,
	soft   => \$_SOFT,
	debug  => \$_DEBUG,
	strict => \$_STRICT,
	warn   => \$_WARN,
	help   => \$_HELP
);

sub IS_OPTION_DEBUG  { $_DEBUG  }
sub IS_OPTION_TOTAL  { $_TOTAL  }
sub IS_OPTION_SOFT   { $_SOFT   }
sub IS_OPTION_STRICT { $_STRICT }
sub IS_OPTION_WARN   { $_WARN   }
sub IS_OPTION_HELP   { $_HELP   }

sub usage {
	print qq|
Usage:
	perl test_name.t [--debug] [--total] [--soft] [--warn] [--help] 
	
	--debug    print more info in fail case
	--total    run global test
	--soft     don't stop if some test failed
	--warn     show some warnings, such as "optional key never checked"
	--help     show this message
\n\n|;
	exit 1;
}

usage() if IS_OPTION_HELP;

1; 
