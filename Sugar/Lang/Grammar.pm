#!/usr/bin/env perl
package Sugar::Lang::Grammar;
use parent 'Sugar::Lang::SyntaxTreeBuilder';
use strict;
use warnings;

use feature 'say';


our @keywords = qw/
	context
	root

	assign
	spawn
	respawn
	enter_context
	switch_context
	exit_context
	undef
/;
our $keyword_chain = join '|', map quotemeta, @keywords;
our $keywords_regex = qr/\b$keyword_chain\b/;

our @symbols = qw/
	{ } => =
/;
our $symbol_chain = join '|', map quotemeta, @symbols;
our $symbols_regex = qr/\b$symbol_chain\b/;

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
				spawn_into_context => [
					type => 'context',
					rule_name => '$1',
					context_type => 'context_definition',
				],
			],
		],
		# context_definition => [
		# 	[$string_regex] => {

		# 	},
		# ],
	};

	my $self = $class->SUPER::new(%args);

	return $self
}

sub main {
	my $parser = Sugar::Lang::Grammar->new;
}

caller or main(@ARGV);
