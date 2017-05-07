#!/usr/bin/env perl
package Sugar::Lang::GrammarCompiler;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use Sugar::IO::File;
use Sugar::Lang::SyntaxIntermediateCompiler;



our $tokens = [
	'code_block' => qr/\{\{.*?\}\}/s,
	'symbol' => qr/\{|\}|\[|\]|->|=>|=|,/,
	'package_identifier' => qr/[a-zA-Z_][a-zA-Z0-9_]*+(\:\:[a-zA-Z_][a-zA-Z0-9_]*+)*+/,
	'identifier' => qr/[a-zA-Z_][a-zA-Z0-9_]*+/,
	'string' => qr/'([^\\']|\\[\\'])*+'/s,
	'regex' => qr/\/([^\\\/]|\\.)*+\/[msixpodualn]*/s,
	'variable' => qr/\$\w++/,
	'context_reference' => qr/!\w++/,
	'function_reference' => qr/\&\w++/,
	'comment' => qr/\#[^\n]*+\n/s,
	'whitespace' => qr/\s++/s,
];

our $ignored_tokens = [
	'comment',
	'whitespace',
];

our $contexts = {
	action_block => 'context_action_block',
	context_definition => 'context_context_definition',
	def_value => 'context_def_value',
	if_chain => 'context_if_chain',
	ignored_tokens_list => 'context_ignored_tokens_list',
	match_action => 'context_match_action',
	match_list => 'context_match_list',
	root => 'context_root',
	spawn_expression => 'context_spawn_expression',
	spawn_expression_hash => 'context_spawn_expression_hash',
	spawn_expression_list => 'context_spawn_expression_list',
	token_definition => 'context_token_definition',
};



sub new {
	my ($class, %opts) = @_;

	$opts{token_regexes} = $tokens;
	$opts{ignored_tokens} = $ignored_tokens;
	$opts{contexts} = $contexts;

	my $self = $class->SUPER::new(%opts);

	return $self
}

sub main {
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


sub context_action_block {
	my ($self, $context_value) = @_;

	while ($self->more_tokens) {
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
	return $context_value;
}

sub context_context_definition {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'default' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, undef;
			push @$context_list, $self->context_match_action([]);
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
		} else {
			push @$context_list, $self->context_match_list([]);
			$self->confess_at_current_offset('expected \'{\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_match_action([]);
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
		}
	}
	return $context_list;
}

sub context_def_value {
	my ($self, $context_value) = @_;

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = $tokens[0][1];
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s) {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = $tokens[0][1];
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\w++\Z/) {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = $tokens[0][1];
			return $context_value;
		} else {
			$self->confess_at_current_offset('unexpected token in def_value');
		}
	}
	return $context_value;
}

sub context_if_chain {
	my ($self, $context_object) = @_;

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'elsif') {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{'branch'} = $self->context_if_chain({ 'type' => 'elsif_statement', 'line_number' => $tokens[0][2], 'match_list' => $self->context_match_list([]), 'block' => $self->context_action_block, });
			return $context_object;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'else') {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_object->{'branch'} = { 'type' => 'else_statement', 'line_number' => $tokens[0][2], 'block' => $self->context_action_block, };
			return $context_object;
		} else {
			return $context_object;
		}
	}
	return $context_object;
}

sub context_ignored_tokens_list {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/) {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $tokens[0][1];
		} else {
			$self->confess_at_current_offset('unexpected token in ignored_tokens_list');
		}
	}
	return $context_list;
}

