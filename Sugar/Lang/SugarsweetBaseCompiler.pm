#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

package Sugar::Lang::SugarsweetBaseCompiler;

	sub new {
		my ($self, $args) = @_;
		$self = bless {}, $self;
		$self->{type} = $args->{asdf};
		return $self;
	}
	
	sub compile_file {
		my ($self, $syntax_tree) = @_;
		my $code = [];
		push @{$code}, @{$self->code_file_preamble()};
		push @{$code}, @{[ map @$_, @{[ map { $self->compile_class($_) } @{$syntax_tree->{classes}} ]} ]};
		push @{$code}, @{$self->code_file_postamble()};
		return join("\n", @{$code});
	}
	
	sub code_file_preamble {
		my ($self) = @_;
		die "unimplemented code_file_preamble";
	}
	
	sub code_file_postamble {
		my ($self) = @_;
		die "unimplemented code_file_postamble";
	}
	
	sub compile_class {
		my ($self, $class_tree) = @_;
		my $code = [];
		$self->{current_class_tree} = $class_tree;
		push @{$code}, @{$self->code_class_preamble($class_tree)};
		push @{$code}, @{[ map { "\t$_" } @{[ map @$_, @{[ map { $self->compile_constructor($_) } @{$class_tree->{constructors}} ]} ]} ]};
		push @{$code}, @{[ map { "\t$_" } @{[ map @$_, @{[ map { $self->compile_function($_) } @{$class_tree->{functions}} ]} ]} ]};
		push @{$code}, @{[ map { "\t$_" } @{[ map @$_, @{[ map { $self->compile_native_function($_) } @{[ grep { $self->is_my_native_function($_) } @{$class_tree->{native_functions}} ]} ]} ]} ]};
		push @{$code}, @{$self->code_class_postamble($class_tree)};
		return $code;
	}
	
	sub code_class_preamble {
		my ($self, $class_tree) = @_;
		die "unimplemented code_class_preamble";
	}
	
	sub code_class_postamble {
		my ($self, $class_tree) = @_;
		die "unimplemented code_class_postamble";
	}
	
	sub compile_constructor {
		my ($self, $function_tree) = @_;
		my $code = [];
		$self->{variable_scope} = {};
		push @{$code}, @{$self->code_constructor_preamble($function_tree)};
		push @{$code}, @{$self->compile_statements_block($function_tree->{block}, $function_tree->{argument_list})};
		push @{$code}, @{$self->code_constructor_postamble($function_tree)};
		return $code;
	}
	
	sub code_constructor_preamble {
		my ($self, $function_tree) = @_;
		die "unimplemented code_constructor_preamble";
	}
	
	sub code_constructor_postamble {
		my ($self, $function_tree) = @_;
		die "unimplemented code_constructor_postamble";
	}
	
	sub compile_function {
		my ($self, $function_tree) = @_;
		my $code = [];
		$self->{variable_scope} = {};
		push @{$code}, @{$self->code_function_preamble($function_tree)};
		push @{$code}, @{$self->compile_statements_block($function_tree->{block}, $function_tree->{argument_list})};
		push @{$code}, @{$self->code_function_postamble($function_tree)};
		return $code;
	}
	
	sub code_function_preamble {
		my ($self, $function_tree) = @_;
		die "unimplemented code_function_preamble";
	}
	
	sub code_function_postamble {
		my ($self, $function_tree) = @_;
		die "unimplemented code_function_postamble";
	}
	
	sub is_my_native_function {
		my ($self, $function_tree) = @_;
		die "unimplemented is_my_native_function";
	}
	
	sub compile_native_function {
		my ($self, $function_tree) = @_;
		die "unimplemented compile_native_function";
	}
	
	sub compile_statements_block {
		my ($self, $block, $with_variables) = @_;
		my $previous_scope = $self->{variable_scope};
		$self->{variable_scope} = { %{$previous_scope} };
		foreach my $var (@{$with_variables}) {
			$self->{variable_scope}->{$var->{identifier}} = $var->{variable_type};
		}
		my $code = [ map { "\t$_" } @{[ map @$_, @{[ map { $self->compile_statement($_) } @{$block} ]} ]} ];
		$self->{variable_scope} = $previous_scope;
		return $code;
	}
	
	sub compile_statement {
		my ($self, $statement) = @_;
		die "unimplemented compile_statement";
	}
	
	sub compile_expression {
		my ($self, $expression) = @_;
		die "unimplemented compile_expression";
	}
	
	sub compile_substitution_expression {
		my ($self, $regex_token) = @_;
		die "unimplemented compile_substitution_expression";
	}
	
	sub compile_string_expression {
		my ($self, $string_token) = @_;
		die "unimplemented compile_string_expression";
	}
	
	sub infer_expression_type {
		my ($self, $expression) = @_;
		if (exists($expression->{static_type})) {
			return $expression->{static_type};
		}
		if (exists($expression->{left_expression})) {
			my $expression_type = $self->get_expression_type($expression->{left_expression});
			if ($expression_type) {
				return $expression_type;
			}
		}
		if (exists($expression->{right_expression})) {
			my $expression_type = $self->get_expression_type($expression->{right_expression});
			if ($expression_type) {
				return $expression_type;
			}
		}
		return;
	}
	
	sub get_expression_type {
		my ($self, $expression) = @_;
		if (exists($expression->{expression_type})) {
			return $expression->{expression_type};
		} elsif (($expression->{type} eq 'variable_expression')) {
			if (not (exists($self->{variable_scope}->{$expression->{identifier}}))) {
				die "undefined variable referenced: $expression->{identifier}";
			}
			return $self->{variable_scope}->{$expression->{identifier}};
		}
		return;
	}
	
	sub compile_expression_with_variables {
		my ($self, $expression, $with_variables) = @_;
		my $previous_scope = $self->{variable_scope};
		$self->{variable_scope} = { %{$previous_scope} };
		foreach my $var (@{$with_variables}) {
			$self->{variable_scope}->{$var->{identifier}} = $var->{variable_type};
		}
		my $code = $self->compile_expression($expression);
		$self->{variable_scope} = $previous_scope;
		return $code;
	}
	

1;

