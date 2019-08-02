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
	'test string',
	text => '
		"asdf

"
	',
	expected_result => { type => 'string_value', value => "\"asdf\n\n\"" }
);

$verifier->expect_result(
	'test number',
	text => '15',
	expected_result => { type => 'number_value', value => "15" }
);

$verifier->expect_result(
	'test bool',
	text => 'true',
	expected_result => { type => 'boolean_value', value => "true" }
);

$verifier->expect_result(
	'test null',
	text => 'null',
	expected_result => { type => 'null_value', value => undef }
);

$verifier->expect_result(
	'test list',
	text => '
		[ "asdf", "qwer"]
	',
	expected_result => {
		type => 'list_value',
		value => [
			{ type => 'string_value', value => '"asdf"' },
			{ type => 'string_value', value => '"qwer"' },
		],
	}
);

$verifier->expect_result(
	'test values',
	text => '
		[ true, false, null ]
	',
	expected_result => {
		type => 'list_value',
		value => [
			{ type => 'boolean_value', value => 'true' },
			{ type => 'boolean_value', value => 'false' },
			{ type => 'null_value', value => undef },
		],
	}
);

$verifier->expect_result(
	'test numbers',
	text => '
		[ 1, 2, -3, 0, 102030, 0.15, 0.00100, 1e10, 1E-15, -123.156e-1 ]
	',
	expected_result => {
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
	'test value error',
	text => '
		[ asdf ]
	',
	expected_error => qr/expected json value/,
);

$verifier->expect_error(
	'test list error',
	text => '
		[true,]
	',
	expected_error => qr/expected json value/,
);

$verifier->expect_result(
	'test recursive list',
	text => '
		[[], ["zxcv"], [ "asdf", "qwer"]]
	',
	expected_result => {
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
	'test object',
	text => '
		{"asdf":true, "qwer": false}
	',
	expected_result => {
		type => 'object_value',
		value => {
			'"asdf"' => { type => 'boolean_value', value => 'true' },
			'"qwer"' => { type => 'boolean_value', value => 'false' },
		},
	}
);

$verifier->expect_result(
	'test object recursive',
	text => '
		{"a": {"asdf":true, "qwer": false}, "b":{}}
	',
	expected_result => {
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

