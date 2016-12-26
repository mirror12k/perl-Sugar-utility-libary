#!/usr/bin/env perl
package Sugar::Lang::Grammar;
use parent 'Sugar::Lang::SyntaxTreeBuilder';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use Sugar::IO::File;



our @keywords = qw/
	context
	root

	default
	
	assign
	spawn
	respawn
	enter_context
	switch_context
	exit_context

/;
our $keyword_chain = join '|', map quotemeta, @keywords;
our $keywords_regex = qr/\b$keyword_chain\b/;

our @symbols = (qw/
	{ } [ ] => =
/, ',');
our $symbol_chain = join '|', map quotemeta, @symbols;
our $symbols_regex = qr/$symbol_chain/;

our $string_regex = qr/'([^\\']|\\[\\'])*+'/s;
our $variable_regex = qr/[\$\&]\w++/;
our $identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;

our $comment_regex = qr/\#[^\n]*+\n/s;
our $whitespace_regex = qr/\s++/s;

sub new {
	my ($class, %args) = @_;

	$args{token_regexes} = [
		keyword => $keywords_regex,
		symbol => $symbols_regex,

		string => $string_regex,
		variable => $variable_regex,
		identifier => $identifier_regex,

		comment => $comment_regex,
		whitespace => $whitespace_regex,
	];
	$args{ignored_tokens} = [qw/ comment whitespace /];

	$args{syntax_definition} = {
		root => [
			[ 'context', $identifier_regex, '{' ] => [
				spawn => '$1',
				spawn => [ '&context_definition' ],
				# spawn_into_context => [
				# 	type => 'context',
				# 	context_name => '$1',
				# 	context_type => 'context_definition',
				# ],
			],
		],
		context_definition => [
			'}' => [
				'exit_context',
			],
			'default' => [
				spawn => undef,
				spawn => [ '&enter_match_action' ],
			],
			undef
				=> [
					spawn => [ '&match_list' ],
					spawn => [ '&enter_match_action' ],
				]
		],

		match_list => [
			$string_regex => [
				spawn => '$0',
				switch_context => 'match_list_more',
			],
			undef
				=> [
					die => 'unexpected end of match list',
				],
		],
		match_list_more => [
			',' => [
				switch_context => 'match_list',
			],
			undef
				=> [ 'exit_context' ]
		],

		enter_match_action => [
			'{' => [
				switch_context => 'match_action',
			],
			undef
				=> [ die => "expected '{' after match directive" ],
		],
		match_action => [
			[ 'enter_context', $variable_regex ] => [
				spawn => 'enter_context',
				spawn => '$1',
			],
			[ 'switch_context', $variable_regex ] => [
				spawn => 'switch_context',
				spawn => '$1',
			],
			'exit_context' => [
				spawn => 'exit_context',
			],
			'}' => [
				'exit_context',
			],
			undef
				=> [ die => "expected '}' to close match actions list" ],
		],
	};

	my $self = $class->SUPER::new(%args);

	return $self
}

sub main {
	my $parser = Sugar::Lang::Grammar->new;
	foreach my $file (@_) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		say Dumper $parser->parse;
	}
}

caller or main(@ARGV);
