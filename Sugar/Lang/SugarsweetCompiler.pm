#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

package Sugar::Lang::SugarsweetCompiler;
sub new {
	my ($self, $args) = @_;
	$self = bless {}, $self;
	$self->{type} = $args->{asdf};
	return $self;
}

sub compile_file {
	my ($self, $syntax_tree) = @_;
	my $code = [];
	push @{$code}, "#!/usr/bin/env perl";
	push @{$code}, "use strict;";
	push @{$code}, "use warnings;";
	push @{$code}, "use feature 'say';";
	push @{$code}, "";
	foreach my $class_tree (@{$syntax_tree->{classes}}) {
		push @{$code}, @{$self->compile_class($class_tree)};
	}
	push @{$code}, "";
	return join("\n", @{$code});
}

sub compile_class {
	my ($self, $class_tree) = @_;
	my $code = [];
	my $class_name = join('::', @{$class_tree->{name}});
	push @{$code}, "package $class_name;";
	push @{$code}, @{[ map @$_, @{[ map { $self->compile_constructor($_) } @{$class_tree->{constructors}} ]} ]};
	push @{$code}, @{[ map @$_, @{[ map { $self->compile_function($_) } @{$class_tree->{functions}} ]} ]};
	return $code;
}

sub compile_constructor {
	my ($self, $function_tree) = @_;
	my $code = [];
	push @{$code}, "sub new {";
	if ((0 < scalar(@{$function_tree->{argument_list}}))) {
		my $argument_list = $self->compile_argument_list($function_tree->{argument_list});
		push @{$code}, "\tmy ($argument_list) = \@_;";
	}
	push @{$code}, "\t\$self = bless {}, \$self;";
	$self->{variable_scope} = {};
	push @{$code}, @{$self->compile_statements_block($function_tree->{block}, $function_tree->{argument_list})};
	push @{$code}, "\treturn \$self;";
	push @{$code}, "}";
	push @{$code}, "";
	return $code;
}