sub context_match_action {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '$_' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { 'type' => 'assign_item_statement', 'expression' => $self->context_spawn_expression, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '$_' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $self->context_spawn_expression;
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_spawn_expression;
			$self->confess_at_current_offset('expected \'}\', \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { 'type' => 'assign_object_field_statement', 'line_number' => $tokens[0][2], 'expression' => $self->context_spawn_expression, 'subkey' => pop @$context_list, 'key' => pop @$context_list, };
			}
			elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens_freeze = @tokens;
			my @tokens = @tokens_freeze;
			@tokens = (@tokens, $self->step_tokens(1));
			$self->confess_at_current_offset('expected \']\', \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { 'type' => 'assign_array_field_statement', 'line_number' => $tokens[0][2], 'expression' => $self->context_spawn_expression, 'key' => pop @$context_list, };
			}
			else {
			$self->confess_at_current_offset('expected \'=\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=';
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { 'type' => 'assign_field_statement', 'line_number' => $tokens[0][2], 'expression' => $self->context_spawn_expression, 'key' => pop @$context_list, };
			}
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'push') {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { 'type' => 'push_statement', 'line_number' => $tokens[0][2], 'expression' => $self->context_spawn_expression, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'return') {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { 'type' => 'return_statement', 'line_number' => $tokens[0][2], };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'match') {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { 'type' => 'match_statement', 'line_number' => $tokens[0][2], 'match_list' => $self->context_match_list([]), };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'if') {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_if_chain({ 'type' => 'if_statement', 'line_number' => $tokens[0][2], 'match_list' => $self->context_match_list([]), 'block' => $self->context_action_block, });
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'while') {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { 'type' => 'while_statement', 'line_number' => $tokens[0][2], 'match_list' => $self->context_match_list([]), 'block' => $self->context_action_block, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'warn') {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { 'type' => 'warn_statement', 'line_number' => $tokens[0][2], 'expression' => $self->context_spawn_expression, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'die') {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { 'type' => 'die_statement', 'line_number' => $tokens[0][2], 'expression' => $self->context_spawn_expression, };
		} else {
			return $context_list;
		}
	}
	return $context_list;
}

sub context_match_list {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\w++\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq ',') {
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $tokens[0][1];
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\w++\Z/) {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $tokens[0][1];
			return $context_list;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq ',') {
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $tokens[0][1];
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s) {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $tokens[0][1];
			return $context_list;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq ',') {
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $tokens[0][1];
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $tokens[0][1];
			return $context_list;
		} else {
			$self->confess_at_current_offset('unexpected end of match list');
		}
	}
	return $context_list;
}

sub context_root {
	my ($self) = @_;
	my $context_object = {};

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{'variables'}{$tokens[0][1]} = $self->context_def_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'package' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+(\:\:[a-zA-Z_][a-zA-Z0-9_]*+)*+\Z/) {
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{'package_identifier'} = $tokens[1][1];
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'tokens' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{'tokens'} = $self->context_token_definition([]);
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'ignored_tokens' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			@tokens = (@tokens, $self->step_tokens(2));
			$context_object->{'ignored_tokens'} = $self->context_ignored_tokens_list([]);
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'item' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'context' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 3][1] eq '{') {
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object->{'item_contexts'}{$tokens[2][1]} = $self->context_context_definition([]);
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'list' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'context' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 3][1] eq '{') {
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object->{'list_contexts'}{$tokens[2][1]} = $self->context_context_definition([]);
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'object' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'context' and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 3][1] eq '{') {
			@tokens = (@tokens, $self->step_tokens(4));
			$context_object->{'object_contexts'}{$tokens[2][1]} = $self->context_context_definition([]);
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'sub' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] =~ /\A\{\{.*?\}\}\Z/s) {
			@tokens = (@tokens, $self->step_tokens(3));
			$context_object->{'subroutines'}{$tokens[1][1]} = $tokens[2][1];
		} else {
			return $context_object;
		}
	}
	return $context_object;
}

sub context_spawn_expression {
	my ($self, $context_value) = @_;

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\d++\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 2][1] eq 'line_number' and $self->{tokens}[$self->{tokens_index} + 3][1] eq '}') {
			@tokens = (@tokens, $self->step_tokens(4));
			$context_value = { 'type' => 'get_token_line_number', 'token' => $tokens[0][1], };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\d++\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 2][1] eq 'line_offset' and $self->{tokens}[$self->{tokens_index} + 3][1] eq '}') {
			@tokens = (@tokens, $self->step_tokens(4));
			$context_value = { 'type' => 'get_token_line_offset', 'token' => $tokens[0][1], };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\d++\Z/) {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = { 'type' => 'get_token_text', 'token' => $tokens[0][1], };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '$_') {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = { 'type' => 'get_context', };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'pop') {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = { 'type' => 'pop_list', };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A!\w++\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '->') {
			@tokens = (@tokens, $self->step_tokens(2));
			$context_value = { 'type' => 'call_context', 'context' => $tokens[0][1], 'argument' => $self->context_spawn_expression, };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A!\w++\Z/) {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = { 'type' => 'call_context', 'context' => $tokens[0][1], };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\&\w++\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '->') {
			@tokens = (@tokens, $self->step_tokens(2));
			$context_value = { 'type' => 'call_function', 'function' => $tokens[0][1], 'argument' => $self->context_spawn_expression, };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\&\w++\Z/) {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = { 'type' => 'call_function', 'function' => $tokens[0][1], };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = { 'type' => 'string', 'string' => $tokens[0][1], };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'undef') {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = { 'type' => 'undef', };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ']') {
			@tokens = (@tokens, $self->step_tokens(2));
			$context_value = { 'type' => 'empty_list', };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '}') {
			@tokens = (@tokens, $self->step_tokens(2));
			$context_value = { 'type' => 'empty_hash', };
			return $context_value;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			@tokens = (@tokens, $self->step_tokens(1));
			$context_value = { 'type' => 'hash_constructor', 'arguments' => $self->context_spawn_expression_hash([]), };
			return $context_value;
		} else {
			$self->confess_at_current_offset('push expression expected');
		}
	}
	return $context_value;
}

sub context_spawn_expression_hash {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
		} else {
			push @$context_list, $self->context_spawn_expression;
			$self->confess_at_current_offset('expected \'=>\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=>';
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $self->context_spawn_expression;
		}
	}
	return $context_list;
}

sub context_spawn_expression_list {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A!\w++\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq ']') {
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $tokens[0][1];
			return $context_list;
		} else {
			$self->confess_at_current_offset('push expression list expected');
		}
	}
	return $context_list;
}

sub context_token_definition {
	my ($self, $context_list) = @_;

	while ($self->more_tokens) {
		my @tokens;
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			@tokens = (@tokens, $self->step_tokens(1));
			return $context_list;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=>') {
			@tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, $tokens[0][1];
			push @$context_list, $self->context_def_value;
		} else {
			$self->confess_at_current_offset('unexpected token in token_definition');
		}
	}
	return $context_list;
}

