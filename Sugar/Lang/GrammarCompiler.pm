#!/usr/bin/env perl
package Sugar::Lang::GrammarCompiler;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_code_block_regex = qr/\{\{.*?\}\}/s;
our $var_symbol_regex = qr/\(|\)|\{|\}|\[|\]|->|=>|=|,|\*/;
our $var_package_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+(\:\:[a-zA-Z_][a-zA-Z0-9_]*+)++/;
our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_string_regex = qr/'([^\\']|\\[\\'])*+'/s;
our $var_regex_regex = qr/\/([^\\\/]|\\.)*+\/[msixpodualn]*+/s;
our $var_substitution_regex_regex = qr/s\/([^\\\/]|\\.)*+\/([^\\\/]|\\.)*+\/[msixpodualngcer]*+/s;
our $var_variable_regex = qr/\$\w++/;
our $var_context_reference_regex = qr/!\w++/;
our $var_function_reference_regex = qr/\&\w++/;
our $var_comment_regex = qr/\#[^\n]*+\n/s;
our $var_whitespace_regex = qr/\s++/s;


our $tokens = [
	'code_block' => $var_code_block_regex,
	'symbol' => $var_symbol_regex,
	'regex' => $var_regex_regex,
	'substitution_regex' => $var_substitution_regex_regex,
	'package_identifier' => $var_package_identifier_regex,
	'identifier' => $var_identifier_regex,
	'string' => $var_string_regex,
	'variable' => $var_variable_regex,
	'context_reference' => $var_context_reference_regex,
	'function_reference' => $var_function_reference_regex,
	'comment' => $var_comment_regex,
	'whitespace' => $var_whitespace_regex,
];

our $ignored_tokens = [
	'comment',
	'whitespace',
];

our $contexts = {
	action_block => 'context_action_block',
	def_value => 'context_def_value',
	if_chain => 'context_if_chain',
	ignored_tokens_list => 'context_ignored_tokens_list',
	match_action => 'context_match_action',
	match_conditions_list => 'context_match_conditions_list',
	match_item => 'context_match_item',
	match_list_arrow => 'context_match_list_arrow',
	match_list_specifier => 'context_match_list_specifier',
	more_spawn_expression => 'context_more_spawn_expression',
	root => 'context_root',
	spawn_expression => 'context_spawn_expression',
	spawn_expression_hash => 'context_spawn_expression_hash',
	switch_blocks => 'context_switch_blocks',
	token_definition => 'context_token_definition',
};



##############################
##### api
##############################



sub new {
	my ($class, %opts) = @_;

	$opts{token_regexes} = $tokens;
	$opts{ignored_tokens} = $ignored_tokens;
	$opts{contexts} = $contexts;

	my $self = $class->SUPER::new(%opts);

	return $self
}

sub parse {
	my ($self, @args) = @_;
	return $self->SUPER::parse(@args)
}



##############################
##### sugar contexts functions
##############################


sub context_root {
	my ($self) = @_;
	my $context_object = {};

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens = (@tokens, $self->step_tokens(2));
			push @{$context_object->{variables}}, $tokens[0][1];
			push @{$context_object->{variables}}, $self->context_def_value;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'package' and $self->{tokens}[$self->{tokens_index} + 1][0] eq 'package_identifier') {
			my @tokens = (@tokens, $self->step_tokens(2));
			$context_object->{package_identifier} = $tokens[1][1];
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'package' and $self->{tokens}[$self->{tokens_index} + 1][0] eq 'identifier') {
			my @tokens = (@tokens, $self->step_tokens(2));
			$context_object->{package_identifier} = $tokens[1][1];
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'tokens' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = (@tokens, $self->step_tokens(2));
			$context_object->{tokens} = $self->context_token_definition([]);
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'ignored_tokens' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = (@tokens, $self->step_tokens(2));
			$context_object->{ignored_tokens} = $self->context_ignored_tokens_list([]);
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'item' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'context' and $self->{tokens}[$self->{tokens_index} + 2][0] eq 'identifier') {
			my @tokens = (@tokens, $self->step_tokens(3));
			push @{$context_object->{context_order}}, $tokens[2][1];
			$context_object->{item_contexts}{$tokens[2][1]} = $self->context_action_block;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'list' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'context' and $self->{tokens}[$self->{tokens_index} + 2][0] eq 'identifier') {
			my @tokens = (@tokens, $self->step_tokens(3));
			push @{$context_object->{context_order}}, $tokens[2][1];
			$context_object->{list_contexts}{$tokens[2][1]} = $self->context_action_block;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'object' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'context' and $self->{tokens}[$self->{tokens_index} + 2][0] eq 'identifier') {
			my @tokens = (@tokens, $self->step_tokens(3));
			push @{$context_object->{context_order}}, $tokens[2][1];
			$context_object->{object_contexts}{$tokens[2][1]} = $self->context_action_block;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'sub' and $self->{tokens}[$self->{tokens_index} + 1][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 2][0] eq 'code_block') {
			my @tokens = (@tokens, $self->step_tokens(3));
			push @{$context_object->{subroutine_order}}, $tokens[1][1];
			$context_object->{subroutines}{$tokens[1][1]} = $tokens[2][1];
			}
	}
	return $context_object;
}