sub compile_function {
	my ($self, $function_tree) = @_;
	my $code = [];
	push @{$code}, "sub $function_tree->{name} {";
	if ((0 < scalar(@{$function_tree->{argument_list}}))) {
		my $argument_list = $self->compile_argument_list($function_tree->{argument_list});
		push @{$code}, "\tmy ($argument_list) = \@_;";
	}
	$self->{variable_scope} = {};
	push @{$code}, @{$self->compile_statements_block($function_tree->{block}, $function_tree->{argument_list})};
	push @{$code}, "}";
	push @{$code}, "";
	return $code;
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
	my $code = [];
	if ($statement->{type} eq "foreach_statement") {
		my $expression = $self->compile_expression($statement->{expression});
		push @{$code}, "foreach my \$$statement->{identifier} (\@{$expression}) {";
		push @{$code}, @{$self->compile_statements_block($statement->{block}, [ $statement ])};
		push @{$code}, "}";
	} elsif ($statement->{type} eq "switch_statement") {
		my $expression = $self->compile_expression($statement->{expression});
		my $string_cases = [ grep { ($_->{type} eq 'string_case') } @{$statement->{block}} ];
		my $default_cases = [ grep { ($_->{type} eq 'default_case') } @{$statement->{block}} ];
		if ((1 < scalar(@{$default_cases}))) {
			die "more than one default case defined";
		}
		if ((0 >= scalar(@{$string_cases}))) {
			die "at least one match case is required";
		}
		my $prefix = '';
		foreach my $case (@{$string_cases}) {
			push @{$code}, "${prefix}if ($expression eq $case->{value}) {";
			push @{$code}, @{$self->compile_statements_block($case->{block}, [])};
			$prefix = "} els";
		}
		foreach my $case (@{$default_cases}) {
			push @{$code}, "} else {";
			push @{$code}, @{$self->compile_statements_block($case->{block}, [])};
		}
		push @{$code}, "}";
	} elsif ($statement->{type} eq "if_statement") {
		my $expression = $self->compile_expression($statement->{expression});
		my $prefix = '';
		push @{$code}, "${prefix}if ($expression) {";
		push @{$code}, @{$self->compile_statements_block($statement->{block}, [])};
		if (exists($statement->{branch})) {
			my $branch = $statement->{branch};
			while ($branch) {
				if (($branch->{type} eq 'elsif_statement')) {
					my $expression = $self->compile_expression($branch->{expression});
					push @{$code}, "} elsif ($expression) {";
					push @{$code}, @{$self->compile_statements_block($branch->{block}, [])};
				} else {
					push @{$code}, "} else {";
					push @{$code}, @{$self->compile_statements_block($branch->{block}, [])};
				}
				$branch = $branch->{branch};
			}
		}
		push @{$code}, "}";
	} elsif ($statement->{type} eq "while_statement") {
		my $expression = $self->compile_expression($statement->{expression});
		my $prefix = '';
		push @{$code}, "while ($expression) {";
		push @{$code}, @{$self->compile_statements_block($statement->{block}, [])};
		push @{$code}, "}";
	} elsif ($statement->{type} eq 'void_return_statement') {
		push @{$code}, "return;";
	} elsif ($statement->{type} eq 'return_statement') {
		my $expression = $self->compile_expression($statement->{expression});
		push @{$code}, "return $expression;";
	} elsif ($statement->{type} eq 'list_push_statement') {
		my $left_expression = $self->compile_expression($statement->{left_expression});
		my $right_expression = $self->compile_expression($statement->{right_expression});
		push @{$code}, "push \@{$left_expression}, \@{$right_expression};";
	} elsif ($statement->{type} eq 'push_statement') {
		my $left_expression = $self->compile_expression($statement->{left_expression});
		my $right_expression = $self->compile_expression($statement->{right_expression});
		push @{$code}, "push \@{$left_expression}, $right_expression;";
	} elsif ($statement->{type} eq 'die_statement') {
		my $expression = $self->compile_expression($statement->{expression});
		push @{$code}, "die $expression;";
	} elsif ($statement->{type} eq 'variable_declaration_statement') {
		$self->{variable_scope}->{$statement->{identifier}} = $statement->{variable_type};
		push @{$code}, "my \$$statement->{identifier};";
	} elsif ($statement->{type} eq 'variable_assignment_statement') {
		my $expression = $self->compile_expression($statement->{expression});
		push @{$code}, "\$$statement->{identifier} = $expression;";
	} elsif ($statement->{type} eq 'variable_declaration_assignment_statement') {
		$self->{variable_scope}->{$statement->{identifier}} = $statement->{variable_type};
		my $expression = $self->compile_expression($statement->{expression});
		push @{$code}, "my \$$statement->{identifier} = $expression;";
	} elsif ($statement->{type} eq 'expression_statement') {
		my $expression = $self->compile_expression($statement->{expression});
		push @{$code}, "$expression;";
	} else {
		die "invalid statement type: $statement->{type}";
	}
	return $code;
}

