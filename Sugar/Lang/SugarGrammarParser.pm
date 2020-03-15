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
our $var_symbol_regex = qr/\(|\)|\{|\}|\[|\]|->|=>|=|,|\||\*|:|\@|\?/;
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
	match_list_specifier_branch => 'context_match_list_specifier_branch',
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
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_root')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @{$context_value->{global_variable_names}}, $tokens[0][1];
			$context_value->{global_variable_expressions}{$tokens[0][1]} = $self->context_def_value;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'package' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'package_identifier')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value->{package_identifier} = $tokens[1][1];
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'package' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value->{package_identifier} = $tokens[1][1];
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'tokens' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value->{tokens} = $self->context_token_definition([]);
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'ignored_tokens' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value->{ignored_tokens} = $self->context_ignored_tokens_list([]);
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 4 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] =~ /\A(item|list|object)\Z/ and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] =~ /\A(context|sub)\Z/ and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>' and ($tokens[4] = $self->context_match_list_specifier))) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			my $var_context = { type => 'context_definition', line_number => $tokens[0][2], context_type => $tokens[0][1], identifier => $tokens[2][1], block => [ { type => 'match_statement', line_number => $tokens[0][2], match_list => $tokens[4], }, { type => 'return_statement', line_number => $tokens[0][2], }, ], };
			push @{$context_value->{contexts}}, $var_context;
			$context_value->{contexts_by_name}{$tokens[2][1]} = $var_context;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] =~ /\A(item|list|object)\Z/ and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] =~ /\A(context|sub)\Z/ and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[3] = $self->context_action_block))) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			my $var_context = { type => 'context_definition', line_number => $tokens[0][2], context_type => $tokens[0][1], identifier => $tokens[2][1], block => $tokens[3], };
			push @{$context_value->{contexts}}, $var_context;
			$context_value->{contexts_by_name}{$tokens[2][1]} = $var_context;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'sub' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'code_block')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @{$context_value->{subroutines}}, { type => 'subroutine', line_number => $tokens[0][2], identifier => $tokens[1][1], code_block => $tokens[2][1], };
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_def_value {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_def_value')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'string')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'string_value', line_number => $tokens[0][2], value => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'substitution_regex')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'substitution_regex_value', line_number => $tokens[0][2], value => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'regex')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'regex_value', line_number => $tokens[0][2], value => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'variable')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'variable_value', line_number => $tokens[0][2], value => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			$self->confess_at_current_offset('unexpected token in def_value');
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_token_definition {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_token_definition')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, { type => 'token_definition', line_number => $tokens[0][2], identifier => $tokens[0][1], value => $self->context_def_value, };
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			$self->confess_at_current_offset('unexpected token in token_definition');
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_ignored_tokens_list {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_ignored_tokens_list')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, $tokens[0][1];
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			$self->confess_at_current_offset('unexpected token in ignored_tokens_list');
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_match_list_specifier {
	my ($self, $context_value) = @_;
	my @tokens;
	my $save_tokens_index = $self->{tokens_index};

	push @$context_value, $self->context_match_list_specifier_branch;
	$save_tokens_index = $self->{tokens_index};
	while (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '|')) {
		$save_tokens_index = $self->{tokens_index};
		$save_tokens_index = $self->{tokens_index};
		push @$context_value, $self->context_match_list_specifier_branch;
		$save_tokens_index = $self->{tokens_index};
	}
	$self->{tokens_index} = $save_tokens_index;
	return $context_value;
}
sub context_match_list_specifier_branch {
	my ($self, $context_value) = @_;
	my @tokens;
	my $save_tokens_index = $self->{tokens_index};

	$context_value = { match_conditions => $self->context_match_conditions_list, };
	return $context_value;
}
sub context_match_conditions_list {
	my ($self, $context_value) = @_;
	my @tokens;
	my $save_tokens_index = $self->{tokens_index};

	push @$context_value, $self->context_match_item;
	$save_tokens_index = $self->{tokens_index};
	while (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ',')) {
		$save_tokens_index = $self->{tokens_index};
		$save_tokens_index = $self->{tokens_index};
		push @$context_value, $self->context_match_item;
		$save_tokens_index = $self->{tokens_index};
	}
	$self->{tokens_index} = $save_tokens_index;
	return $context_value;
}
sub context_match_list_arrow {
	my ($self, $context_value) = @_;
	my @tokens;
	my $save_tokens_index = $self->{tokens_index};

	$context_value = $self->context_match_list_specifier;
	$save_tokens_index = $self->{tokens_index};
	$self->confess_at_offset('expected \'=>\'', $save_tokens_index)
		unless ((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>');
	$save_tokens_index = $self->{tokens_index};
	return $context_value;
}
sub context_match_item {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_match_item')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '@' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[' and ($tokens[2] = $self->context_match_list_specifier) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'optional_loop_matchgroup', line_number => $tokens[0][2], branching_match_list => $tokens[2], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '?' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[' and ($tokens[2] = $self->context_match_list_specifier) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'optional_matchgroup', line_number => $tokens[0][2], branching_match_list => $tokens[2], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(' and ($tokens[1] = $self->context_match_list_specifier) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'lookahead_matchgroup', line_number => $tokens[0][2], branching_match_list => $tokens[1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 6 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ':' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[4] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}' and ($tokens[5] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value = $self->context_match_item;
			$context_value->{assign_object_type} = $tokens[0][1];
			$context_value->{assign_object_value} = $tokens[3][1];
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 4 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value = $self->context_match_item;
			$context_value->{assign_object_value} = $tokens[1][1];
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[1] = $self->context_spawn_expression) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value = $self->context_match_item;
			$context_value->{assign_object_expression_value} = $tokens[1];
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value = $self->context_match_item;
			$context_value->{assign_list_value} = 'true';
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'variable' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value = $self->context_match_item;
			$context_value->{assign_variable} = $tokens[0][1];
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 6 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ':' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[4] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}' and ($tokens[5] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>' and ($tokens[6] = $self->context_spawn_expression))) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'assignment_nonmatch', line_number => $tokens[0][2], assign_object_type => $tokens[0][1], assign_object_value => $tokens[3][1], expression => $tokens[6], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 4 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>' and ($tokens[4] = $self->context_spawn_expression))) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'assignment_nonmatch', line_number => $tokens[0][2], assign_object_value => $tokens[1][1], expression => $tokens[4], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[1] = $self->context_spawn_expression) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>' and ($tokens[4] = $self->context_spawn_expression))) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'assignment_nonmatch', line_number => $tokens[0][2], assign_object_expression_value => $tokens[1], expression => $tokens[4], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>' and ($tokens[3] = $self->context_spawn_expression))) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'assignment_nonmatch', line_number => $tokens[0][2], assign_list_value => 'true', expression => $tokens[3], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'variable' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>' and ($tokens[2] = $self->context_spawn_expression))) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'assignment_nonmatch', line_number => $tokens[0][2], assign_variable => $tokens[0][1], expression => $tokens[2], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'function_reference' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '->' and ($tokens[2] = $self->context_spawn_expression))) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'function_match', line_number => $tokens[0][2], function => $tokens[0][1], argument => $tokens[2], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'function_reference')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'function_match', line_number => $tokens[0][2], function => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'context_reference' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '->' and ($tokens[2] = $self->context_spawn_expression))) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'context_match', line_number => $tokens[0][2], identifier => $tokens[0][1], argument => $tokens[2], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'context_reference')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'context_match', line_number => $tokens[0][2], identifier => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'variable')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'variable_match', line_number => $tokens[0][2], variable => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'regex')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'regex_match', line_number => $tokens[0][2], regex => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'string')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'string_match', line_number => $tokens[0][2], string => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '*' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'token_type_match', line_number => $tokens[0][2], value => $tokens[1][1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'die' and ($tokens[1] = $self->context_spawn_expression))) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'death_match', line_number => $tokens[0][2], argument => $tokens[1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'return')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'return_match', line_number => $tokens[0][2], };
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			$self->confess_at_current_offset('expected match item');
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_action_block {
	my ($self, $context_value) = @_;
	my @tokens;
	my $save_tokens_index = $self->{tokens_index};

	$save_tokens_index = $self->{tokens_index};
	$self->confess_at_offset('"{" expected for code block', $save_tokens_index)
		unless ((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{');
	$save_tokens_index = $self->{tokens_index};
	$context_value = $self->context_match_action([]);
	$save_tokens_index = $self->{tokens_index};
	$self->confess_at_offset('"}" expected after code block', $save_tokens_index)
		unless ((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}');
	$save_tokens_index = $self->{tokens_index};
	return $context_value;
}
sub context_match_action {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_match_action')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'variable' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, { type => 'assign_item_statement', line_number => $tokens[0][2], variable => $tokens[0][1], expression => $self->context_spawn_expression, };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'variable' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			my $var_key_expression = $self->context_spawn_expression;
			$save_tokens_index = $self->{tokens_index};
			$self->confess_at_offset('"}" expected after key expression', $save_tokens_index)
				unless ((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}');
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{')) {
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
				my $var_subkey_expression = $self->context_spawn_expression;
				$save_tokens_index = $self->{tokens_index};
				$self->confess_at_offset('"}", "=" expected after sub-key expression', $save_tokens_index)
					unless ((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[4] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}' and ($tokens[5] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=');
				$save_tokens_index = $self->{tokens_index};
				push @$context_value, { type => 'assign_object_field_statement', line_number => $tokens[0][2], variable => $tokens[0][1], expression => $self->context_spawn_expression, subkey => $var_subkey_expression, key => $var_key_expression, };
				$save_tokens_index = $self->{tokens_index};
			} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[')) {
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
				$self->confess_at_offset('"]", "=" expected after array access expression', $save_tokens_index)
					unless ((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[4] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']' and ($tokens[5] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=');
				$save_tokens_index = $self->{tokens_index};
				push @$context_value, { type => 'assign_array_field_statement', line_number => $tokens[0][2], variable => $tokens[0][1], expression => $self->context_spawn_expression, key => $var_key_expression, };
				$save_tokens_index = $self->{tokens_index};
			} else {
				$self->{tokens_index} = $save_tokens_index;
				$save_tokens_index = $self->{tokens_index};
				$self->confess_at_offset('"=" expected after key expression', $save_tokens_index)
					unless ((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=');
				$save_tokens_index = $self->{tokens_index};
				push @$context_value, { type => 'assign_field_statement', line_number => $tokens[0][2], variable => $tokens[0][1], expression => $self->context_spawn_expression, key => $var_key_expression, };
				$save_tokens_index = $self->{tokens_index};
			}
			$self->{tokens_index} = $save_tokens_index;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'push')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, { type => 'push_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'return')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			if (((($self->{tokens_index} = $save_tokens_index) + 0 <= @{$self->{tokens}}) and (do { my $save_tokens_index = $self->{tokens_index}; my $lookahead_result = (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}'));
								$self->{tokens_index} = $save_tokens_index; $lookahead_result; }))) {
				$save_tokens_index = $self->{tokens_index};
				push @$context_value, { type => 'return_statement', line_number => $tokens[0][2], };
				$save_tokens_index = $self->{tokens_index};
			} else {
				$self->{tokens_index} = $save_tokens_index;
				push @$context_value, { type => 'return_expression_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
				$save_tokens_index = $self->{tokens_index};
			}
			$self->{tokens_index} = $save_tokens_index;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'match')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			my $var_statement = { type => 'match_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_specifier, };
			$save_tokens_index = $self->{tokens_index};
			if (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'or' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'die')) {
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
				$var_statement->{death_expression} = $self->context_spawn_expression;
				$save_tokens_index = $self->{tokens_index};
			}
			$self->{tokens_index} = $save_tokens_index;
			push @$context_value, $var_statement;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'if')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, $self->context_if_chain({ type => 'if_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, });
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'switch')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$self->confess_at_offset('expected \'{\'', $save_tokens_index)
				unless ((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{');
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, { type => 'switch_statement', line_number => $tokens[0][2], switch_cases => $self->context_switch_blocks([]), };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'while')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, { type => 'while_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'warn')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, { type => 'warn_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'die')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, { type => 'die_statement', line_number => $tokens[0][2], expression => $self->context_spawn_expression, };
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_switch_blocks {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_switch_blocks')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'default')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, { type => 'default_case', line_number => $tokens[0][2], block => $self->context_action_block, };
			$save_tokens_index = $self->{tokens_index};
			$self->confess_at_offset('expected \'}\'', $save_tokens_index)
				unless ((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}');
			$save_tokens_index = $self->{tokens_index};
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			push @$context_value, { type => 'match_case', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, };
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_if_chain {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_if_chain')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'elsif')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value->{'branch'} = $self->context_if_chain({ type => 'elsif_statement', line_number => $tokens[0][2], match_list => $self->context_match_list_arrow, block => $self->context_action_block, });
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'else')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value->{'branch'} = { type => 'else_statement', line_number => $tokens[0][2], block => $self->context_action_block, };
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_spawn_expression {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_spawn_expression')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] =~ /\A(\$\d++)\Z/)) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			if (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'line_number' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}')) {
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
				return { type => 'get_token_line_number', line_number => $tokens[0][2], token => $tokens[0][1], };
				$save_tokens_index = $self->{tokens_index};
			} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'line_offset' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}')) {
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
				return { type => 'get_token_line_offset', line_number => $tokens[0][2], token => $tokens[0][1], };
				$save_tokens_index = $self->{tokens_index};
			} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'type' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}')) {
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
				return { type => 'get_token_type', line_number => $tokens[0][2], token => $tokens[0][1], };
				$save_tokens_index = $self->{tokens_index};
			} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'value' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}')) {
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
				return { type => 'get_raw_token', line_number => $tokens[0][2], token => $tokens[0][1], };
				$save_tokens_index = $self->{tokens_index};
			} else {
				$self->{tokens_index} = $save_tokens_index;
				return { type => 'get_token_text', line_number => $tokens[0][2], token => $tokens[0][1], };
				$save_tokens_index = $self->{tokens_index};
			}
			$self->{tokens_index} = $save_tokens_index;
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '$_')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $self->context_more_spawn_expression({ type => 'get_context', line_number => $tokens[0][2], });
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'pop')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			warn ('pop expressions are deprecated');
			return { type => 'pop_list', line_number => $tokens[0][2], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'empty_list', line_number => $tokens[0][2], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'list_constructor', line_number => $tokens[0][2], arguments => $self->context_spawn_expression_list([]), };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'empty_hash', line_number => $tokens[0][2], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'hash_constructor', line_number => $tokens[0][2], arguments => $self->context_spawn_expression_hash([]), };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ':' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'hash_constructor', line_number => $tokens[0][2], arguments => $self->context_spawn_expression_hash([ { type => 'bareword', line_number => $tokens[0][2], value => 'type', }, { type => 'bareword_string', line_number => $tokens[0][2], value => $tokens[0][1], }, { type => 'bareword', line_number => $tokens[0][2], value => 'line_number', }, { type => 'get_token_line_number', line_number => $tokens[0][2], token => '$0', }, ]), };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'undef')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'undef', line_number => $tokens[0][2], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'context_reference' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '->')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $self->context_more_spawn_expression({ type => 'call_context', line_number => $tokens[0][2], context => $tokens[0][1], argument => $self->context_spawn_expression, });
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'context_reference')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $self->context_more_spawn_expression({ type => 'call_context', line_number => $tokens[0][2], context => $tokens[0][1], });
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'function_reference' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '->')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $self->context_more_spawn_expression({ type => 'call_function', line_number => $tokens[0][2], function => $tokens[0][1], argument => $self->context_spawn_expression, });
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'function_reference')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $self->context_more_spawn_expression({ type => 'call_function', line_number => $tokens[0][2], function => $tokens[0][1], });
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'substitution_regex' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '->')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'call_substitution', line_number => $tokens[0][2], regex => $tokens[0][1], argument => $self->context_spawn_expression, };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'variable' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '->')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'call_variable', line_number => $tokens[0][2], variable => $tokens[0][1], argument => $self->context_spawn_expression, };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'variable')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $self->context_more_spawn_expression({ type => 'variable_value', line_number => $tokens[0][2], variable => $tokens[0][1], });
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'string')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'string', line_number => $tokens[0][2], string => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return { type => 'bareword', line_number => $tokens[0][2], value => $tokens[0][1], };
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			$self->confess_at_current_offset('push expression expected');
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_more_spawn_expression {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_more_spawn_expression')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			$context_value = { type => 'access', line_number => $tokens[0][2], left_expression => $context_value, right_expression => $self->context_spawn_expression, };
			$save_tokens_index = $self->{tokens_index};
			$self->confess_at_offset('expected \'}\'', $save_tokens_index)
				unless ((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}');
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_spawn_expression_list {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_spawn_expression_list')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			push @$context_value, $self->context_spawn_expression;
			$save_tokens_index = $self->{tokens_index};
			if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ',')) {
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
			} elsif (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']')) {
				$save_tokens_index = $self->{tokens_index};
				$save_tokens_index = $self->{tokens_index};
				return $context_value;
				$save_tokens_index = $self->{tokens_index};
			} else {
				$self->{tokens_index} = $save_tokens_index;
				return $context_value;
				$save_tokens_index = $self->{tokens_index};
			}
			$self->{tokens_index} = $save_tokens_index;
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
	}
	return $context_value;
}
sub context_spawn_expression_hash {
	my ($self, $context_value) = @_;
	my $last_loop_index = -1;
	while (1) {
		$self->confess_at_current_offset('infinite loop in context_spawn_expression_hash')
				if $last_loop_index == $self->{tokens_index};
		$last_loop_index = $self->{tokens_index};
		my @tokens;
	my $save_tokens_index = $self->{tokens_index};
	
		$save_tokens_index = $self->{tokens_index};
		if (((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}')) {
			$save_tokens_index = $self->{tokens_index};
			$save_tokens_index = $self->{tokens_index};
			return $context_value;
			$save_tokens_index = $self->{tokens_index};
		} else {
			$self->{tokens_index} = $save_tokens_index;
			push @$context_value, $self->context_spawn_expression;
			$save_tokens_index = $self->{tokens_index};
			$self->confess_at_offset('expected \'=>\'', $save_tokens_index)
				unless ((($self->{tokens_index} = $save_tokens_index) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>');
			$save_tokens_index = $self->{tokens_index};
			push @$context_value, $self->context_spawn_expression;
			$save_tokens_index = $self->{tokens_index};
		}
		$self->{tokens_index} = $save_tokens_index;
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
		say &Data::Dumper::Dumper ($tree);

		# my $compiler = Sugar::Lang::SyntaxIntermediateCompiler->new(syntax_definition_intermediate => $tree);
		# say $compiler->to_package;
	}
}

caller or main(@ARGV);



1;