sub context_def_value {
	my ($self, $context_value) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'string') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $tokens[0][1];
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'substitution_regex') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $tokens[0][1];
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'regex') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $tokens[0][1];
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'variable') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $tokens[0][1];
			}
			else {
			$self->confess_at_current_offset('unexpected token in def_value');
			}
	}
	return $context_value;
}

sub context_token_definition {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=>') {
			my @tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $tokens[0][1];
			push @$context_list, $self->context_def_value;
			}
			else {
			$self->confess_at_current_offset('unexpected token in token_definition');
			}
	}
	return $context_list;
}

sub context_ignored_tokens_list {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $tokens[0][1];
			}
			else {
			$self->confess_at_current_offset('unexpected token in ignored_tokens_list');
			}
	}
	return $context_list;
}

sub context_match_list_specifier {
	my ($self, $context_object) = @_;
	my @tokens;

			$context_object = { match_conditions => [], look_ahead_conditons => [], };
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '(') {
			my @tokens = (@tokens, $self->step_tokens(1));
			$context_object->{look_ahead_conditons} = $self->context_match_conditions_list;
			$self->confess_at_current_offset('expected \')\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			$context_object->{match_conditions} = $self->context_match_conditions_list;
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '(') {
			my @tokens = (@tokens, $self->step_tokens(1));
			$context_object->{look_ahead_conditons} = $self->context_match_conditions_list;
			$self->confess_at_current_offset('expected \')\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			}
			return $context_object;
}

sub context_match_conditions_list {
	my ($self, $context_list) = @_;
	my @tokens;

			push @$context_list, $self->context_match_item;
			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_match_item;
			}
			return $context_list;
}

sub context_match_list_arrow {
	my ($self, $context_list) = @_;
	my @tokens;

			$context_list = $self->context_match_list_specifier($context_list);
			$self->confess_at_current_offset('expected \'=>\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=>';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
}

sub context_match_item {
	my ($self, $context_value) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'function_reference' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '->') {
			my @tokens = (@tokens, $self->step_tokens(2));
			return { type => 'function_match', function => $tokens[0][1], argument => $self->context_spawn_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'function_reference') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'function_match', function => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'variable') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'variable_match', variable => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'regex') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'regex_match', regex => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'string') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'string_match', string => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '*' and $self->{tokens}[$self->{tokens_index} + 1][0] eq 'identifier') {
			my @tokens = (@tokens, $self->step_tokens(2));
			return { type => 'token_type_match', value => $tokens[1][1], };
			}
			else {
			$self->confess_at_current_offset('expected match item');
			}
	}
	return $context_value;
}

sub context_action_block {
	my ($self, $context_value) = @_;
	my @tokens;

			$self->confess_at_current_offset('expected \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = $self->context_match_action([]);
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_value;
}

sub context_match_action {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '$_' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'assign_item_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '$_' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $self->context_spawn_expression;
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_spawn_expression;
			$self->confess_at_current_offset('expected \'}\', \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'assign_object_field_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, subkey => pop @$context_list, key => pop @$context_list, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected \']\', \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'assign_array_field_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, key => pop @$context_list, };
			}
			else {
			$self->confess_at_current_offset('expected \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'assign_field_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, key => pop @$context_list, };
			}
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'push') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'push_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'return') {
			my @tokens = (@tokens, $self->step_tokens(1));
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			push @$context_list, { type => 'return_statement', line_number => $tokens[0][2], };
			}
			else {
			push @$context_list, { type => 'return_expression_statement', expression => $self->context_spawn_expression, line_number => $tokens[0][2], };
			}
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'match') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'match_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_specifier, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'if') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_if_chain({ type => 'if_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'switch') {
			my @tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_if_chain({ type => 'switch_statement', line_number => $tokens[0][2], switch_cases => $self->context_switch_blocks([]), });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'while') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'while_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'warn') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'warn_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'die') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'die_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
			}
			else {
			return $context_list;
			}
	}
	return $context_list;
}