sub compile_expression {
	my ($self, $expression) = @_;
	if ($expression->{type} eq 'string_expression') {
		return $self->compile_string_expression($expression->{value});
	} elsif ($expression->{type} eq 'integer_expression') {
		return $expression->{value};
	} elsif ($expression->{type} eq 'variable_expression') {
		if (not (exists($self->{variable_scope}->{$expression->{identifier}}))) {
			die "undefined variable referenced: $expression->{identifier}";
		}
		return "\$$expression->{identifier}";
	} elsif ($expression->{type} eq 'match_index_expression') {
		if (($expression->{index} < 0)) {
			die "match index cannot be negative";
		}
		return "\$$expression->{index}";
	} elsif ($expression->{type} eq 'match_position_expression') {
		return "\$+[0]";
	} elsif ($expression->{type} eq 'empty_list_expression') {
		return "[]";
	} elsif ($expression->{type} eq 'empty_tree_expression') {
		return "{}";
	} elsif ($expression->{type} eq 'list_constructor_expression') {
		my $expression_list = $self->compile_expression_list($expression->{expression_list});
		return "[ $expression_list ]";
	} elsif ($expression->{type} eq 'tree_constructor_expression') {
		my $expression_list = $self->compile_tree_constructor($expression->{expression_list});
		return "{ $expression_list }";
	} elsif ($expression->{type} eq 'not_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "not ($sub_expression)";
	} elsif ($expression->{type} eq 'join_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "join($left_expression, \@{$right_expression})";
	} elsif ($expression->{type} eq 'split_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "[ split($left_expression, $right_expression) ]";
	} elsif ($expression->{type} eq 'flatten_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "[ map \@\$_, \@{$sub_expression} ]";
	} elsif ($expression->{type} eq 'map_expression') {
		my $left_expression = $self->compile_expression_with_variables($expression->{left_expression}, [ { variable_type => ('*'), identifier => ('_') } ]);
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "[ map { $left_expression } \@{$right_expression} ]";
	} elsif ($expression->{type} eq 'grep_expression') {
		my $left_expression = $self->compile_expression_with_variables($expression->{left_expression}, [ { variable_type => ('*'), identifier => ('_') } ]);
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "[ grep { $left_expression } \@{$right_expression} ]";
	} elsif ($expression->{type} eq 'length_expression') {
		my $expression_type;
		if (exists($expression->{static_type})) {
			$expression_type = $expression->{static_type};
		} else {
			$expression_type = $self->get_expression_type($expression->{expression});
		}
		if (not ($expression_type)) {
			die "ambiguous type length expression";
		}
		my $sub_expression = $self->compile_expression($expression->{expression});
		if (($expression_type eq 'string')) {
			return "length($sub_expression)";
		} elsif (($expression_type eq 'list')) {
			return "scalar(\@{$sub_expression})";
		} else {
			die "invalid value type for length expression: '$expression_type'";
		}
	} elsif ($expression->{type} eq 'pop_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "pop(\@{$sub_expression})";
	} elsif ($expression->{type} eq 'shift_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "shift(\@{$sub_expression})";
	} elsif ($expression->{type} eq 'contains_expression') {
		if ($expression->{expression}->{type} eq 'access_expression') {
		} elsif ($expression->{expression}->{type} eq 'expression_access_expression') {
		} else {
			die "invalid expression for contains expression: $expression->{expression}{type}";
		}
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "exists($sub_expression)";
	} elsif ($expression->{type} eq 'clone_expression') {
		my $expression_type = $self->get_expression_type($expression->{expression});
		if (not ($expression_type)) {
			die "ambiguous type clone expression";
		}
		my $sub_expression = $self->compile_expression($expression->{expression});
		if (($expression_type eq 'tree')) {
			return "{ \%{$sub_expression} }";
		} elsif (($expression_type eq 'list')) {
			return "[ \@{$sub_expression} ]";
		} else {
			die "invalid value type for clone expression: '$expression_type'";
		}
	} elsif ($expression->{type} eq 'assignment_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "$left_expression = $right_expression";
	} elsif ($expression->{type} eq 'addition_assignment_expression') {
		my $expression_type = $self->infer_expression_type($expression);
		if (not ($expression_type)) {
			die "ambiguous type addition assignment expression";
		}
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		if (($expression_type eq 'string')) {
			return "$left_expression .= $right_expression";
		} elsif (($expression_type eq 'int')) {
			return "$left_expression += $right_expression";
		} else {
			die "invalid expression type for addition assignment: $expression_type";
		}
	} elsif ($expression->{type} eq 'access_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "$sub_expression\->{$expression->{identifier}}";
	} elsif ($expression->{type} eq 'expression_access_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "$left_expression\->{$right_expression}";
	} elsif ($expression->{type} eq 'access_call_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		my $expression_list = $self->compile_expression_list($expression->{expression_list});
		return "$sub_expression\->$expression->{identifier}\($expression_list)";
	} elsif ($expression->{type} eq 'call_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		my $expression_list = $self->compile_expression_list($expression->{expression_list});
		return "$sub_expression\->($expression_list)";
	} elsif ($expression->{type} eq 'object_assignment_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "$left_expression\->{$expression->{identifier}} = $right_expression";
	} elsif ($expression->{type} eq 'numeric_comparison_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "($left_expression $expression->{operator} $right_expression)";
	} elsif ($expression->{type} eq 'comparison_expression') {
		my $expression_type = $self->infer_expression_type($expression);
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		if (($expression_type eq 'string')) {
			my $operator;
			if (($expression->{operator} eq '==')) {
				$operator = 'eq';
			} else {
				$operator = 'ne';
			}
			return "($left_expression $operator $right_expression)";
		} else {
			return "($left_expression $expression->{operator} $right_expression)";
		}
	} elsif ($expression->{type} eq 'regex_match_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "($sub_expression $expression->{operator} $expression->{regex})";
	} elsif ($expression->{type} eq 'regex_substitution_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		my $regex_expression = $self->compile_substitution_expression($expression->{regex});
		return "($sub_expression =~ $regex_expression)";
	} else {
		die "invalid expression type: $expression->{type}";
	}
}

