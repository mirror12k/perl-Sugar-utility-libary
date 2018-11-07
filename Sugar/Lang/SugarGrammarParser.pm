#!/usr/bin/env perl
package Sugar::Lang::SugarGrammarParser;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_code_block_regex = qr/\{\{.*?\}\}/s;
our $var_symbol_regex = qr/\(|\)|\{|\}|\[|\]|->|=>|=|,|\*|:/;
our $var_package_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+(?:\:\:[a-zA-Z_][a-zA-Z0-9_]*+)++/;
our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_string_regex = qr/'(?:[^\\']|\\[\\'])*+'/s;
our $var_regex_regex = qr/\/(?:[^\\\/]|\\.)*+\/[msixpodualn]*+/s;
our $var_substitution_regex_regex = qr/s\/(?:[^\\\/]|\\.)*+\/(?:[^\\\/]|\\.)*+\/[msixpodualngcer]*+/s;
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
	root => 'context_root',
	def_value => 'context_def_value',
	token_definition => 'context_token_definition',
	ignored_tokens_list => 'context_ignored_tokens_list',
	match_list_specifier => 'context_match_list_specifier',
	match_conditions_list => 'context_match_conditions_list',
	match_list_arrow => 'context_match_list_arrow',
	match_item => 'context_match_item',
	action_block => 'context_action_block',
	match_action => 'context_match_action',
	switch_blocks => 'context_switch_blocks',
	if_chain => 'context_if_chain',
	spawn_expression => 'context_spawn_expression',
	more_spawn_expression => 'context_more_spawn_expression',
	spawn_expression_list => 'context_spawn_expression_list',
	spawn_expression_hash => 'context_spawn_expression_hash',
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
	my $context_value = {};
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '=') {
			$self->{tokens_index} += 2;
			push @{$context_value->{global_variable_names}}, $tokens[0][1];
			$context_value->{global_variable_expressions}{$tokens[0][1]} = $self->context_def_value;
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'package' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[0] eq 'package_identifier') {
			$self->{tokens_index} += 2;
			$context_value->{package_identifier} = $tokens[1][1];
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'package' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[0] eq 'identifier') {
			$self->{tokens_index} += 2;
			$context_value->{package_identifier} = $tokens[1][1];
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'tokens' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '{') {
			$self->{tokens_index} += 2;
			$context_value->{tokens} = $self->context_token_definition([]);
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'ignored_tokens' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '{') {
			$self->{tokens_index} += 2;
			$context_value->{ignored_tokens} = $self->context_ignored_tokens_list([]);
		} elsif ($self->{tokens_index} + 3 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'item' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq 'context' and ($tokens[2] = $self->{tokens}[$self->{tokens_index} + 2])->[0] eq 'identifier') {
			$self->{tokens_index} += 3;
			my $var_context = { type => 'item_context', line_number => $tokens[0][2], identifier => $tokens[2][1], block => $self->context_action_block, };
			push @{$context_value->{contexts}}, $var_context;
			$context_value->{contexts_by_name}{$tokens[2][1]} = $var_context;
		} elsif ($self->{tokens_index} + 3 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'list' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq 'context' and ($tokens[2] = $self->{tokens}[$self->{tokens_index} + 2])->[0] eq 'identifier') {
			$self->{tokens_index} += 3;
			my $var_context = { type => 'list_context', line_number => $tokens[0][2], identifier => $tokens[2][1], block => $self->context_action_block, };
			push @{$context_value->{contexts}}, $var_context;
			$context_value->{contexts_by_name}{$tokens[2][1]} = $var_context;
		} elsif ($self->{tokens_index} + 3 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'object' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq 'context' and ($tokens[2] = $self->{tokens}[$self->{tokens_index} + 2])->[0] eq 'identifier') {
			$self->{tokens_index} += 3;
			my $var_context = { type => 'object_context', line_number => $tokens[0][2], identifier => $tokens[2][1], block => $self->context_action_block, };
			push @{$context_value->{contexts}}, $var_context;
			$context_value->{contexts_by_name}{$tokens[2][1]} = $var_context;
		} elsif ($self->{tokens_index} + 3 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'sub' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[0] eq 'identifier' and ($tokens[2] = $self->{tokens}[$self->{tokens_index} + 2])->[0] eq 'code_block') {
			$self->{tokens_index} += 3;
			push @{$context_value->{subroutines}}, { type => 'subroutine', line_number => $tokens[0][2], identifier => $tokens[1][1], code_block => $tokens[2][1], };
		}
	}
	return $context_value;
}
sub context_def_value {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'string') {
			$self->{tokens_index} += 1;
			return { type => 'string_value', line_number => $tokens[0][2], value => $tokens[0][1], };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'substitution_regex') {
			$self->{tokens_index} += 1;
			return { type => 'substitution_regex_value', line_number => $tokens[0][2], value => $tokens[0][1], };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'regex') {
			$self->{tokens_index} += 1;
			return { type => 'regex_value', line_number => $tokens[0][2], value => $tokens[0][1], };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'variable') {
			$self->{tokens_index} += 1;
			return { type => 'variable_value', line_number => $tokens[0][2], value => $tokens[0][1], };
		} else {
			$self->confess_at_current_offset('unexpected token in def_value');
		}
	}
	return $context_value;
}
sub context_token_definition {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '}') {
			$self->{tokens_index} += 1;
			return $context_value;
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '=>') {
			$self->{tokens_index} += 2;
			push @$context_value, { type => 'token_definition', line_number => $tokens[0][2], identifier => $tokens[0][1], value => $self->context_def_value, };
		} else {
			$self->confess_at_current_offset('unexpected token in token_definition');
		}
	}
	return $context_value;
}
sub context_ignored_tokens_list {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '}') {
			$self->{tokens_index} += 1;
			return $context_value;
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'identifier') {
			$self->{tokens_index} += 1;
			push @$context_value, $tokens[0][1];
		} else {
			$self->confess_at_current_offset('unexpected token in ignored_tokens_list');
		}
	}
	return $context_value;
}
sub context_match_list_specifier {
	my ($self, $context_value) = @_;
	my @tokens;

	$context_value = { match_conditions => [], look_ahead_conditons => [], };
	if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '(') {
		$self->{tokens_index} += 1;
		$context_value->{look_ahead_conditons} = $self->context_match_conditions_list;
		$self->confess_at_current_offset('expected \')\'')
			unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq ')';
		$self->{tokens_index} += 1;
	} else {
		$context_value->{match_conditions} = $self->context_match_conditions_list;
		if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '(') {
			$self->{tokens_index} += 1;
			$context_value->{look_ahead_conditons} = $self->context_match_conditions_list;
			$self->confess_at_current_offset('expected \')\'')
				unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq ')';
			$self->{tokens_index} += 1;
		}
	}
	return $context_value;
}
sub context_match_conditions_list {
	my ($self, $context_value) = @_;
	my @tokens;

	push @$context_value, $self->context_match_item;
	while ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq ',') {
		$self->{tokens_index} += 1;
		push @$context_value, $self->context_match_item;
	}
	return $context_value;
}
sub context_match_list_arrow {
	my ($self, $context_value) = @_;
	my @tokens;

	$context_value = $self->context_match_list_specifier($context_value);
	$self->confess_at_current_offset('expected \'=>\'')
		unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '=>';
	$self->{tokens_index} += 1;
	return $context_value;
}
sub context_match_item {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'function_reference' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '->') {
			$self->{tokens_index} += 2;
			return { type => 'function_match', line_number => $tokens[0][2], function => $tokens[0][1], argument => $self->context_spawn_expression, };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'function_reference') {
			$self->{tokens_index} += 1;
			return { type => 'function_match', line_number => $tokens[0][2], function => $tokens[0][1], };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'variable') {
			$self->{tokens_index} += 1;
			return { type => 'variable_match', line_number => $tokens[0][2], variable => $tokens[0][1], };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'regex') {
			$self->{tokens_index} += 1;
			return { type => 'regex_match', line_number => $tokens[0][2], regex => $tokens[0][1], };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'string') {
			$self->{tokens_index} += 1;
			return { type => 'string_match', line_number => $tokens[0][2], string => $tokens[0][1], };
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '*' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[0] eq 'identifier') {
			$self->{tokens_index} += 2;
			return { type => 'token_type_match', line_number => $tokens[0][2], value => $tokens[1][1], };
		} else {
			$self->confess_at_current_offset('expected match item');
		}
	}
	return $context_value;
}
sub context_action_block {
	my ($self, $context_value) = @_;
	my @tokens;

	$self->confess_at_current_offset('"{" expected for code block')
		unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '{';
	$self->{tokens_index} += 1;
	$context_value = $self->context_match_action([]);
	$self->confess_at_current_offset('"}" expected after code block')
		unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '}';
	$self->{tokens_index} += 1;
	return $context_value;
}
sub context_match_action {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'variable' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '=') {
			$self->{tokens_index} += 2;
			push @$context_value, { type => 'assign_item_statement', line_number => $tokens[0][2], variable => $tokens[0][1], expression => $self->context_spawn_expression, };
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'variable' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '{') {
			$self->{tokens_index} += 2;
			my $var_key_expression = $self->context_spawn_expression;
			$self->confess_at_current_offset('"}" expected after key expression')
				unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[2] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '}';
			$self->{tokens_index} += 1;
			if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[3] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '{') {
				$self->{tokens_index} += 1;
				my $var_subkey_expression = $self->context_spawn_expression;
				$self->confess_at_current_offset('"}", "=" expected after sub-key expression')
					unless $self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[4] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '}' and ($tokens[5] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '=';
				$self->{tokens_index} += 2;
				push @$context_value, { type => 'assign_object_field_statement', line_number => $tokens[0][2], variable => $tokens[0][1], expression => $self->context_spawn_expression, subkey => $var_subkey_expression, key => $var_key_expression, };
			} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[3] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '[') {
				$self->{tokens_index} += 1;
				$self->confess_at_current_offset('"]", "=" expected after array access expression')
					unless $self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[4] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq ']' and ($tokens[5] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '=';
				$self->{tokens_index} += 2;
				push @$context_value, { type => 'assign_array_field_statement', line_number => $tokens[0][2], variable => $tokens[0][1], expression => $self->context_spawn_expression, key => $var_key_expression, };
			} else {
				$self->confess_at_current_offset('"=" expected after key expression')
					unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[3] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '=';
				$self->{tokens_index} += 1;
				push @$context_value, { type => 'assign_field_statement', line_number => $tokens[0][2], variable => $tokens[0][1], expression => $self->context_spawn_expression, key => $var_key_expression, };
			}
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'push') {
			$self->{tokens_index} += 1;
			push @$context_value, { type => 'push_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'return') {
			$self->{tokens_index} += 1;
			if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '}') {
				push @$context_value, { type => 'return_statement', line_number => $tokens[0][2], };
			} else {
				push @$context_value, { type => 'return_expression_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
			}
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'match') {
			$self->{tokens_index} += 1;
			my $var_statement = { type => 'match_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_specifier, };
			if ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'or' and ($tokens[2] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq 'die') {
				$self->{tokens_index} += 2;
				$var_statement->{death_expression} = $self->context_spawn_expression;
			}
			push @$context_value, $var_statement;
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'if') {
			$self->{tokens_index} += 1;
			push @$context_value, $self->context_if_chain({ type => 'if_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, });
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'switch') {
			$self->{tokens_index} += 1;
			$self->confess_at_current_offset('expected \'{\'')
				unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '{';
			$self->{tokens_index} += 1;
			push @$context_value, { type => 'switch_statement', line_number => $tokens[0][2], switch_cases => $self->context_switch_blocks([]), };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'while') {
			$self->{tokens_index} += 1;
			push @$context_value, { type => 'while_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'warn') {
			$self->{tokens_index} += 1;
			push @$context_value, { type => 'warn_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'die') {
			$self->{tokens_index} += 1;
			push @$context_value, { type => 'die_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
		} else {
			return $context_value;
		}
	}
	return $context_value;
}
sub context_switch_blocks {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '}') {
			$self->{tokens_index} += 1;
			return $context_value;
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'default') {
			$self->{tokens_index} += 1;
			push @$context_value, { type => 'default_case', line_number => $tokens[0][2], block => $self->context_action_block, };
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '}';
			$self->{tokens_index} += 1;
			return $context_value;
		} else {
			push @$context_value, { type => 'match_case', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, };
		}
	}
	return $context_value;
}
sub context_if_chain {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'elsif') {
			$self->{tokens_index} += 1;
			$context_value->{'branch'} = $self->context_if_chain({ type => 'elsif_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, });
			return $context_value;
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'else') {
			$self->{tokens_index} += 1;
			$context_value->{'branch'} = { type => 'else_statement', line_number => $tokens[0][2], block => $self->context_action_block, };
			return $context_value;
		} else {
			return $context_value;
		}
	}
	return $context_value;
}
sub context_spawn_expression {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] =~ /\A(\$\d++)\Z/) {
			$self->{tokens_index} += 1;
			if ($self->{tokens_index} + 3 <= @{$self->{tokens}} and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '{' and ($tokens[2] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq 'line_number' and ($tokens[3] = $self->{tokens}[$self->{tokens_index} + 2])->[1] eq '}') {
				$self->{tokens_index} += 3;
				return { type => 'get_token_line_number', line_number => $tokens[0][2], token => $tokens[0][1], };
			} elsif ($self->{tokens_index} + 3 <= @{$self->{tokens}} and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '{' and ($tokens[2] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq 'line_offset' and ($tokens[3] = $self->{tokens}[$self->{tokens_index} + 2])->[1] eq '}') {
				$self->{tokens_index} += 3;
				return { type => 'get_token_line_offset', line_number => $tokens[0][2], token => $tokens[0][1], };
			} else {
				return { type => 'get_token_text', line_number => $tokens[0][2], token => $tokens[0][1], };
			}
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '$_') {
			$self->{tokens_index} += 1;
			return $self->context_more_spawn_expression({ type => 'get_context', line_number => $tokens[0][2], });
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'pop') {
			$self->{tokens_index} += 1;
			warn ('pop expressions are deprecated');
			return { type => 'pop_list', line_number => $tokens[0][2], };
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '[' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq ']') {
			$self->{tokens_index} += 2;
			return { type => 'empty_list', line_number => $tokens[0][2], };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '[') {
			$self->{tokens_index} += 1;
			return { type => 'list_constructor', line_number => $tokens[0][2], arguments => $self->context_spawn_expression_list([]), };
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '{' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '}') {
			$self->{tokens_index} += 2;
			return { type => 'empty_hash', line_number => $tokens[0][2], };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '{') {
			$self->{tokens_index} += 1;
			return { type => 'hash_constructor', line_number => $tokens[0][2], arguments => $self->context_spawn_expression_hash([]), };
		} elsif ($self->{tokens_index} + 3 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq ':' and ($tokens[2] = $self->{tokens}[$self->{tokens_index} + 2])->[1] eq '{') {
			$self->{tokens_index} += 3;
			return { type => 'hash_constructor', line_number => $tokens[0][2], arguments => $self->context_spawn_expression_hash([ { type => 'bareword', line_number => $tokens[0][2], value => 'type', }, { type => 'bareword_string', line_number => $tokens[0][2], value => $tokens[0][1], }, { type => 'bareword', line_number => $tokens[0][2], value => 'line_number', }, { type => 'get_token_line_number', line_number => $tokens[0][2], token => '$0', }, ]), };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq 'undef') {
			$self->{tokens_index} += 1;
			return { type => 'undef', line_number => $tokens[0][2], };
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'context_reference' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '->') {
			$self->{tokens_index} += 2;
			return { type => 'call_context', line_number => $tokens[0][2], context => $tokens[0][1], argument => $self->context_spawn_expression, };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'context_reference') {
			$self->{tokens_index} += 1;
			return { type => 'call_context', line_number => $tokens[0][2], context => $tokens[0][1], };
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'function_reference' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '->') {
			$self->{tokens_index} += 2;
			return { type => 'call_function', line_number => $tokens[0][2], function => $tokens[0][1], argument => $self->context_spawn_expression, };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'function_reference') {
			$self->{tokens_index} += 1;
			return { type => 'call_function', line_number => $tokens[0][2], function => $tokens[0][1], };
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'substitution_regex' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '->') {
			$self->{tokens_index} += 2;
			return { type => 'call_substitution', line_number => $tokens[0][2], regex => $tokens[0][1], argument => $self->context_spawn_expression, };
		} elsif ($self->{tokens_index} + 2 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'variable' and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 1])->[1] eq '->') {
			$self->{tokens_index} += 2;
			return { type => 'call_variable', line_number => $tokens[0][2], variable => $tokens[0][1], argument => $self->context_spawn_expression, };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'variable') {
			$self->{tokens_index} += 1;
			return $self->context_more_spawn_expression({ type => 'variable_value', line_number => $tokens[0][2], variable => $tokens[0][1], });
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'string') {
			$self->{tokens_index} += 1;
			return { type => 'string', line_number => $tokens[0][2], string => $tokens[0][1], };
		} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[0] eq 'identifier') {
			$self->{tokens_index} += 1;
			return { type => 'bareword', line_number => $tokens[0][2], value => $tokens[0][1], };
		} else {
			$self->confess_at_current_offset('push expression expected');
		}
	}
	return $context_value;
}
sub context_more_spawn_expression {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '{') {
			$self->{tokens_index} += 1;
			$context_value = { type => 'access', line_number => $tokens[0][2], left_expression => $context_value, right_expression => $self->context_spawn_expression, };
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[1] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '}';
			$self->{tokens_index} += 1;
		} else {
			return $context_value;
		}
	}
	return $context_value;
}
sub context_spawn_expression_list {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq ']') {
			$self->{tokens_index} += 1;
			return $context_value;
		} else {
			push @$context_value, $self->context_spawn_expression;
			if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq ',') {
				$self->{tokens_index} += 1;
			} elsif ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq ']') {
				$self->{tokens_index} += 1;
				return $context_value;
			} else {
				return $context_value;
			}
		}
	}
	return $context_value;
}
sub context_spawn_expression_hash {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
	
		if ($self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '}') {
			$self->{tokens_index} += 1;
			return $context_value;
		} else {
			push @$context_value, $self->context_spawn_expression;
			$self->confess_at_current_offset('expected \'=>\'')
				unless $self->{tokens_index} + 1 <= @{$self->{tokens}} and ($tokens[0] = $self->{tokens}[$self->{tokens_index} + 0])->[1] eq '=>';
			$self->{tokens_index} += 1;
			push @$context_value, $self->context_spawn_expression;
		}
	}
	return $context_value;
}


##############################
##### native perl functions
##############################

sub main {
	require Data::Dumper;
	require Sugar::IO::File;
	# use Sugar::Lang::SyntaxIntermediateCompiler;

	my $parser = __PACKAGE__->new;
	foreach my $file (@_) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		my $tree = $parser->parse;
		say Dumper $tree;

		# my $compiler = Sugar::Lang::SyntaxIntermediateCompiler->new(syntax_definition_intermediate => $tree);
		# say $compiler->to_package;
	}
}

caller or main(@ARGV);



1;


