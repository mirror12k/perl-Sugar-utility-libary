#!/usr/bin/env perl
package Sugar::Lang::SugarsweetParser;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';





##############################
##### variables and settings
##############################

our $var_symbol_regex = qr/\(|\)|\{|\}|\[|\]|<=|>=|<|>|->|=>|==|=~|\+=|!~|!=|=|,|\.|\+|\-|\*|\/|::|:|;/;
our $var_identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;
our $var_string_regex = qr/'([^\\']|\\.)*+'|"([^\\"]|\\.)*+"/s;
our $var_integer_regex = qr/-?\d++/;
our $var_regex_regex = qr/\/([^\\\/]|\\.)*+\/[msixgcpodualn]*+/s;
our $var_comment_regex = qr/\#[^\n]*+\n/s;
our $var_whitespace_regex = qr/\s++/s;


our $tokens = [
	'regex' => $var_regex_regex,
	'symbol' => $var_symbol_regex,
	'identifier' => $var_identifier_regex,
	'string' => $var_string_regex,
	'integer' => $var_integer_regex,
	'comment' => $var_comment_regex,
	'whitespace' => $var_whitespace_regex,
];

our $ignored_tokens = [
	'comment',
	'whitespace',
];

our $contexts = {
	argument_list => 'context_argument_list',
	class_definition => 'context_class_definition',
	class_definition_block => 'context_class_definition_block',
	class_identifier => 'context_class_identifier',
	expression => 'context_expression',
	expression_list => 'context_expression_list',
	method_argument_list => 'context_method_argument_list',
	more_expression => 'context_more_expression',
	root => 'context_root',
	statements_block => 'context_statements_block',
	statements_block_list => 'context_statements_block_list',
	switch_block_list => 'context_switch_block_list',
	switch_statements_block => 'context_switch_statements_block',
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
	my $context_object = {};
	while ($self->more_tokens) {
		my @tokens;
		
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'class') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{classes}}, $self->context_class_definition({ type => 'class_declaration', line_number => $tokens[0][2], name => $self->context_class_identifier, });
		} else {
			$self->confess_at_current_offset('expected class definition');
		}
	}
	return $context_object;
}
sub context_class_identifier {
	my ($self, $context_list) = @_;
	my @tokens;
	
	$self->confess_at_current_offset('expected identifier token')
		unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier';
	@tokens = (@tokens, $self->step_tokens(1));
	push @$context_list, $tokens[0][1];
	while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '::') {
		my @tokens = (@tokens, $self->step_tokens(1));
		$self->confess_at_current_offset('expected identifier after "::" token')
			unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier';
		@tokens = (@tokens, $self->step_tokens(1));
		push @$context_list, $tokens[2][1];
	}
	return $context_list;
}
sub context_class_definition {
	my ($self, $context_object) = @_;
	my @tokens;
	
	$self->confess_at_current_offset('"{" expected before code block')
		unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{';
	@tokens = (@tokens, $self->step_tokens(1));
	$context_object = $self->context_class_definition_block($context_object);
	$self->confess_at_current_offset('"}" expected after code block')
		unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
	@tokens = (@tokens, $self->step_tokens(1));
	return $context_object;
}
sub context_class_definition_block {
	my ($self, $context_object) = @_;
	while ($self->more_tokens) {
		my @tokens;
		
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'sub' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '_constructor' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '(') {
			my @tokens = (@tokens, $self->step_tokens(3));
			my $var_argument_list = $self->context_method_argument_list;
			$self->confess_at_current_offset('expected ")" after argument list')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{constructors}}, { type => 'function_declaration', line_number => $tokens[0][2], return_type => $tokens[0][1], name => $tokens[1][1], argument_list => $var_argument_list, block => $self->context_statements_block, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'sub' and $self->{tokens}[$self->{tokens_index} + 2][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 3][1] eq '(') {
			my @tokens = (@tokens, $self->step_tokens(4));
			my $var_argument_list = $self->context_method_argument_list;
			$self->confess_at_current_offset('expected ")" after argument list')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			push @{$context_object->{functions}}, { type => 'function_declaration', line_number => $tokens[0][2], return_type => $tokens[0][1], name => $tokens[2][1], argument_list => $var_argument_list, block => $self->context_statements_block, };
		} else {
			return $context_object;
		}
	}
	return $context_object;
}
sub context_statements_block {
	my ($self, $context_list) = @_;
	my @tokens;
	
	$self->confess_at_current_offset('"{" expected before code block')
		unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{';
	@tokens = (@tokens, $self->step_tokens(1));
	$context_list = $self->context_statements_block_list([]);
	$self->confess_at_current_offset('"}" expected after code block')
		unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
	@tokens = (@tokens, $self->step_tokens(1));
	return $context_list;
}
sub context_statements_block_list {
	my ($self, $context_list) = @_;
	while ($self->more_tokens) {
		my @tokens;
		
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'foreach' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '(' and $self->{tokens}[$self->{tokens_index} + 2][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 3][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 4][1] eq 'in') {
			my @tokens = (@tokens, $self->step_tokens(5));
			my $var_expression = $self->context_expression;
			$self->confess_at_current_offset('expected ")" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'foreach_statement', line_number => $tokens[0][2], variable_type => $tokens[2][1], identifier => $tokens[3][1], expression => $var_expression, block => $self->context_statements_block, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'string' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'switch' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '(') {
			my @tokens = (@tokens, $self->step_tokens(3));
			my $var_expression = $self->context_expression;
			$self->confess_at_current_offset('expected ")" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'switch_statement', line_number => $tokens[0][2], expression_type => $tokens[0][1], expression => $var_expression, block => $self->context_switch_statements_block, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'if' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '(') {
			my @tokens = (@tokens, $self->step_tokens(2));
			my $var_expression = $self->context_expression;
			$self->confess_at_current_offset('expected ")" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			my $var_statement = { type => 'if_statement', line_number => $tokens[0][2], expression => $var_expression, block => $self->context_statements_block, };
			my $var_branch_statement = $var_statement;
			while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'elsif' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '(') {
				my @tokens = (@tokens, $self->step_tokens(2));
				$var_expression = $self->context_expression;
				$self->confess_at_current_offset('expected ")" after expression')
					unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
				@tokens = (@tokens, $self->step_tokens(1));
				$var_branch_statement->{branch} = { type => 'elsif_statement', line_number => $tokens[0][2], expression => $var_expression, block => $self->context_statements_block, };
				$var_branch_statement = $var_branch_statement->{branch};
			}
			if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'else') {
				my @tokens = (@tokens, $self->step_tokens(1));
				$var_branch_statement->{branch} = { type => 'else_statement', line_number => $tokens[0][2], block => $self->context_statements_block, };
			}
			push @$context_list, $var_statement;
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'while' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '(') {
			my @tokens = (@tokens, $self->step_tokens(2));
			my $var_expression = $self->context_expression;
			$self->confess_at_current_offset('expected ")" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'while_statement', line_number => $tokens[0][2], expression => $var_expression, block => $self->context_statements_block, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'return' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ';') {
			my @tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'void_return_statement', line_number => $tokens[0][2], };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'return') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'return_statement', line_number => $tokens[0][2], expression => $self->context_expression, };
			$self->confess_at_current_offset('expected ";" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'list' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'push') {
			my @tokens = (@tokens, $self->step_tokens(2));
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \',\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',';
			@tokens = (@tokens, $self->step_tokens(1));
			my $var_right_expression = $self->context_expression;
			push @$context_list, { type => 'list_push_statement', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, };
			$self->confess_at_current_offset('expected ";" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'push') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \',\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',';
			@tokens = (@tokens, $self->step_tokens(1));
			my $var_right_expression = $self->context_expression;
			push @$context_list, { type => 'push_statement', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, };
			$self->confess_at_current_offset('expected ";" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'die') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, { type => 'die_statement', line_number => $tokens[0][2], expression => $self->context_expression, };
			$self->confess_at_current_offset('expected ";" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 1][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 2][1] eq ';') {
			my @tokens = (@tokens, $self->step_tokens(3));
			push @$context_list, { type => 'variable_declaration_statement', line_number => $tokens[0][2], variable_type => $tokens[0][1], identifier => $tokens[1][1], };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 1][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '=') {
			my @tokens = (@tokens, $self->step_tokens(3));
			push @$context_list, { type => 'variable_declaration_assignment_statement', line_number => $tokens[0][2], variable_type => $tokens[0][1], identifier => $tokens[1][1], expression => $self->context_expression, };
			$self->confess_at_current_offset('expected ";" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'variable_assignment_statement', line_number => $tokens[0][2], identifier => $tokens[0][1], expression => $self->context_expression, };
			$self->confess_at_current_offset('expected ";" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			return $context_list;
		} else {
			push @$context_list, { type => 'expression_statement', line_number => $tokens[0][2], expression => $self->context_expression, };
			$self->confess_at_current_offset('expected ";" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ';';
			@tokens = (@tokens, $self->step_tokens(1));
		}
	}
	return $context_list;
}
sub context_switch_statements_block {
	my ($self, $context_list) = @_;
	my @tokens;
	
	$self->confess_at_current_offset('"{" expected before code block')
		unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{';
	@tokens = (@tokens, $self->step_tokens(1));
	$context_list = $self->context_switch_block_list([]);
	$self->confess_at_current_offset('"}" expected after code block')
		unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
	@tokens = (@tokens, $self->step_tokens(1));
	return $context_list;
}
sub context_switch_block_list {
	my ($self, $context_list) = @_;
	while ($self->more_tokens) {
		my @tokens;
		
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'integer' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ':') {
			my @tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'integer_case', line_number => $tokens[0][2], value => $tokens[0][1], block => $self->context_statements_block, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'string' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ':') {
			my @tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'string_case', line_number => $tokens[0][2], value => $tokens[0][1], block => $self->context_statements_block, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'default' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ':') {
			my @tokens = (@tokens, $self->step_tokens(2));
			push @$context_list, { type => 'default_case', line_number => $tokens[0][2], block => $self->context_statements_block, };
		} else {
			return $context_list;
		}
	}
	return $context_list;
}
sub context_expression {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
		
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'integer') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $self->context_more_expression({ type => 'integer_expression', line_number => $tokens[0][2], value => $tokens[0][1], expression_type => 'int', });
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'string') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $self->context_more_expression({ type => 'string_expression', line_number => $tokens[0][2], value => $tokens[0][1], expression_type => 'string', });
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ']') {
			my @tokens = (@tokens, $self->step_tokens(2));
			return $self->context_more_expression({ type => 'empty_list_expression', line_number => $tokens[0][2], expression_type => 'list', });
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_expression = { type => 'list_constructor_expression', line_number => $tokens[0][2], expression_type => 'list', expression_list => $self->context_expression_list([]), };
			$self->confess_at_current_offset('expected "]" after expression list')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']';
			@tokens = (@tokens, $self->step_tokens(1));
			return $self->context_more_expression($var_expression);
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '}') {
			my @tokens = (@tokens, $self->step_tokens(2));
			return $self->context_more_expression({ type => 'empty_tree_expression', line_number => $tokens[0][2], expression_type => 'tree', });
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_expression = { type => 'tree_constructor_expression', line_number => $tokens[0][2], expression_type => 'tree', expression_list => $self->context_tree_constructor([]), };
			$self->confess_at_current_offset('expected "}" after expression list')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			return $self->context_more_expression($var_expression);
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'join') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \',\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',';
			@tokens = (@tokens, $self->step_tokens(1));
			my $var_right_expression = $self->context_expression;
			return { type => 'join_expression', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, expression_type => 'string', };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'split') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \',\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',';
			@tokens = (@tokens, $self->step_tokens(1));
			my $var_right_expression = $self->context_expression;
			return { type => 'split_expression', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, expression_type => 'list', };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'list' and $self->{tokens}[$self->{tokens_index} + 1][1] eq 'length') {
			my @tokens = (@tokens, $self->step_tokens(2));
			my $var_expression = $self->context_expression;
			return { type => 'length_expression', line_number => $tokens[0][2], expression => $var_expression, expression_type => 'int', static_type => $tokens[0][1], };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'length') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_expression = $self->context_expression;
			return { type => 'length_expression', line_number => $tokens[0][2], expression => $var_expression, expression_type => 'int', };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'clone') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_expression = $self->context_expression;
			return { type => 'clone_expression', line_number => $tokens[0][2], expression => $var_expression, expression_type => $var_expression->{expression_type}, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'pop') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_expression = $self->context_expression;
			return { type => 'pop_expression', line_number => $tokens[0][2], expression => $var_expression, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'shift') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_expression = $self->context_expression;
			return { type => 'shift_expression', line_number => $tokens[0][2], expression => $var_expression, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'contains') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_expression = $self->context_expression;
			return { type => 'contains_expression', line_number => $tokens[0][2], expression => $var_expression, expression_type => 'bool', };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'flatten') {
			my @tokens = (@tokens, $self->step_tokens(1));
			my $var_expression = $self->context_expression;
			return { type => 'flatten_expression', line_number => $tokens[0][2], expression => $var_expression, expression_type => 'list', };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'map' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = (@tokens, $self->step_tokens(2));
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			my $var_right_expression = $self->context_expression;
			return { type => 'map_expression', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, expression_type => 'list', };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'grep' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = (@tokens, $self->step_tokens(2));
			my $var_left_expression = $self->context_expression;
			$self->confess_at_current_offset('expected \'}\'')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}';
			@tokens = (@tokens, $self->step_tokens(1));
			my $var_right_expression = $self->context_expression;
			return { type => 'grep_expression', line_number => $tokens[0][2], left_expression => $var_left_expression, right_expression => $var_right_expression, expression_type => 'list', };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'match' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 2][0] eq 'integer' and $self->{tokens}[$self->{tokens_index} + 3][1] eq ']') {
			my @tokens = (@tokens, $self->step_tokens(4));
			return $self->context_more_expression({ type => 'match_index_expression', line_number => $tokens[0][2], index => $tokens[2][1], });
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq 'match' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 2][1] eq 'pos') {
			my @tokens = (@tokens, $self->step_tokens(3));
			return $self->context_more_expression({ type => 'match_position_expression', line_number => $tokens[0][2], });
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return $self->context_more_expression({ type => 'variable_expression', line_number => $tokens[0][2], identifier => $tokens[0][1], });
		} else {
			$self->confess_at_current_offset('expected expression');
		}
	}
	return $context_value;
}
sub context_more_expression {
	my ($self, $context_value) = @_;
	while ($self->more_tokens) {
		my @tokens;
		
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 1][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '(') {
			my @tokens = (@tokens, $self->step_tokens(3));
			$context_value = { type => 'access_call_expression', line_number => $tokens[0][2], expression => $context_value, identifier => $tokens[1][1], expression_list => $self->context_expression_list([]), };
			$self->confess_at_current_offset('expected ")" after expression list')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 1][0] eq 'identifier' and $self->{tokens}[$self->{tokens_index} + 2][1] eq '=') {
			my @tokens = (@tokens, $self->step_tokens(3));
			return { type => 'object_assignment_expression', line_number => $tokens[0][2], left_expression => $context_value, right_expression => $self->context_expression, identifier => $tokens[1][1], };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'assignment_expression', line_number => $tokens[0][2], left_expression => $context_value, right_expression => $self->context_expression, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '+=') {
			my @tokens = (@tokens, $self->step_tokens(1));
			return { type => 'addition_assignment_expression', line_number => $tokens[0][2], operator => $tokens[0][1], left_expression => $context_value, right_expression => $self->context_expression, };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '.' and $self->{tokens}[$self->{tokens_index} + 1][0] eq 'identifier') {
			my @tokens = (@tokens, $self->step_tokens(2));
			$context_value = { type => 'access_expression', line_number => $tokens[0][2], expression => $context_value, identifier => $tokens[1][1], };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens = (@tokens, $self->step_tokens(1));
			$context_value = { type => 'expression_access_expression', line_number => $tokens[0][2], left_expression => $context_value, right_expression => $self->context_expression, };
			$self->confess_at_current_offset('expected "]" after expression')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']';
			@tokens = (@tokens, $self->step_tokens(1));
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '(') {
			my @tokens = (@tokens, $self->step_tokens(1));
			$context_value = { type => 'call_expression', line_number => $tokens[0][2], expression => $context_value, expression_list => $self->context_expression_list([]), };
			$self->confess_at_current_offset('expected ")" after expression list')
				unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')';
			@tokens = (@tokens, $self->step_tokens(1));
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A(<=|>=|<|>)\Z/) {
			my @tokens = (@tokens, $self->step_tokens(1));
			$context_value = { type => 'numeric_comparison_expression', line_number => $tokens[0][2], operator => $tokens[0][1], left_expression => $context_value, right_expression => $self->context_expression, expression_type => 'bool', };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A(==|!=)\Z/) {
			my @tokens = (@tokens, $self->step_tokens(1));
			$context_value = { type => 'comparison_expression', line_number => $tokens[0][2], operator => $tokens[0][1], left_expression => $context_value, right_expression => $self->context_expression, expression_type => 'bool', };
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A(=~|!~)\Z/ and $self->{tokens}[$self->{tokens_index} + 1][0] eq 'regex') {
			my @tokens = (@tokens, $self->step_tokens(2));
			$context_value = { type => 'regex_match_expression', line_number => $tokens[0][2], expression => $context_value, operator => $tokens[0][1], regex => $tokens[1][1], expression_type => 'bool', };
		} else {
			return $context_value;
		}
	}
	return $context_value;
}
sub context_method_argument_list {
	my ($self, $context_list) = @_;
	my @tokens;
	
	return $self->context_argument_list([ { variable_type => 'self', identifier => 'self', }, ]);
}
sub context_argument_list {
	my ($self, $context_list) = @_;
	my @tokens;
	
	if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')') {
		return $context_list;
	}
	$self->confess_at_current_offset('expected variable type in argument list')
		unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier';
	@tokens = (@tokens, $self->step_tokens(1));
	$self->confess_at_current_offset('expected variable identifier in argument list')
		unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier';
	@tokens = (@tokens, $self->step_tokens(1));
	push @$context_list, { variable_type => $tokens[0][1], identifier => $tokens[1][1], };
	while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
		my @tokens = (@tokens, $self->step_tokens(1));
		$self->confess_at_current_offset('expected variable type in argument list')
			unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier';
		@tokens = (@tokens, $self->step_tokens(1));
		$self->confess_at_current_offset('expected variable identifier in argument list')
			unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier';
		@tokens = (@tokens, $self->step_tokens(1));
		push @$context_list, { variable_type => $tokens[3][1], identifier => $tokens[4][1], };
	}
	return $context_list;
}
sub context_expression_list {
	my ($self, $context_list) = @_;
	my @tokens;
	
	if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ')') {
		return $context_list;
	} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ']') {
		return $context_list;
	}
	push @$context_list, $self->context_expression;
	while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
		my @tokens = (@tokens, $self->step_tokens(1));
		push @$context_list, $self->context_expression;
	}
	return $context_list;
}
sub context_tree_constructor {
	my ($self, $context_list) = @_;
	my @tokens;
	
	if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
		return $context_list;
	}
	if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier') {
		my @tokens = (@tokens, $self->step_tokens(1));
		push @$context_list, $tokens[0][1];
	} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'string') {
		my @tokens = (@tokens, $self->step_tokens(1));
		push @$context_list, $tokens[0][1];
	} else {
		return $context_list;
	}
	$self->confess_at_current_offset('expected \'=>\'')
		unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=>';
	@tokens = (@tokens, $self->step_tokens(1));
	push @$context_list, $self->context_expression;
	while ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq ',') {
		my @tokens = (@tokens, $self->step_tokens(1));
		if ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'identifier') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $tokens[2][1];
		} elsif ($self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][0] eq 'string') {
			my @tokens = (@tokens, $self->step_tokens(1));
			push @$context_list, $tokens[2][1];
		} else {
			return $context_list;
		}
		$self->confess_at_current_offset('expected \'=>\'')
			unless $self->more_tokens and $self->{tokens}[$self->{tokens_index} + 0][1] eq '=>';
		@tokens = (@tokens, $self->step_tokens(1));
		push @$context_list, $self->context_expression;
	}
	return $context_list;
}


##############################
##### native perl functions
##############################

sub main {
	use Data::Dumper;
	use Sugar::IO::File;
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


