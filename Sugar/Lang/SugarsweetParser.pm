#!/usr/bin/env perl
package Sugar::Lang::SugarsweetParser;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_code_block_regex = qr/\{\{.*?\}\}/s;
our $var_symbol_regex = qr/\(|\)|\{|\}|\[|\]|<=|>=|<|>|->|=>|==|=~|\+=|!~|!=|=|,|\.|\+|\-|\*|\/|::|:|;/;
our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_string_regex = qr/'(?:[^\\']|\\.)*+'|"(?:[^\\"]|\\.)*+"/s;
our $var_integer_regex = qr/-?\d++/;
our $var_regex_regex = qr/\/(?:[^\\\/]|\\.)*+\/[msixgcpodualn]*+/s;
our $var_substitution_regex_regex = qr/s\/(?:[^\\\/]|\\.)*+\/(?:[^\\\/]|\\.)*+\/[msixpodualngc]*+/s;
our $var_comment_regex = qr/\#[^\n]*+\n/s;
our $var_whitespace_regex = qr/\s++/s;


our $tokens = [
	'code_block' => $var_code_block_regex,
	'regex' => $var_regex_regex,
	'substitution_regex' => $var_substitution_regex_regex,
	'identifier' => $var_identifier_regex,
	'string' => $var_string_regex,
	'integer' => $var_integer_regex,
	'symbol' => $var_symbol_regex,
	'comment' => $var_comment_regex,
	'whitespace' => $var_whitespace_regex,
];

our $ignored_tokens = [
	'comment',
	'whitespace',
];