sub context_switch_blocks {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'default') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'default_case', line_number => $tokens[0][2], block => $self->context_action_block, };
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
			}
			else {
			push @$context_list, { type => 'match_case', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, };
			}
	}
	return $context_list;
}

sub context_if_chain {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'elsif') {
			my @tokens = (@tokens, $self->step_tokens(1));
			$context_object->{'branch'} = $self->context_if_chain({ type => 'elsif_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, });
			return $context_object;
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'else') {
			my @tokens = (@tokens, $self->step_tokens(1));
			$context_object->{'branch'} = { type => 'else_statement', line_number => $tokens[0][2], block => $self->context_action_block, };
			return $context_object;
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_spawn_expression {
	my ($self, $context_value) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A(\$\d++)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 2][1] eq 'line_number' and $self->{tokens}[$self->{tokens_index} + 3][1] eq '}') {
			my @tokens = (@tokens, $self->step_tokens(4));
			return { type => 'get_token_line_number', token => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A(\$\d++)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 2][1] eq 'line_offset' and $self->{tokens}[$self->{tokens_index} + 3][1] eq '}') {
			my @tokens = (@tokens, $self->step_tokens(4));
			return { type => 'get_token_line_offset', token => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A(\$\d++)\Z/) {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'get_token_text', token => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '$_') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $self->context_more_spawn_expression({ type => 'get_context', });
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'pop') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'pop_list', };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'context_reference' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '->') {
			my @tokens = (@tokens, $self->step_tokens(2));
			return { type => 'call_context', context => $tokens[0][1], argument => $self->context_spawn_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'context_reference') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'call_context', context => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'function_reference' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '->') {
			my @tokens = (@tokens, $self->step_tokens(2));
			return { type => 'call_function', function => $tokens[0][1], argument => $self->context_spawn_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'function_reference') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'call_function', function => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'substitution_regex' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '->') {
			my @tokens = (@tokens, $self->step_tokens(2));
			return { type => 'call_substitution', regex => $tokens[0][1], argument => $self->context_spawn_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'variable' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '->') {
			my @tokens = (@tokens, $self->step_tokens(2));
			return { type => 'call_variable', variable => $tokens[0][1], argument => $self->context_spawn_expression, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'variable') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'call_variable', variable => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'string') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'string', string => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'bareword', value => $tokens[0][1], };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'undef') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'undef', };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ']') {
			my @tokens = (@tokens, $self->step_tokens(2));
			return { type => 'empty_list', };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '}') {
			my @tokens = (@tokens, $self->step_tokens(2));
			return { type => 'empty_hash', };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'hash_constructor', arguments => $self->context_spawn_expression_hash([]), };
			}
			else {
			$self->confess_at_current_offset('push expression expected');
			}
	}
	return $context_value;
}

sub context_more_spawn_expression {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens = (@tokens, $self->step_tokens(1));
			$context_object = { type => 'access', left_expression => $context_object, right_expression => $self->context_spawn_expression, };
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			}
			else {
			return $context_object;
			}
	}
	return $context_object;
}

sub context_spawn_expression_hash {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
	my @tokens;

			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
			}
			else {
			push @$context_list, $self->context_spawn_expression;
			$self->confess_at_current_offset('expected \'=>\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=>';
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_spawn_expression;
			}
	}
	return $context_list;
}


##############################
##### native perl functions
##############################

sub main {
	use Data::Dumper;
	use Sugar::IO::File;
	use Sugar::Lang::SyntaxIntermediateCompiler;

	my $parser = __PACKAGE__->new;
	foreach my $file (@_) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		my $tree = $parser->parse;
		# say Dumper $tree;

		my $compiler = Sugar::Lang::SyntaxIntermediateCompiler->new(syntax_definition_intermediate => $tree);
		say $compiler->to_package;
	}
}

caller or main(@ARGV);