sub compile_substitution_expression {
	my ($self, $regex_token) = @_;
	if (($regex_token =~ /\As\/([^\\\/]|\\.)*+\/([^\\\/]|\\.)*+\/([msixpodualngc]*+)\Z/s)) {
		my $regex = $1;
		my $substitution_string = $2;
		my $flags = $3;
		$substitution_string = $self->compile_string_expression($substitution_string);
		return "s/$regex/$substitution_string/${flags}r";
	} else {
		die "failed to compile substitution expression: $regex_token";
	}
}

sub compile_string_expression {
	my ($self, $string_token) = @_;
	my $string_content;
	if (($string_token =~ /\A'/s)) {
		return $string_token;
	} elsif (($string_token =~ /\A"(.*)"\Z/s)) {
		$string_content = $1;
	} else {
		$string_content = $string_token;
	}
	if (($string_content eq '')) {
		return $string_token;
	}
	my $compiled_string = '';
	my $last_match_position = 0;
	while (($string_content =~ /\G(?:((?:[^\$\\]|\\.)+)|\$(\w+)(?:\.(\w+(?:\.\w+)*))?|\$\{(\w+)(?:\.(\w+(?:\.\w+)*))?\})/gsc)) {
		my $text_match = $1;
		my $variable_match = $2;
		my $variable_access = $3;
		my $protected_variable_match = $4;
		my $protected_variable_access = $5;
		$last_match_position = $+[0];
		if ($text_match) {
			$compiled_string .= $text_match;
		} elsif ($variable_match) {
			if (not (exists($self->{variable_scope}->{$variable_match}))) {
				die "undefined variable in string interpolation: $variable_match";
			}
			if ($variable_access) {
				$compiled_string .= "\$$variable_match\->";
				$compiled_string .= join('', @{[ map { "{$_}" } @{[ split("\\.", $variable_access) ]} ]});
			} else {
				$compiled_string .= "\$$variable_match";
			}
		} else {
			if (not (exists($self->{variable_scope}->{$protected_variable_match}))) {
				die "undefined variable in string interpolation: $protected_variable_match";
			}
			if ($protected_variable_access) {
				$compiled_string .= "\$$protected_variable_match\->";
				$compiled_string .= join('', @{[ map { "{$_}" } @{[ split("\\.", $protected_variable_access) ]} ]});
			} else {
				$compiled_string .= "\${$protected_variable_match}";
			}
		}
	}
	if (($last_match_position < length($string_content))) {
		die "failed to compile string expression: $string_token";
	}
	return "\"$compiled_string\"";
}

sub compile_argument_list {
	my ($self, $argument_list) = @_;
	return join(', ', @{[ map { "\$$_->{identifier}" } @{$argument_list} ]});
}

sub compile_expression_list {
	my ($self, $expression_list) = @_;
	return join(', ', @{[ map { $self->compile_expression($_) } @{$expression_list} ]});
}

sub compile_tree_constructor {
	my ($self, $tree_constructor_list) = @_;
	my $pairs = [];
	my $items = [ @{$tree_constructor_list} ];
	while ((0 < scalar(@{$items}))) {
		my $key = shift(@{$items});
		my $expression = $self->compile_expression(shift(@{$items}));
		push @{$pairs}, "$key => ($expression)";
	}
	return join(', ', @{$pairs});
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



sub main {
	use Data::Dumper;
	use Sugar::IO::File;
	# use test1;
	use Sugar::Lang::SugarsweetParser;

	my $parser = Sugar::Lang::SugarsweetParser->new;
	my $compiler = __PACKAGE__->new;
	foreach my $file (@_) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		my $tree = $parser->parse;
		# say Dumper $tree;

		say $compiler->compile_file($tree);


		# my $compiler = Sugar::Lang::SyntaxIntermediateCompiler->new(syntax_definition_intermediate => $tree);
		# say $compiler->to_package;
	}
}

caller or main(@ARGV);