our $contexts = {
	root => 'context_root',
	class_identifier => 'context_class_identifier',
	class_definition => 'context_class_definition',
	class_definition_block => 'context_class_definition_block',
	statements_block => 'context_statements_block',
	statements_block_list => 'context_statements_block_list',
	more_statement => 'context_more_statement',
	switch_statements_block => 'context_switch_statements_block',
	switch_block_list => 'context_switch_block_list',
	switch_case_list => 'context_switch_case_list',
	expression => 'context_expression',
	more_expression => 'context_more_expression',
	method_argument_list => 'context_method_argument_list',
	argument_list => 'context_argument_list',
	expression_list => 'context_expression_list',
	tree_constructor => 'context_tree_constructor',
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
	while ($self->{tokens_index} < @{$self->{tokens}}) {
		my @tokens;
	
		if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'class') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @{$context_value->{classes}}, $self->context_class_definition({ type => 'class_declaration', line_number => $tokens[0][2], name => $self->context_class_identifier, });
		} else {
			$self->{tokens_index} = $self->{save_tokens_index};
			$self->confess_at_current_offset('expected class definition');
		}
		$self->{tokens_index} = $self->{save_tokens_index};
	}
	return $context_value;
}
sub context_class_identifier {
	my ($self, $context_value) = @_;
	my @tokens;

	$self->confess_at_current_offset('expected identifier token')
		unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier';
	$self->{save_tokens_index} = $self->{tokens_index};
	push @$context_value, $tokens[0][1];
	while ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '::') {
		$self->{save_tokens_index} = $self->{tokens_index};
		$self->confess_at_current_offset('expected identifier after "::" token')
			unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier';
		$self->{save_tokens_index} = $self->{tokens_index};
		push @$context_value, $tokens[2][1];
	}
	return $context_value;
}
sub context_class_definition {
	my ($self, $context_value) = @_;
	my @tokens;

	$self->confess_at_current_offset('"{" expected before code block')
		unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{';
	$self->{save_tokens_index} = $self->{tokens_index};
	$context_value = $self->context_class_definition_block($context_value);
	$self->confess_at_current_offset('"}" expected after code block')
		unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}';
	$self->{save_tokens_index} = $self->{tokens_index};
	return $context_value;
}
sub context_class_definition_block {
	my ($self, $context_value) = @_;
	while ($self->{tokens_index} < @{$self->{tokens}}) {
		my @tokens;
	
		if ((($self->{tokens_index} = $self->{save_tokens_index}) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'sub' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '_constructor' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_argument_list = $self->context_method_argument_list;
			$self->confess_at_current_offset('expected ")" after argument list')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')';
			$self->{save_tokens_index} = $self->{tokens_index};
			push @{$context_value->{constructors}}, { type => 'function_declaration', line_number => $tokens[0][2], return_type => $tokens[0][1], name => $tokens[1][1], argument_list => $var_argument_list, block => $self->context_statements_block, };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 4 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'sub' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_argument_list = $self->context_method_argument_list;
			$self->confess_at_current_offset('expected ")" after argument list')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[4] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')';
			$self->{save_tokens_index} = $self->{tokens_index};
			if ((($self->{tokens_index} = $self->{save_tokens_index}) + 4 <= @{$self->{tokens}}) and ($tokens[5] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'native' and ($tokens[6] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ':' and ($tokens[7] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[8] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'code_block') {
				$self->{save_tokens_index} = $self->{tokens_index};
				push @{$context_value->{native_functions}}, { type => 'native_function_declaration', line_number => $tokens[0][2], return_type => $tokens[0][1], name => $tokens[2][1], argument_list => $var_argument_list, native_type => $tokens[7][1], block => $tokens[8][1], };
			} else {
				$self->{tokens_index} = $self->{save_tokens_index};
				push @{$context_value->{functions}}, { type => 'function_declaration', line_number => $tokens[0][2], return_type => $tokens[0][1], name => $tokens[2][1], argument_list => $var_argument_list, block => $self->context_statements_block, };
			}
			$self->{tokens_index} = $self->{save_tokens_index};
		} else {
			$self->{tokens_index} = $self->{save_tokens_index};
			return $context_value;
		}
		$self->{tokens_index} = $self->{save_tokens_index};
	}
	return $context_value;
}
sub context_statements_block {
	my ($self, $context_value) = @_;
	my @tokens;

	$self->confess_at_current_offset('"{" expected before code block')
		unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{';
	$self->{save_tokens_index} = $self->{tokens_index};
	$context_value = $self->context_statements_block_list([]);
	$self->confess_at_current_offset('"}" expected after code block')
		unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}';
	$self->{save_tokens_index} = $self->{tokens_index};
	return $context_value;
}
sub context_statements_block_list {
	my ($self, $context_value) = @_;
	while ($self->{tokens_index} < @{$self->{tokens}}) {
		my @tokens;
	
		if ((($self->{tokens_index} = $self->{save_tokens_index}) + 5 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'foreach' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[4] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'in') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			$self->confess_at_current_offset('expected ")" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[5] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')';
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, { type => 'foreach_statement', line_number => $tokens[0][2], variable_type => $tokens[2][1], identifier => $tokens[3][1], expression => $var_expression, block => $self->context_statements_block, };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'string' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'switch' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			$self->confess_at_current_offset('expected ")" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')';
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, { type => 'switch_statement', line_number => $tokens[0][2], expression_type => $tokens[0][1], expression => $var_expression, block => $self->context_switch_statements_block, };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'if' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			$self->confess_at_current_offset('expected ")" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')';
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_statement = { type => 'if_statement', line_number => $tokens[0][2], expression => $var_expression, block => $self->context_statements_block, };
			my $var_branch_statement = $var_statement;
			while ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'elsif' and ($tokens[4] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(') {
				$self->{save_tokens_index} = $self->{tokens_index};
				$var_expression = $self->context_expression;
				$self->confess_at_current_offset('expected ")" after expression')
					unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[5] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')';
				$self->{save_tokens_index} = $self->{tokens_index};
				$var_branch_statement->{branch} = { type => 'elsif_statement', line_number => $tokens[0][2], expression => $var_expression, block => $self->context_statements_block, };
				$var_branch_statement = $var_branch_statement->{branch};
			}
			if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'else') {
				$self->{save_tokens_index} = $self->{tokens_index};
				$var_branch_statement->{branch} = { type => 'else_statement', line_number => $tokens[0][2], block => $self->context_statements_block, };
			}
			$self->{tokens_index} = $self->{save_tokens_index};
			push @$context_value, $var_statement;
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'unless' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			$self->confess_at_current_offset('expected ")" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')';
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_statement = { type => 'if_statement', line_number => $tokens[0][2], expression => { type => 'not_expression', line_number => $tokens[0][2], expression => $var_expression, }, block => $self->context_statements_block, };
			my $var_branch_statement = $var_statement;
			if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'else') {
				$self->{save_tokens_index} = $self->{tokens_index};
				$var_branch_statement->{branch} = { type => 'else_statement', line_number => $tokens[0][2], block => $self->context_statements_block, };
			}
			$self->{tokens_index} = $self->{save_tokens_index};
			push @$context_value, $var_statement;
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'while' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			$self->confess_at_current_offset('expected ")" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')';
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, { type => 'while_statement', line_number => $tokens[0][2], expression => $var_expression, block => $self->context_statements_block, };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'return' and $self->{tokens}[$self->{tokens_index} + 0]->[1] =~ /\A(;|if|unless)\Z/) {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, $self->context_more_statement({ type => 'void_return_statement', line_number => $tokens[0][2], });
			$self->confess_at_current_offset('expected ";" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ';';
			$self->{save_tokens_index} = $self->{tokens_index};
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'return') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, $self->context_more_statement({ type => 'return_statement', line_number => $tokens[0][2], expression => $self->context_expression, });
			$self->confess_at_current_offset('expected ";" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ';';
			$self->{save_tokens_index} = $self->{tokens_index};
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'list' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'push') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \',\'')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ',';
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_right_expression = $self->context_expression;
			push @$context_value, $self->context_more_statement({ type => 'list_push_statement', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, });
			$self->confess_at_current_offset('expected ";" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ';';
			$self->{save_tokens_index} = $self->{tokens_index};
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'push') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \',\'')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ',';
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_right_expression = $self->context_expression;
			push @$context_value, $self->context_more_statement({ type => 'push_statement', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, });
			$self->confess_at_current_offset('expected ";" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ';';
			$self->{save_tokens_index} = $self->{tokens_index};
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'die') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, $self->context_more_statement({ type => 'die_statement', line_number => $tokens[0][2], expression => $self->context_expression, });
			$self->confess_at_current_offset('expected ";" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ';';
			$self->{save_tokens_index} = $self->{tokens_index};
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ';') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, { type => 'variable_declaration_statement', line_number => $tokens[0][2], variable_type => $tokens[0][1], identifier => $tokens[1][1], };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, { type => 'variable_declaration_assignment_statement', line_number => $tokens[0][2], variable_type => $tokens[0][1], identifier => $tokens[1][1], expression => $self->context_expression, };
			$self->confess_at_current_offset('expected ";" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ';';
			$self->{save_tokens_index} = $self->{tokens_index};
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, $self->context_more_statement({ type => 'variable_assignment_statement', line_number => $tokens[0][2], identifier => $tokens[0][1], expression => $self->context_expression, });
			$self->confess_at_current_offset('expected ";" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ';';
			$self->{save_tokens_index} = $self->{tokens_index};
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and $self->{tokens}[$self->{tokens_index} + 0]->[1] eq '}') {
			return $context_value;
		} else {
			$self->{tokens_index} = $self->{save_tokens_index};
			push @$context_value, $self->context_more_statement({ type => 'expression_statement', line_number => $tokens[0][2], expression => $self->context_expression, });
			$self->confess_at_current_offset('expected ";" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ';';
			$self->{save_tokens_index} = $self->{tokens_index};
		}
		$self->{tokens_index} = $self->{save_tokens_index};
	}
	return $context_value;
}
sub context_more_statement {
	my ($self, $context_value) = @_;
	while ($self->{tokens_index} < @{$self->{tokens}}) {
		my @tokens;
	
		if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'unless') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return { type => 'if_statement', line_number => $tokens[0][2], expression => { type => 'not_expression', line_number => $tokens[0][2], expression => $self->context_expression, }, block => [ $context_value, ], };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'if') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return { type => 'if_statement', line_number => $tokens[0][2], expression => $self->context_expression, block => [ $context_value, ], };
		} else {
			$self->{tokens_index} = $self->{save_tokens_index};
			return $context_value;
		}
		$self->{tokens_index} = $self->{save_tokens_index};
	}
	return $context_value;
}
sub context_switch_statements_block {
	my ($self, $context_value) = @_;
	my @tokens;

	$self->confess_at_current_offset('"{" expected before code block')
		unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{';
	$self->{save_tokens_index} = $self->{tokens_index};
	$context_value = $self->context_switch_block_list([]);
	$self->confess_at_current_offset('"}" expected after code block')
		unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}';
	$self->{save_tokens_index} = $self->{tokens_index};
	return $context_value;
}
sub context_switch_block_list {
	my ($self, $context_value) = @_;
	while ($self->{tokens_index} < @{$self->{tokens}}) {
		my @tokens;
	
		if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and $self->{tokens}[$self->{tokens_index} + 0]->[1] eq '}') {
			return $context_value;
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'default' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ':') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, { type => 'default_switch_block', line_number => $tokens[0][2], block => $self->context_statements_block, };
		} else {
			$self->{tokens_index} = $self->{save_tokens_index};
			push @$context_value, { type => 'match_switch_block', line_number => $tokens[0][2], case_list => $self->context_switch_case_list([]), block => $self->context_statements_block, };
		}
		$self->{tokens_index} = $self->{save_tokens_index};
	}
	return $context_value;
}
sub context_switch_case_list {
	my ($self, $context_value) = @_;
	while ($self->{tokens_index} < @{$self->{tokens}}) {
		my @tokens;
	
		if ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'integer' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ':') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, { type => 'integer_case', line_number => $tokens[0][2], value => $tokens[0][1], };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'string' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ':') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, { type => 'string_case', line_number => $tokens[0][2], value => $tokens[0][1], };
		} else {
			$self->{tokens_index} = $self->{save_tokens_index};
			return $context_value;
		}
		$self->{tokens_index} = $self->{save_tokens_index};
	}
	return $context_value;
}
sub context_expression {
	my ($self, $context_value) = @_;
	while ($self->{tokens_index} < @{$self->{tokens}}) {
		my @tokens;
	
		if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'integer') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return $self->context_more_expression({ type => 'integer_expression', line_number => $tokens[0][2], value => $tokens[0][1], expression_type => 'int', });
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'string') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return $self->context_more_expression({ type => 'string_expression', line_number => $tokens[0][2], value => $tokens[0][1], expression_type => 'string', });
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return $self->context_more_expression({ type => 'empty_list_expression', line_number => $tokens[0][2], expression_type => 'list', });
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = { type => 'list_constructor_expression', line_number => $tokens[0][2], expression_type => 'list', expression_list => $self->context_expression_list([]), };
			$self->confess_at_current_offset('expected "]" after expression list')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']';
			$self->{save_tokens_index} = $self->{tokens_index};
			return $self->context_more_expression($var_expression);
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return $self->context_more_expression({ type => 'empty_tree_expression', line_number => $tokens[0][2], expression_type => 'tree', });
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = { type => 'tree_constructor_expression', line_number => $tokens[0][2], expression_type => 'tree', expression_list => $self->context_tree_constructor([]), };
			$self->confess_at_current_offset('expected "}" after expression list')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}';
			$self->{save_tokens_index} = $self->{tokens_index};
			return $self->context_more_expression($var_expression);
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'join') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \',\'')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ',';
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_right_expression = $self->context_expression;
			return { type => 'join_expression', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, expression_type => 'string', };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'split') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \',\'')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ',';
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_right_expression = $self->context_expression;
			return { type => 'split_expression', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, expression_type => 'list', };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'list' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'length') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			return { type => 'length_expression', line_number => $tokens[0][2], expression => $var_expression, expression_type => 'int', static_type => $tokens[0][1], };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'length') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			return { type => 'length_expression', line_number => $tokens[0][2], expression => $var_expression, expression_type => 'int', };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'clone') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			return { type => 'clone_expression', line_number => $tokens[0][2], expression => $var_expression, expression_type => $var_expression->{expression_type}, };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'pop') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			return { type => 'pop_expression', line_number => $tokens[0][2], expression => $var_expression, };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'shift') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			return { type => 'shift_expression', line_number => $tokens[0][2], expression => $var_expression, };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'contains') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			return { type => 'contains_expression', line_number => $tokens[0][2], expression => $var_expression, expression_type => 'bool', };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'flatten') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_expression = $self->context_expression;
			return { type => 'flatten_expression', line_number => $tokens[0][2], expression => $var_expression, expression_type => 'list', };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'map' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \'}\'')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}';
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_right_expression = $self->context_expression;
			return { type => 'map_expression', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, expression_type => 'list', };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'grep' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '{') {
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \'}\'')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '}';
			$self->{save_tokens_index} = $self->{tokens_index};
			my $var_right_expression = $self->context_expression;
			return { type => 'grep_expression', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, expression_type => 'list', };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 4 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'match' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'integer' and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return $self->context_more_expression({ type => 'match_index_expression', line_number => $tokens[0][2], index => $tokens[2][1], });
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'match' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '.' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'pos') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return $self->context_more_expression({ type => 'match_position_expression', line_number => $tokens[0][2], });
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq 'not') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return { type => 'not_expression', line_number => $tokens[0][2], expression => $self->context_expression, };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return $self->context_more_expression({ type => 'variable_expression', line_number => $tokens[0][2], identifier => $tokens[0][1], });
		} else {
			$self->{tokens_index} = $self->{save_tokens_index};
			$self->confess_at_current_offset('expected expression');
		}
		$self->{tokens_index} = $self->{save_tokens_index};
	}
	return $context_value;
}
sub context_more_expression {
	my ($self, $context_value) = @_;
	while ($self->{tokens_index} < @{$self->{tokens}}) {
		my @tokens;
	
		if ((($self->{tokens_index} = $self->{save_tokens_index}) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '.' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(') {
			$self->{save_tokens_index} = $self->{tokens_index};
			$context_value = { type => 'access_call_expression', line_number => $tokens[0][2], expression => $context_value, identifier => $tokens[1][1], expression_list => $self->context_expression_list([]), };
			$self->confess_at_current_offset('expected ")" after expression list')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')';
			$self->{save_tokens_index} = $self->{tokens_index};
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 3 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '.' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier' and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return { type => 'object_assignment_expression', line_number => $tokens[0][2], left_expression => $context_value, right_expression => $self->context_expression, identifier => $tokens[1][1], };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return { type => 'assignment_expression', line_number => $tokens[0][2], left_expression => $context_value, right_expression => $self->context_expression, };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '+=') {
			$self->{save_tokens_index} = $self->{tokens_index};
			return { type => 'addition_assignment_expression', line_number => $tokens[0][2], operator => $tokens[0][1], left_expression => $context_value, right_expression => $self->context_expression, };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '.' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier') {
			$self->{save_tokens_index} = $self->{tokens_index};
			$context_value = { type => 'access_expression', line_number => $tokens[0][2], expression => $context_value, identifier => $tokens[1][1], };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '[') {
			$self->{save_tokens_index} = $self->{tokens_index};
			$context_value = { type => 'expression_access_expression', line_number => $tokens[0][2], left_expression => $context_value, right_expression => $self->context_expression, };
			$self->confess_at_current_offset('expected "]" after expression')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ']';
			$self->{save_tokens_index} = $self->{tokens_index};
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '(') {
			$self->{save_tokens_index} = $self->{tokens_index};
			$context_value = { type => 'call_expression', line_number => $tokens[0][2], expression => $context_value, expression_list => $self->context_expression_list([]), };
			$self->confess_at_current_offset('expected ")" after expression list')
				unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ')';
			$self->{save_tokens_index} = $self->{tokens_index};
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] =~ /\A(<=|>=|<|>)\Z/) {
			$self->{save_tokens_index} = $self->{tokens_index};
			$context_value = { type => 'numeric_comparison_expression', line_number => $tokens[0][2], operator => $tokens[0][1], left_expression => $context_value, right_expression => $self->context_expression, expression_type => 'bool', };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] =~ /\A(==|!=)\Z/) {
			$self->{save_tokens_index} = $self->{tokens_index};
			$context_value = { type => 'comparison_expression', line_number => $tokens[0][2], operator => $tokens[0][1], left_expression => $context_value, right_expression => $self->context_expression, expression_type => 'bool', };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] =~ /\A(=~|!~)\Z/ and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'regex') {
			$self->{save_tokens_index} = $self->{tokens_index};
			$context_value = { type => 'regex_match_expression', line_number => $tokens[0][2], expression => $context_value, operator => $tokens[0][1], regex => $tokens[1][1], expression_type => 'bool', };
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 2 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=~' and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'substitution_regex') {
			$self->{save_tokens_index} = $self->{tokens_index};
			$context_value = { type => 'regex_substitution_expression', line_number => $tokens[0][2], expression => $context_value, regex => $tokens[1][1], expression_type => 'string', };
		} else {
			$self->{tokens_index} = $self->{save_tokens_index};
			return $context_value;
		}
		$self->{tokens_index} = $self->{save_tokens_index};
	}
	return $context_value;
}
sub context_method_argument_list {
	my ($self, $context_value) = @_;
	my @tokens;

	return $self->context_argument_list([ { variable_type => 'self', identifier => 'self', }, ]);
}
sub context_argument_list {
	my ($self, $context_value) = @_;
	my @tokens;

	if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and $self->{tokens}[$self->{tokens_index} + 0]->[1] eq ')') {
		return $context_value;
	}
	$self->{tokens_index} = $self->{save_tokens_index};
	$self->confess_at_current_offset('expected variable type in argument list')
		unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier';
	$self->{save_tokens_index} = $self->{tokens_index};
	$self->confess_at_current_offset('expected variable identifier in argument list')
		unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier';
	$self->{save_tokens_index} = $self->{tokens_index};
	push @$context_value, { variable_type => $tokens[0][1], identifier => $tokens[1][1], };
	while ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ',') {
		$self->{save_tokens_index} = $self->{tokens_index};
		$self->confess_at_current_offset('expected variable type in argument list')
			unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[3] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier';
		$self->{save_tokens_index} = $self->{tokens_index};
		$self->confess_at_current_offset('expected variable identifier in argument list')
			unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[4] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier';
		$self->{save_tokens_index} = $self->{tokens_index};
		push @$context_value, { variable_type => $tokens[3][1], identifier => $tokens[4][1], };
	}
	return $context_value;
}
sub context_expression_list {
	my ($self, $context_value) = @_;
	my @tokens;

	if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and $self->{tokens}[$self->{tokens_index} + 0]->[1] eq ')') {
		return $context_value;
	} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and $self->{tokens}[$self->{tokens_index} + 0]->[1] eq ']') {
		return $context_value;
	}
	$self->{tokens_index} = $self->{save_tokens_index};
	push @$context_value, $self->context_expression;
	while ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ',') {
		$self->{save_tokens_index} = $self->{tokens_index};
		push @$context_value, $self->context_expression;
	}
	return $context_value;
}
sub context_tree_constructor {
	my ($self, $context_value) = @_;
	my @tokens;

	if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and $self->{tokens}[$self->{tokens_index} + 0]->[1] eq '}') {
		return $context_value;
	}
	$self->{tokens_index} = $self->{save_tokens_index};
	if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier') {
		$self->{save_tokens_index} = $self->{tokens_index};
		push @$context_value, $tokens[0][1];
	} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'string') {
		$self->{save_tokens_index} = $self->{tokens_index};
		push @$context_value, $tokens[0][1];
	} else {
		$self->{tokens_index} = $self->{save_tokens_index};
		return $context_value;
	}
	$self->{tokens_index} = $self->{save_tokens_index};
	$self->confess_at_current_offset('expected \'=>\'')
		unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[0] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>';
	$self->{save_tokens_index} = $self->{tokens_index};
	push @$context_value, $self->context_expression;
	while ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[1] = $self->{tokens}[$self->{tokens_index}++])->[1] eq ',') {
		$self->{save_tokens_index} = $self->{tokens_index};
		if ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'identifier') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, $tokens[2][1];
		} elsif ((($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[0] eq 'string') {
			$self->{save_tokens_index} = $self->{tokens_index};
			push @$context_value, $tokens[2][1];
		} else {
			$self->{tokens_index} = $self->{save_tokens_index};
			return $context_value;
		}
		$self->{tokens_index} = $self->{save_tokens_index};
		$self->confess_at_current_offset('expected \'=>\'')
			unless (($self->{tokens_index} = $self->{save_tokens_index}) + 1 <= @{$self->{tokens}}) and ($tokens[2] = $self->{tokens}[$self->{tokens_index}++])->[1] eq '=>';
		$self->{save_tokens_index} = $self->{tokens_index};
		push @$context_value, $self->context_expression;
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
		say Data::Dumper::Dumper ($tree);

		# my $compiler = Sugar::Lang::SyntaxIntermediateCompiler->new(syntax_definition_intermediate => $tree);
		# say $compiler->to_package;
	}
}

caller or main(@ARGV);



1;


