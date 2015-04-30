use strict;
use warnings;
use utf8;

use FindBin;
use lib $FindBin::Bin . '/../lib';
use Test::ComplexStruct;
use Test::More;


#
# key_11
#
my $key_11_proto = {
	__full_view_cond => 2,
	__value => [{
		__short => { a => '', b => '' },
		__full  => { c => '', d => '' }
	}]
};

check_complex_struct(
	[
		{ a => 1 , b => 2 },
		{ a => 11, b => 21 },
		{ a => 11, b => 21 },
	],
	$key_11_proto,
	'key_11 (short view)'
);

check_complex_struct(
	[
		{ c => 1 , d => 2 },
		{ c => 11, d => 21 },
	],
	$key_11_proto,
	'key_11 (full view)'
);

check_complex_struct(
	[
		{ a => '', b => 123 },
		{ a => '', b => [123] },
		{ a => '', b => [{ a => 123 }] },
		{ a => '' },
	],
	[{ a => '', b => SKIP }],
	'key_15'
);

done_testing;
