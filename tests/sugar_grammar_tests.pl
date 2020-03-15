#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Sugar::Test::LangVerifier;
use Sugar::Lang::SugarGrammarParser;
# use SugarGrammarParser;

use Data::Dumper;


my $verifier = Sugar::Test::LangVerifier->new(
	parser_class => 'Sugar::Lang::SugarGrammarParser',
);

# ignore contexts_by_name as it's too complex to implement right now
$verifier->{ignore_keys}{contexts_by_name} = 1;

$verifier->expect_result(
	'test comments',
	text => "
		# asdf qewkengiwniwf9r2339t9023r9203r9203r#(@#
	",
	expected_result => {}
);

$verifier->expect_result(
	'test ignored tokens',
	text => "
		ignored_tokens {
			comment
			whitespace
		}
	",
	expected_result => {
		ignored_tokens => [ 'comment', 'whitespace', ],
	}
);

$verifier->expect_result(
	'test package name',
	text => "
		package Awesome::Test::Package
	",
	expected_result => {
		package_identifier => 'Awesome::Test::Package',
	}
);

$verifier->expect_result(
	'test tokens list and def values',
	text => "
		tokens {
			test_a => \$var_a
			symbol => /[a-z_][a-z0-9_]*/
			regex => s/asdf/qwer/

			comment => '# hello world!'
		}
	",
	expected_result => {
		tokens => [
			{ type => 'token_definition', identifier => 'test_a',
					value => { type => 'variable_value', value => '$var_a', }, },
			{ type => 'token_definition', identifier => 'symbol',
					value => { type => 'regex_value', value => '/[a-z_][a-z0-9_]*/', }, },
			{ type => 'token_definition', identifier => 'regex',
					value => { type => 'substitution_regex_value', value => 's/asdf/qwer/', }, },
			{ type => 'token_definition', identifier => 'comment',
					value => { type => 'string_value', value => "'# hello world!'", }, },
		],
	}
);

$verifier->expect_result(
	'test item context',
	text => "
		item context token_definition {
			match ')'
			\$_ = \$0
			return \$1
		}
	",
	expected_result => {
	'contexts' => [
		{
			'identifier' => 'token_definition',
			'type' => 'context_definition',
			'context_type' => 'item',
			'block' => [
				{
					'type' => 'match_statement',
					'match_list' => [{
						'match_conditions' => [
							{ 'type' => 'string_match', 'string' => '\')\'' }
						],
					}],
				},
				{
					'type' => 'assign_item_statement',
					'expression' => { 'token' => '$0', 'type' => 'get_token_text' },
					'variable' => '$_'
				},
				{
					'type' => 'return_expression_statement',
					'expression' => { 'type' => 'get_token_text', 'token' => '$1' },
				},
			],
		}
	],
});

$verifier->expect_result(
	'test list context',
	text => "
		list context mycoolcontext {
			switch {
				*my_type => {
					push \$0
					push \$0{line_number}
					push \$0{line_offset}
				}
				'asdf' => {}
				/qwer/ => {}
			}
		}
	",
	expected_result => {
	'contexts' => [
		{
			'identifier' => 'mycoolcontext',
			'type' => 'context_definition',
			'context_type' => 'list',
			'block' => [
				{
					'type' => 'switch_statement',
					'switch_cases' => [
						{
							'type' => 'match_case',
							'match_list' => [{
								'match_conditions' => [
									{ 'type' => 'token_type_match', 'value' => 'my_type' }
								],
							}],

							'block' => [
								{
									'expression' => { 'type' => 'get_token_text', 'token' => '$0', },
									'type' => 'push_statement'
								},
								{
									'expression' => { 'token' => '$0', 'type' => 'get_token_line_number', },
									'type' => 'push_statement'
								},
								{
									'type' => 'push_statement',
									'expression' => { 'token' => '$0', 'type' => 'get_token_line_offset' }
								}
							],
						},
						{
							'type' => 'match_case',
							'match_list' => [{
								'match_conditions' => [
									{ 'type' => 'string_match', 'string' => "'asdf'" }
								],
							}],
							'block' => [],
						},
						{
							'type' => 'match_case',
							'match_list' => [{
								'match_conditions' => [
									{ 'type' => 'regex_match', 'regex' => "/qwer/" }
								],
							}],
							'block' => [],
						},
					],
				},
			],
		}
	],
});

$verifier->expect_result(
	'test object context',
	text => "
		object context objdefinition {
			\$_ = {
				asdf => []
				qwer => {}
				zxcv => 'lol'
			}
			\$_{my_value} = 'no'
			\$_{my_list}[] = '15'
			\$_{my_hash}{wat} = \$0
			return \$_
		}
	",
	expected_result => {
	'contexts' => [
		{
			'identifier' => 'objdefinition',
			'type' => 'context_definition',
			'context_type' => 'object',
			'block' => [
				{
					'type' => 'assign_item_statement',
					'variable' => '$_',
					'expression' => {
						'type' => 'hash_constructor',
						'arguments' => [
							{ 'value' => 'asdf', 'type' => 'bareword', },
							{ 'type' => 'empty_list', },
							{ 'value' => 'qwer',
							'type' => 'bareword', },
							{ 'type' => 'empty_hash' },
							{ 'type' => 'bareword', 'value' => 'zxcv' },
							{ 'string' => '\'lol\'', 'type' => 'string' }
						],
					}
				},
				{
					'type' => 'assign_field_statement',
					'key' => {
						'type' => 'bareword',
						'value' => 'my_value',
					},
					'expression' => {
						'string' => '\'no\'',
						'type' => 'string'
					},
					'variable' => '$_'
				},
				{
					'type' => 'assign_array_field_statement',
					'variable' => '$_',
					'key' => {
						'type' => 'bareword',
						'value' => 'my_list',
					},
					'expression' => {
						'string' => '\'15\'',
						'type' => 'string'
					}
				},
				{
					'type' => 'assign_object_field_statement',
					'key' => {
						'type' => 'bareword',
						'value' => 'my_hash',
					},
					'subkey' => {
						'value' => 'wat',
						'type' => 'bareword'
					},
					'expression' => {
						'token' => '$0',
						'type' => 'get_token_text',
					},
					'variable' => '$_',
				},
				{
					'type' => 'return_expression_statement',
					'expression' => { 'type' => 'get_context', }
				}

			],
		}
	],
});



$verifier->expect_error(
	'missing def value error',
	text => "
		asdf = A::B
	",
	expected_error => qr/unexpected token in def_value/);



$verifier->expect_result(
	'test match action simple',
	context_key => 'context_match_action',
	text => "
		\$_ = \$0
		return \$1
	",
	expected_result => [
		{
			'type' => 'assign_item_statement',
			'expression' => { 'token' => '$0', 'type' => 'get_token_text' },
			'variable' => '$_'
		},
		{
			'type' => 'return_expression_statement',
			'expression' => { 'type' => 'get_token_text', 'token' => '$1' },
		},
	]);



$verifier->expect_result(
	'test match context result',
	context_key => 'context_match_action',
	text => "
		match 'asdf', !qwer, !zxcv->[]
	",
	expected_result => [
		{
			'type' => 'match_statement',
			'match_list' => [{
				'match_conditions' => [
					{
						'type' => 'string_match',
						'line_number' => 2,
						'string' => '\'asdf\''
					},
					{
						'line_number' => 2,
						'identifier' => '!qwer',
						'type' => 'context_match'
					},
					{
						'line_number' => 2,
						'identifier' => '!zxcv',
						'type' => 'context_match',
						'argument' => { 'type' => 'empty_list', }
					},
				],
			}],
		},
	]);


$verifier->run;



