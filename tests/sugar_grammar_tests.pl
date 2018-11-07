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
	'test comments'
	=> context_root
	=> "
		# asdf qewkengiwniwf9r2339t9023r9203r9203r#(@#
	"
	=> {}
);

$verifier->expect_result(
	'test ignored tokens'
	=> context_root
	=> "
		ignored_tokens {
			comment
			whitespace
		}
	"
	=> {
		ignored_tokens => [ 'comment', 'whitespace', ],
	}
);

$verifier->expect_result(
	'test package name'
	=> context_root
	=> "
		package Awesome::Test::Package
	"
	=> {
		package_identifier => 'Awesome::Test::Package',
	}
);

$verifier->expect_result(
	'test tokens list and def values'
	=> context_root
	=> "
		tokens {
			test_a => \$var_a
			symbol => /[a-z_][a-z0-9_]*/
			regex => s/asdf/qwer/

			comment => '# hello world!'
		}
	"
	=> {
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
	'test item context'
	=> context_root
	=> "
		item context token_definition {
			match ')'
			\$_ = \$0
			return \$1
		}
	"
	=> {
	'contexts' => [
		{
			'identifier' => 'token_definition',
			'type' => 'item_context',
			'block' => [
				{
					'type' => 'match_statement',
					'match_list' => {
						'match_conditions' => [
							{ 'type' => 'string_match', 'string' => '\')\'' }
						],
						'look_ahead_conditons' => []
					},
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

# $verifier->expect_result(
# 	'test list context'
# 	=> context_root
# 	=> "
# 		list context mycoolcontext {
# 			switch {
# 				*my_type => {
# 					push \$0
# 					push \$0{line_number}
# 					push \$0{line_offset}
# 				}
# 				'asdf' => {}
# 				/qwer/ => {}
# 			}
# 		}
# 	"
# 	=> {
# 	'contexts' => [
# 		{
# 			'identifier' => 'mycoolcontext',
# 			'type' => 'list_context',
# 			'block' => [
# 				{
# 					'type' => 'switch_statement',
# 					'switch_cases' => [
# 						{
# 							'type' => 'match_case',
# 							'match_list' => {
# 								'match_conditions' => [
# 									{ 'type' => 'token_type_match', 'value' => 'my_type' }
# 								],
# 								'look_ahead_conditons' => [],
# 							},

# 							'block' => [
# 								{
# 									'expression' => { 'type' => 'get_token_text', 'token' => '$0', },
# 									'type' => 'push_statement'
# 								},
# 								{
# 									'expression' => { 'token' => '$0', 'type' => 'get_token_line_number', },
# 									'type' => 'push_statement'
# 								},
# 								{
# 									'type' => 'push_statement',
# 									'expression' => { 'token' => '$0', 'type' => 'get_token_line_offset' }
# 								}
# 							],
# 						},
# 						{
# 							'type' => 'match_case',
# 							'match_list' => {
# 								'match_conditions' => [
# 									{ 'type' => 'string_match', 'string' => "'asdf'" }
# 								],
# 								'look_ahead_conditons' => [],
# 							},
# 							'block' => [],
# 						},
# 						{
# 							'type' => 'match_case',
# 							'match_list' => {
# 								'match_conditions' => [
# 									{ 'type' => 'regex_match', 'regex' => "/qwer/" }
# 								],
# 								'look_ahead_conditons' => [],
# 							},
# 							'block' => [],
# 						},
# 					],
# 				},
# 			],
# 		}
# 	],
# });

# $verifier->expect_result(
# 	'test object context'
# 	=> context_root
# 	=> "
# 		object context objdefinition {
# 			\$_ = {
# 				asdf => []
# 				qwer => {}
# 				zxcv => 'lol'
# 			}
# 			\$_{my_value} = 'no'
# 			\$_{my_list}[] = '15'
# 			\$_{my_hash}{wat} = \$0
# 			return \$_
# 		}
# 	"
# 	=> {
# 	'contexts' => [
# 		{
# 			'identifier' => 'objdefinition',
# 			'type' => 'object_context',
# 			'block' => [
# 				{
# 					'type' => 'assign_item_statement',
# 					'variable' => '$_',
# 					'expression' => {
# 						'type' => 'hash_constructor',
# 						'arguments' => [
# 							{ 'value' => 'asdf', 'type' => 'bareword', },
# 							{ 'type' => 'empty_list', },
# 							{ 'value' => 'qwer',
# 							'type' => 'bareword', },
# 							{ 'type' => 'empty_hash' },
# 							{ 'type' => 'bareword', 'value' => 'zxcv' },
# 							{ 'string' => '\'lol\'', 'type' => 'string' }
# 						],
# 					}
# 				},
# 				{
# 					'type' => 'assign_field_statement',
# 					'key' => {
# 						'type' => 'bareword',
# 						'value' => 'my_value',
# 					},
# 					'expression' => {
# 						'string' => '\'no\'',
# 						'type' => 'string'
# 					},
# 					'variable' => '$_'
# 				},
# 				{
# 					'type' => 'assign_array_field_statement',
# 					'variable' => '$_',
# 					'key' => {
# 						'type' => 'bareword',
# 						'value' => 'my_list',
# 					},
# 					'expression' => {
# 						'string' => '\'15\'',
# 						'type' => 'string'
# 					}
# 				},
# 				{
# 					'type' => 'assign_object_field_statement',
# 					'key' => {
# 						'type' => 'bareword',
# 						'value' => 'my_hash',
# 					},
# 					'subkey' => {
# 						'value' => 'wat',
# 						'type' => 'bareword'
# 					},
# 					'expression' => {
# 						'token' => '$0',
# 						'type' => 'get_token_text',
# 					},
# 					'variable' => '$_',
# 				},
# 				{
# 					'type' => 'return_expression_statement',
# 					'expression' => { 'type' => 'get_context', }
# 				}

# 			],
# 		}
# 	],
# });



$verifier->expect_error(
	'missing def value error'
	=> context_root
	=> "
		asdf = A::B
	"
	=> qr/unexpected token in def_value/);



$verifier->expect_result(
	'test match action simple'
	=> context_match_action
	=> "
		\$_ = \$0
		return \$1
	"
	=> [
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


$verifier->run;



