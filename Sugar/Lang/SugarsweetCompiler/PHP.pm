#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

package Sugar::Lang::SugarsweetCompiler::PHP;
use parent 'Sugar::Lang::SugarsweetBaseCompiler';

	sub code_file_preamble {
		my ($self) = @_;
		return [ "<?php", "", "", "" ];
	}
	
	sub code_file_postamble {
		my ($self) = @_;
		return [ "" ];
	}
	
	sub code_class_preamble {
		my ($self, $class_tree) = @_;
		my $class_name = join('::', @{$class_tree->{name}});
		my $code = [];
		push @{$code}, "class $class_name {";
		if ($class_tree->{parent_name}) {
			die "TODO parent classes";
		}
		push @{$code}, "";
		return $code;
	}
	
	sub code_class_postamble {
		my ($self, $class_tree) = @_;
		if ($self->{has_main_method}) {
			my $class_name = join('::', @{$class_tree->{name}});
			return [ "}", "", "if (__FILE__ == get_included_files()[0])", "\t$class_name\::main(\$argv);", "" ];
		} else {
			return [ "}", "" ];
		}
	}
	
	sub code_constructor_preamble {
		my ($self, $function_tree) = @_;
		my $code = [];
		if ((0 < scalar(@{$function_tree->{argument_list}}))) {
			my $argument_list = $self->compile_argument_list($function_tree->{argument_list});
			push @{$code}, "function __construct($argument_list) {";
		} else {
			push @{$code}, "function __construct() {";
		}
		return $code;
	}
	
	sub code_constructor_postamble {
		my ($self, $function_tree) = @_;
		return [ "}", "" ];
	}
	
	sub code_function_preamble {
		my ($self, $function_tree) = @_;
		my $code = [];
		my $modifiers = "public";
		if (($function_tree->{name} eq 'main')) {
			$modifiers .= " static";
			$self->{has_main_method} = 1;
		}
		if ((0 < scalar(@{$function_tree->{argument_list}}))) {
			my $argument_list = $self->compile_argument_list($function_tree->{argument_list});
			push @{$code}, "$modifiers function $function_tree->{name} ($argument_list) {";
		} else {
			push @{$code}, "$modifiers function $function_tree->{name} () {";
		}
		return $code;
	}
	
	sub code_function_postamble {
		my ($self, $function_tree) = @_;
		my $code = [ "}", "" ];
		return $code;
	}
	
	sub is_my_native_function {
		my ($self, $function_tree) = @_;
		if (($function_tree->{native_type} eq 'php7')) {
			return 1;
		} elsif (($function_tree->{native_type} eq 'php5')) {
			return 1;
		} else {
			return 0;
		}
	}
	
	sub compile_native_function {
		my ($self, $function_tree) = @_;
		my $code = [];
		my $modifiers = "public";
		if (($function_tree->{name} eq 'main')) {
			$modifiers .= " static";
			$self->{has_main_method} = 1;
		}
		if ((0 < scalar(@{$function_tree->{argument_list}}))) {
			my $argument_list = $self->compile_argument_list($function_tree->{argument_list});
			push @{$code}, "$modifiers function $function_tree->{name} ($argument_list) {";
		} else {
			push @{$code}, "$modifiers function $function_tree->{name} () {";
		}
		if (($function_tree->{block} =~ /\A\{\{(.*?)\}\}\Z/s)) {
			push @{$code}, $1;
		} else {
			die "failed to compile native block: $function_tree->{block}";
		}
		push @{$code}, "}";
		push @{$code}, "";
		return $code;
	}
	
	sub compile_statement {
		my ($self, $statement) = @_;
		my $code = [];
		if (($statement->{type} eq "foreach_statement")) {
			my $expression = $self->compile_expression($statement->{expression});
			push @{$code}, "foreach ($expression as \$$statement->{identifier}) {";
			push @{$code}, @{$self->compile_statements_block($statement->{block}, [ $statement ])};
			push @{$code}, "}";
		} elsif (($statement->{type} eq "switch_statement")) {
			my $expression = $self->compile_expression($statement->{expression});
			my $match_blocks = [ grep { ($_->{type} eq 'match_switch_block') } @{$statement->{block}} ];
			my $default_blocks = [ grep { ($_->{type} eq 'default_switch_block') } @{$statement->{block}} ];
			if ((1 < scalar(@{$default_blocks}))) {
				die "more than one default case defined";
			}
			if ((0 >= scalar(@{$match_blocks}))) {
				die "at least one match case is required";
			}
			my $prefix = '';
			foreach my $case (@{$match_blocks}) {
				my $expression_list_strings;
				foreach my $match_case (@{$case->{case_list}}) {
					if (($match_case->{type} eq "integer_case")) {
						push @{$expression_list_strings}, "$expression === $match_case->{value}";
					} elsif (($match_case->{type} eq "string_case")) {
						push @{$expression_list_strings}, "$expression === $match_case->{value}";
					} else {
						die "unimplemented: $match_case->{type}";
					}
				}
				my $expression_list = join(' or ', @{$expression_list_strings});
				push @{$code}, "${prefix}if ($expression_list) {";
				push @{$code}, @{$self->compile_statements_block($case->{block}, [])};
				$prefix = "} else ";
			}
			foreach my $case (@{$default_blocks}) {
				push @{$code}, "} else {";
				push @{$code}, @{$self->compile_statements_block($case->{block}, [])};
			}
			push @{$code}, "}";
		} elsif (($statement->{type} eq "if_statement")) {
			my $expression = $self->compile_expression($statement->{expression});
			my $prefix = '';
			push @{$code}, "${prefix}if ($expression) {";
			push @{$code}, @{$self->compile_statements_block($statement->{block}, [])};
			if (exists($statement->{branch})) {
				my $branch = $statement->{branch};
				while ($branch) {
					if (($branch->{type} eq 'elsif_statement')) {
						my $expression = $self->compile_expression($branch->{expression});
						push @{$code}, "} else if ($expression) {";
						push @{$code}, @{$self->compile_statements_block($branch->{block}, [])};
					} else {
						push @{$code}, "} else {";
						push @{$code}, @{$self->compile_statements_block($branch->{block}, [])};
					}
					$branch = $branch->{branch};
				}
			}
			push @{$code}, "}";
		} elsif (($statement->{type} eq "while_statement")) {
			my $expression = $self->compile_expression($statement->{expression});
			my $prefix = '';
			push @{$code}, "while ($expression) {";
			push @{$code}, @{$self->compile_statements_block($statement->{block}, [])};
			push @{$code}, "}";
		} elsif (($statement->{type} eq 'void_return_statement')) {
			push @{$code}, "return;";
		} elsif (($statement->{type} eq 'return_statement')) {
			my $expression = $self->compile_expression($statement->{expression});
			push @{$code}, "return $expression;";
		} elsif (($statement->{type} eq 'list_push_statement')) {
			my $left_expression = $self->compile_expression($statement->{left_expression});
			my $right_expression = $self->compile_expression($statement->{right_expression});
			push @{$code}, "$left_expression->exchangeArray(array_merge($left_expression->getArrayCopy(), $right_expression->getArrayCopy()));";
		} elsif (($statement->{type} eq 'push_statement')) {
			my $left_expression = $self->compile_expression($statement->{left_expression});
			my $right_expression = $self->compile_expression($statement->{right_expression});
			push @{$code}, "$left_expression\[] = $right_expression;";
		} elsif (($statement->{type} eq 'die_statement')) {
			my $expression = $self->compile_expression($statement->{expression});
			push @{$code}, "die $expression;";
		} elsif (($statement->{type} eq 'print_statement')) {
			my $expression = $self->compile_expression($statement->{expression});
			push @{$code}, "print($expression . \"\\n\");";
		} elsif (($statement->{type} eq 'variable_declaration_statement')) {
			$self->{variable_scope}->{$statement->{identifier}} = $statement->{variable_type};
		} elsif (($statement->{type} eq 'variable_assignment_statement')) {
			my $expression = $self->compile_expression($statement->{expression});
			push @{$code}, "\$$statement->{identifier} = $expression;";
		} elsif (($statement->{type} eq 'variable_declaration_assignment_statement')) {
			$self->{variable_scope}->{$statement->{identifier}} = $statement->{variable_type};
			my $expression = $self->compile_expression($statement->{expression});
			push @{$code}, "\$$statement->{identifier} = $expression;";
		} elsif (($statement->{type} eq 'expression_statement')) {
			my $expression = $self->compile_expression($statement->{expression});
			push @{$code}, "$expression;";
		} else {
			die "invalid statement type: $statement->{type}";
		}
		return $code;
	}
	
	sub compile_expression {
		my ($self, $expression) = @_;
		if (($expression->{type} eq 'string_expression')) {
			return $self->compile_string_expression($expression->{value});
		} elsif (($expression->{type} eq 'integer_expression')) {
			return $expression->{value};
		} elsif (($expression->{type} eq 'variable_expression')) {
			if (not (exists($self->{variable_scope}->{$expression->{identifier}}))) {
				die "undefined variable referenced: $expression->{identifier}";
			}
			if (($expression->{identifier} eq "self")) {
				return "\$this";
			} else {
				return "\$$expression->{identifier}";
			}
		} elsif (($expression->{type} eq 'match_index_expression')) {
			if (($expression->{index} < 0)) {
				die "match index cannot be negative";
			}
			return "\$match[$expression->{index}][0]";
		} elsif (($expression->{type} eq 'match_position_expression')) {
			return "strlen(\$match[0][0]) + \$match[0][1]";
		} elsif (($expression->{type} eq 'empty_list_expression')) {
			return "(new ArrayObject([]))";
		} elsif (($expression->{type} eq 'empty_tree_expression')) {
			return "(new ArrayObject([], ArrayObject::ARRAY_AS_PROPS))";
		} elsif (($expression->{type} eq 'list_constructor_expression')) {
			my $expression_list = $self->compile_expression_list($expression->{expression_list});
			return "(new ArrayObject([ $expression_list ]))";
		} elsif (($expression->{type} eq 'tree_constructor_expression')) {
			my $expression_list = $self->compile_tree_constructor($expression->{expression_list});
			return "(new ArrayObject([ $expression_list ], ArrayObject::ARRAY_AS_PROPS))";
		} elsif (($expression->{type} eq 'not_expression')) {
			my $sub_expression = $self->compile_expression($expression->{expression});
			return "!($sub_expression)";
		} elsif (($expression->{type} eq 'join_expression')) {
			my $left_expression = $self->compile_expression($expression->{left_expression});
			my $right_expression = $self->compile_expression($expression->{right_expression});
			return "implode($left_expression, $right_expression->getArrayCopy())";
		} elsif (($expression->{type} eq 'split_expression')) {
			my $left_expression = $self->compile_expression($expression->{left_expression});
			my $right_expression = $self->compile_expression($expression->{right_expression});
			return "(new ArrayObject(explode($left_expression, $right_expression), ArrayObject::ARRAY_AS_PROPS))";
		} elsif (($expression->{type} eq 'flatten_expression')) {
			my $sub_expression = $self->compile_expression($expression->{expression});
			return "call_user_func_array('array_merge', $sub_expression->getArrayCopy())";
		} elsif (($expression->{type} eq 'map_expression')) {
			my $left_expression = $self->compile_expression_with_variables($expression->{left_expression}, [ { variable_type => ('*'), identifier => ('_') } ]);
			my $right_expression = $self->compile_expression($expression->{right_expression});
			return "array_map(function (\$_) { return $left_expression; }, $right_expression)";
		} elsif (($expression->{type} eq 'grep_expression')) {
			my $left_expression = $self->compile_expression_with_variables($expression->{left_expression}, [ { variable_type => ('*'), identifier => ('_') } ]);
			my $right_expression = $self->compile_expression($expression->{right_expression});
			return "array_filter(function (\$_) { return $left_expression; }, $right_expression)";
		} elsif (($expression->{type} eq 'length_expression')) {
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
				return "strlen($sub_expression)";
			} elsif (($expression_type eq 'list')) {
				return "count($sub_expression)";
			} else {
				die "invalid value type for length expression: '$expression_type'";
			}
		} elsif (($expression->{type} eq 'pop_expression')) {
			my $sub_expression = $self->compile_expression($expression->{expression});
			return "array_pop($sub_expression)";
		} elsif (($expression->{type} eq 'shift_expression')) {
			my $sub_expression = $self->compile_expression($expression->{expression});
			return "array_shift($sub_expression)";
		} elsif (($expression->{type} eq 'contains_expression')) {
			if (($expression->{expression}->{type} eq 'access_expression') or ($expression->{expression}->{type} eq 'expression_access_expression')) {
			} else {
				die "invalid expression for contains expression: $expression->{expression}{type}";
			}
			my $sub_expression = $self->compile_expression($expression->{expression});
			return "isset($sub_expression)";
		} elsif (($expression->{type} eq 'clone_expression')) {
			my $expression_type = $self->get_expression_type($expression->{expression});
			if (not ($expression_type)) {
				die "ambiguous type clone expression";
			}
			my $sub_expression = $self->compile_expression($expression->{expression});
			if (($expression_type eq 'tree')) {
				return "array_merge($sub_expression)";
			} elsif (($expression_type eq 'list')) {
				return "array_merge($sub_expression)";
			} else {
				die "invalid value type for clone expression: '$expression_type'";
			}
		} elsif (($expression->{type} eq 'assignment_expression')) {
			my $left_expression = $self->compile_expression($expression->{left_expression});
			my $right_expression = $self->compile_expression($expression->{right_expression});
			return "$left_expression = $right_expression";
		} elsif (($expression->{type} eq 'addition_assignment_expression')) {
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
		} elsif (($expression->{type} eq 'access_expression')) {
			my $sub_expression = $self->compile_expression($expression->{expression});
			return "$sub_expression\->$expression->{identifier}";
		} elsif (($expression->{type} eq 'expression_access_expression')) {
			my $left_expression = $self->compile_expression($expression->{left_expression});
			my $right_expression = $self->compile_expression($expression->{right_expression});
			return "$left_expression\[$right_expression]";
		} elsif (($expression->{type} eq 'access_call_expression')) {
			my $sub_expression = $self->compile_expression($expression->{expression});
			my $expression_list = $self->compile_expression_list($expression->{expression_list});
			return "$sub_expression\->$expression->{identifier}\($expression_list)";
		} elsif (($expression->{type} eq 'call_expression')) {
			my $sub_expression = $self->compile_expression($expression->{expression});
			my $expression_list = $self->compile_expression_list($expression->{expression_list});
			return "$sub_expression\->($expression_list)";
		} elsif (($expression->{type} eq 'object_assignment_expression')) {
			my $left_expression = $self->compile_expression($expression->{left_expression});
			my $right_expression = $self->compile_expression($expression->{right_expression});
			return "$left_expression\->{$expression->{identifier}} = $right_expression";
		} elsif (($expression->{type} eq 'numeric_comparison_expression')) {
			my $left_expression = $self->compile_expression($expression->{left_expression});
			my $right_expression = $self->compile_expression($expression->{right_expression});
			return "($left_expression $expression->{operator} $right_expression)";
		} elsif (($expression->{type} eq 'comparison_expression')) {
			my $expression_type = $self->infer_expression_type($expression);
			my $left_expression = $self->compile_expression($expression->{left_expression});
			my $right_expression = $self->compile_expression($expression->{right_expression});
			if (($expression_type eq 'string')) {
				my $operator;
				if (($expression->{operator} eq '==')) {
					$operator = '===';
				} else {
					$operator = '!==';
				}
				return "($left_expression $operator $right_expression)";
			} else {
				return "($left_expression $expression->{operator} $right_expression)";
			}
		} elsif (($expression->{type} eq 'regex_match_expression')) {
			my $sub_expression = $self->compile_expression($expression->{expression});
			my $compiled_regex = $self->compile_regex_expression($expression->{regex});
			my $operator = '===';
			if (($expression->{operator} eq '!~')) {
				$operator = '!==';
			}
			if ($compiled_regex->{has_g}) {
				return "(preg_match('/$compiled_regex->{regex}/$compiled_regex->{flags}', $sub_expression, \$match, PREG_OFFSET_CAPTURE, isset(\$_offset)?\$_offset:0) $operator 1 && \$_offset = strlen(\$match[0][0]) + \$match[0][1])";
			} else {
				return "(preg_match('/$compiled_regex->{regex}/$compiled_regex->{flags}', $sub_expression, \$match, PREG_OFFSET_CAPTURE) $operator 1)";
			}
		} elsif (($expression->{type} eq 'regex_substitution_expression')) {
			my $sub_expression = $self->compile_expression($expression->{expression});
			my $regex_expression = $self->compile_substitution_expression($expression->{regex});
			return "($sub_expression =~ $regex_expression)";
		} else {
			die "invalid expression type: $expression->{type}";
		}
	}
	
	sub compile_regex_expression {
		my ($self, $regex_token) = @_;
		if (($regex_token =~ /\A\/((?:[^\\\/]|\\.)*+)\/([msixpodualngc]*+)\Z/s)) {
			my $regex = $1;
			my $flags = $2;
			my $has_g = 0;
			if (($flags =~ /g/)) {
				$flags = ($flags =~ s/g//r);
				$has_g = 1;
			}
			return { regex => ($regex), flags => ($flags), has_g => ($has_g) };
		} else {
			die "failed to compile regex expression: $regex_token";
		}
	}
	
	sub compile_substitution_expression {
		my ($self, $regex_token) = @_;
		if (($regex_token =~ /\As\/((?:[^\\\/]|\\.)*+)\/((?:[^\\\/]|\\.)*+)\/([msixpodualngc]*+)\Z/s)) {
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
		my $is_quoted;
		if (($string_token =~ /\A'/s)) {
			return $string_token;
		} elsif (($string_token =~ /\A"(.*)"\Z/s)) {
			$string_content = $1;
			$is_quoted = 1;
		} else {
			$string_content = $string_token;
			$is_quoted = 0;
		}
		if (($string_content eq '')) {
			return $string_token;
		}
		my $compiled_string = '';
		my $last_match_position = 0;
		while (($string_content =~ /\G(?:((?:[^\$\\]|\\.)+)|\$(\d+)|\$(\w+)(?:\.(\w+(?:\.\w+)*))?|\$\{(\w+)(?:\.(\w+(?:\.\w+)*))?\})/gsc)) {
			my $text_match = $1;
			my $match_variable_match = $2;
			my $variable_match = $3;
			my $variable_access = $4;
			my $protected_variable_match = $5;
			my $protected_variable_access = $6;
			$last_match_position = $+[0];
			if ($text_match) {
				$compiled_string .= $text_match;
			} elsif ($match_variable_match) {
				$compiled_string .= "\$$match_variable_match";
			} elsif ($variable_match) {
				if (not (exists($self->{variable_scope}->{$variable_match}))) {
					die "undefined variable in string interpolation: $variable_match";
				}
				if ($variable_access) {
					$compiled_string .= "{\$$variable_match";
					$compiled_string .= join('', @{[ map { "->$_" } @{[ split(quotemeta("."), $variable_access) ]} ]});
					$compiled_string .= "}";
				} else {
					$compiled_string .= "{\$$variable_match}";
				}
			} else {
				if (not (exists($self->{variable_scope}->{$protected_variable_match}))) {
					die "undefined variable in string interpolation: $protected_variable_match";
				}
				if ($protected_variable_access) {
					$compiled_string .= "{\$$protected_variable_match";
					$compiled_string .= join('', @{[ map { "->$_" } @{[ split(quotemeta("."), $protected_variable_access) ]} ]});
					$compiled_string .= "}";
				} else {
					$compiled_string .= "{\$$protected_variable_match}";
				}
			}
		}
		if (($last_match_position < length($string_content))) {
			die "failed to compile string expression: $string_token";
		}
		if ($is_quoted) {
			return "\"$compiled_string\"";
		} else {
			return $compiled_string;
		}
	}
	
	sub compile_argument_list {
		my ($self, $argument_list) = @_;
		my $true_argument_list = [];
		my $i = 0;
		foreach my $arg (@{$argument_list}) {
			if (($i > 0)) {
				push @{$true_argument_list}, $arg;
			}
			$i += 1;
		}
		return join(', ', @{[ map { "\$$_->{identifier}" } @{$true_argument_list} ]});
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
			push @{$pairs}, $self->compile_tree_constructor_pair($key, $expression);
		}
		return join(', ', @{$pairs});
	}
	
	sub compile_tree_constructor_pair {
		my ($self, $key, $expression) = @_;
		return "'$key' => $expression";
	}
	
	sub main {
		my ($self) = @_;
	
	my ($files_list) = @_;

	# require Data::Dumper;
	require Sugar::IO::File;
	use Sugar::Lang::SugarsweetParser;

	my $parser = Sugar::Lang::SugarsweetParser->new;
	my $compiler = __PACKAGE__->new;
	foreach my $file (@$files_list) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		my $tree = $parser->parse;
		# say Dumper $tree;

		say $compiler->compile_file($tree);
	}

	}
	
	caller or main(\@ARGV);
	

1;

