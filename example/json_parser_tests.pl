#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Sugar::Test::LangVerifier;
use example::JSONParser;


# create a new verifier to run our tests
my $verifier = Sugar::Test::LangVerifier->new(
	# specify the parser class which will be tested
	parser_class => 'example::JSONParser',
);

$verifier->expect_result(
	'test string'
	=> context_root
	=> '
		"asdf

"
	'
	=> { type => 'string_value', value => "\"asdf\n\n\"" }
);

$verifier->expect_result(
	'test list'
	=> context_root
	=> '
		[ "asdf", "qwer"]
	'
	=> {
		type => 'list_value',
		value => [
			{ type => 'string_value', value => '"asdf"' },
			{ type => 'string_value', value => '"qwer"' },
		],
	}
);

$verifier->expect_result(
	'test values'
	=> context_root
	=> '
		[ true, false, null ]
	'
	=> {
		type => 'list_value',
		value => [
			{ type => 'boolean_value', value => 'true' },
			{ type => 'boolean_value', value => 'false' },
			{ type => 'null_value' },
		],
	}
);

$verifier->expect_result(
	'test numbers'
	=> context_root
	=> '
		[ 1, 2, -3, 0, 102030, 0.15, 0.00100, 1e10, 1E-15, -123.156e-1 ]
	'
	=> {
		type => 'list_value',
		value => [
			{ type => 'number_value', value => '1' },
			{ type => 'number_value', value => '2' },
			{ type => 'number_value', value => '-3' },
			{ type => 'number_value', value => '0' },
			{ type => 'number_value', value => '102030' },
			{ type => 'number_value', value => '0.15' },
			{ type => 'number_value', value => '0.00100' },
			{ type => 'number_value', value => '1e10' },
			{ type => 'number_value', value => '1E-15' },
			{ type => 'number_value', value => '-123.156e-1' },
		],
	}
);

$verifier->expect_error(
	'test value error'
	=> context_root
	=> '
		[ asdf ]
	'
	=> qr/expected json value/,
);

$verifier->expect_error(
	'test list error'
	=> context_root
	=> '
		[true,]
	'
	=> qr/expected json value/,
);

$verifier->expect_result(
	'test recursive list'
	=> context_root
	=> '
		[[], ["zxcv"], [ "asdf", "qwer"]]
	'
	=> {
		type => 'list_value',
		value => [
			{ type => 'list_value', value => [], },
			{
				type => 'list_value',
				value => [
					{ type => 'string_value', value => '"zxcv"' },
				],
			},
			{
				type => 'list_value',
				value => [
					{ type => 'string_value', value => '"asdf"' },
					{ type => 'string_value', value => '"qwer"' },
				],
			},
		],
	}
);

$verifier->expect_result(
	'test object'
	=> context_root
	=> '
		{"asdf":true, "qwer": false}
	'
	=> {
		type => 'object_value',
		value => {
			'"asdf"' => { type => 'boolean_value', value => 'true' },
			'"qwer"' => { type => 'boolean_value', value => 'false' },
		},
	}
);

$verifier->expect_result(
	'test object recursive'
	=> context_root
	=> '
		{"a": {"asdf":true, "qwer": false}, "b":{}}
	'
	=> {
		type => 'object_value',
		value => {
			'"a"' => {
				type => 'object_value',
				value => {
					'"asdf"' => { type => 'boolean_value', value => 'true' },
					'"qwer"' => { type => 'boolean_value', value => 'false' },
				},
			},
			'"b"' => { type => 'object_value', value => {} },
		},
	}
);



$verifier->run;

