package Sugar::Lang::SyntaxIntermediateCompiler;
use strict;
use warnings;

use feature 'say';

use Carp;
use Data::Dumper;



sub new {
	my ($class, %opts) = @_;
	my $self = bless {}, $class;

	$self->{syntax_definition_intermediate} = $opts{syntax_definition_intermediate}
			// croak "syntax_definition_intermediate argument required for Sugar::Lang::SyntaxIntermediateCompiler";

	$self->{variables} = $self->{syntax_definition_intermediate}{variables};
	$self->{tokens} = [];
	$self->{ignored_tokens} = $self->{syntax_definition_intermediate}{ignored_tokens};
	$self->{context_order} = $self->{syntax_definition_intermediate}{context_order};
	$self->{item_contexts} = $self->{syntax_definition_intermediate}{item_contexts};
	$self->{list_contexts} = $self->{syntax_definition_intermediate}{list_contexts};
	$self->{object_contexts} = $self->{syntax_definition_intermediate}{object_contexts};
	$self->{subroutine_order} = $self->{syntax_definition_intermediate}{subroutine_order};
	$self->{subroutines} = $self->{syntax_definition_intermediate}{subroutines};
	$self->{code_definitions} = {};
	$self->{package_identifier} = $self->{syntax_definition_intermediate}{package_identifier} // 'PACKAGE_NAME';
	$self->compile_syntax_intermediate;

	return $self
}

sub to_package {
	my ($self) = @_;

	my $code = '';

	$code .= "#!/usr/bin/env perl
package $self->{package_identifier};
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use Sugar::IO::File;
# use Sugar::Lang::SyntaxIntermediateCompiler;



";

	$code .= "our \$tokens = [\n";
	foreach my $i (0 .. $#{$self->{tokens}} / 2) {
		$code .= "\t'$self->{tokens}[$i*2]' => $self->{tokens}[$i*2+1],\n";
	}
	$code .= "];\n\n";

	$code .= "our \$ignored_tokens = [\n";
	foreach my $token (@{$self->{ignored_tokens}}) {
		$code .= "\t'$token',\n";
	}
	$code .= "];\n\n";

	$code .= "our \$contexts = {\n";
	foreach my $context_type (sort keys %{$self->{code_definitions}}) {
		$code .= "\t$context_type => 'context_$context_type',\n";
	}
	$code .= "};\n\n";

	$code .= '

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
		say Dumper $tree;

		# my $compiler = Sugar::Lang::SyntaxIntermediateCompiler->new(syntax_definition_intermediate => $tree);
		# say $compiler->to_package;
	}
}

caller or main(@ARGV);

';

	foreach my $context_type (@{$self->{context_order}}) {
		$code .= $self->{code_definitions}{$context_type} =~ s/\A(\s*)sub \{/$1sub context_$context_type {/r;
	}

	foreach my $subroutine (@{$self->{subroutine_order}}) {
		my $subroutine_code = $self->{subroutines}{$subroutine};
		$subroutine_code =~ s/\A\{\{(.*)\}\}\Z/{$1}/s;
		$code .= "sub $subroutine $subroutine_code\n\n";
	}

	return $code
}

sub confess_at_current_line {
	my ($self, $msg) = @_;
	confess "syntax error on line $self->{current_line}: $msg";
}

sub get_variable {
	my ($self, $identifier) = @_;
	$self->confess_at_current_line("undefined variable requested: '$identifier'") unless exists $self->{variables}{$identifier};
	return $self->{variables}{$identifier}
}

sub get_function_by_name {
	my ($self, $value) = @_;
	if ($value =~ /\A\!(\w++)\Z/) {
		my $context_type = $1;
		if (defined $self->{object_contexts}{$context_type}) {
			return "context_$context_type"
		} elsif (defined $self->{list_contexts}{$context_type}) {
			return "context_$context_type"
		} elsif (defined $self->{item_contexts}{$context_type}) {
			return "context_$context_type"
		} else {
			$self->confess_at_current_line("undefined context requested: '$context_type'");
		}

	} elsif ($value =~ /\A\&(\w++)\Z/) {
		return "$1"

	} else {
		$self->confess_at_current_line("unknown context type requested: '$value'");
	}
}

sub compile_syntax_intermediate {
	my ($self) = @_;

	my @token_definitions = @{$self->{syntax_definition_intermediate}{tokens}};
	while (@token_definitions) {
		my $key = shift @token_definitions;
		my $value = $self->compile_syntax_token_value(shift @token_definitions);
		push @{$self->{tokens}}, $key, $value;
	}
	foreach my $context_name (keys %{$self->{syntax_definition_intermediate}{item_contexts}}) {
		my $context_definition = $self->{syntax_definition_intermediate}{item_contexts}{$context_name};
		$self->{code_definitions}{$context_name} = $self->compile_syntax_context('item_context', $context_name, $context_definition);
	}
	foreach my $context_name (keys %{$self->{syntax_definition_intermediate}{list_contexts}}) {
		my $context_definition = $self->{syntax_definition_intermediate}{list_contexts}{$context_name};
		$self->{code_definitions}{$context_name} = $self->compile_syntax_context('list_context', $context_name, $context_definition);
	}
	foreach my $context_name (keys %{$self->{syntax_definition_intermediate}{object_contexts}}) {
		my $context_definition = $self->{syntax_definition_intermediate}{object_contexts}{$context_name};
		$self->{code_definitions}{$context_name} = $self->compile_syntax_context('object_context', $context_name, $context_definition);
	}
}

sub compile_syntax_token_value {
	my ($self, $value) = @_;
	if ($value =~ m#\A/([^\\/]|\\.)*+/[msixpodualn]*\Z#s) {
		return "qr$value"
	} elsif ($value =~ /\A\$(\w++)\Z/) {
		return $self->compile_syntax_token_value($self->get_variable($1))
	} else {
		confess "invalid syntax token value: $value";
	}
}

sub compile_syntax_context {
	my ($self, $context_type, $context_name, $context) = @_;

	my $code = '
sub {';
	my @args_list = ('$self');
	if ($context_name ne 'root') {
		if ($context_type eq 'object_context') {
			push @args_list, '$context_object';
		} elsif ($context_type eq 'list_context') {
			push @args_list, '$context_list';
		} else {
			push @args_list, '$context_value';
		}
	}
	my $args_list_string = join ', ', @args_list;
	$code .= "
	my ($args_list_string) = \@_;
";

	if ($context_name eq 'root') {
		if ($context_type eq 'object_context') {
			$code .= "\tmy \$context_object = {};\n";
		} elsif ($context_type eq 'list_context') {
			$code .= "\tmy \$context_list = [];\n";
		} else {
			$code .= "\tmy \$context_value;\n";
		}
	}

	# $code .= "\t\tsay 'in context $context_name';\n"; # DEBUG INLINE TREE BUILDER
	$code .= '
	while ($self->more_tokens) {
		my @tokens;
';

	$code .= $self->compile_syntax_action($context_type, undef, $context);

	$code .= "\t}\n";

	if ($context_type eq 'object_context') {
		$code .= "\treturn \$context_object;\n";
	} elsif ($context_type eq 'list_context') {
		$code .= "\treturn \$context_list;\n";
	} else {
		$code .= "\treturn \$context_value;\n";
	}

	$code .= "}\n";
	# say "compiled code: ", $code; # DEBUG INLINE TREE BUILDER
	# my $compiled = eval $code;
	# if ($@) {
	# 	confess "error compiling context type '$context_name': $@";
	# }
	# return $compiled
	return $code
}

sub compile_syntax_condition {
	my ($self, $condition, $offset) = @_;
	$offset //= 0;
	if (ref $condition eq 'ARRAY') {
		my @conditions = @$condition;
		foreach my $i (0 .. $#conditions) {
			$conditions[$i] = $self->compile_syntax_condition($conditions[$i], $i);
		}
		return join ' and ', '$self->more_tokens', @conditions
	} elsif ($condition =~ m#\A\$(\w++)\Z#s) {
		return $self->compile_syntax_condition($self->get_variable($1), $offset)
	} elsif ($condition =~ m#\A/(.*)/([msixpodualn]*)\Z#s) {
		return "\$self->{tokens}[\$self->{tokens_index} + $offset][1] =~ /\\A$1\\Z/$2"
	} elsif ($condition =~ /\A'.*'\Z/s) {
		return "\$self->{tokens}[\$self->{tokens_index} + $offset][1] eq $condition"
	} else {
		$self->confess_at_current_line("invalid syntax condition '$condition'");
	}
}

sub compile_syntax_action {
	my ($self, $context_type, $condition, $actions_list) = @_;

	my @code;

	if (defined $condition and ref $condition eq 'ARRAY') {
		my $count = @$condition;
		push @code, "\@tokens = (\@tokens, \$self->step_tokens($count));";
	} elsif (defined $condition) {
		push @code, "\@tokens = (\@tokens, \$self->next_token->[1]);";
	} else {
		# push @code, "my \@tokens;";
	}
	
	# my @actions = @$actions_list;
	# while (@actions) {
		# my $action = shift @actions;
	foreach my $action (@$actions_list) {
		$self->{current_line} = $action->{line_number};

		if ($action->{type} eq 'push_statement') {
			my $expression = $self->compile_syntax_spawn_expression($context_type, $action->{expression});
			if ($context_type eq 'list_context') {
				push @code, "push \@\$context_list, $expression;";
			} else {
				$self->confess_at_current_line("use of push in $context_type");
			}
		} elsif ($action->{type} eq 'assign_item_statement') {
			my $expression = $self->compile_syntax_spawn_expression($context_type, $action->{expression});
			if ($context_type eq 'object_context') {
				push @code, "\$context_object = $expression;";
			} elsif ($context_type eq 'list_context') {
				push @code, "\$context_list = $expression;";
			} else {
				push @code, "\$context_value = $expression;";
			}
			
		} elsif ($action->{type} eq 'assign_field_statement') {
			my $key = $self->compile_syntax_spawn_expression($context_type, $action->{key});
			my $expression = $self->compile_syntax_spawn_expression($context_type, $action->{expression});
			push @code, "\$context_object->{$key} = $expression;";
			
		} elsif ($action->{type} eq 'assign_array_field_statement') {
			my $key = $self->compile_syntax_spawn_expression($context_type, $action->{key});
			my $expression = $self->compile_syntax_spawn_expression($context_type, $action->{expression});
			push @code, "push \@{\$context_object->{$key}}, $expression;";
			
		} elsif ($action->{type} eq 'assign_object_field_statement') {
			my $key = $self->compile_syntax_spawn_expression($context_type, $action->{key});
			my $subkey = $self->compile_syntax_spawn_expression($context_type, $action->{subkey});
			my $expression = $self->compile_syntax_spawn_expression($context_type, $action->{expression});
			push @code, "\$context_object->{$key}{$subkey} = $expression;";

		} elsif ($action->{type} eq 'return_statement') {
			if ($context_type eq 'object_context') {
				push @code, "return \$context_object;";
			} elsif ($context_type eq 'list_context') {
				push @code, "return \$context_list;";
			} else {
				push @code, "return \$context_value;";
			}

			$self->{context_default_case} //= [ { type => 'die_statement', expression => { type => 'string', string => "'unexpected token'" } } ];

		} elsif ($action->{type} eq 'match_statement') {
			my $match_condition = $action->{match_list};
			push @code, "\$self->confess_at_current_offset('expected " . (join ', ', @$match_condition) =~ s/([\\'])/\\$1/gr . "')";
			push @code, "\tunless " . $self->compile_syntax_condition($match_condition) . ";";

			my $count = @$match_condition;
			push @code, "\@tokens = (\@tokens, \$self->step_tokens($count));";

		} elsif ($action->{type} eq 'if_statement') {
			my $condition = $action->{match_list};
			my $conditional_actions = $action->{block};

			my $condition_code = $self->compile_syntax_condition($condition);
			my $action_code = $self->compile_syntax_action($context_type, $condition, $conditional_actions);

			push @code, "if ($condition_code) {\n\t\t\tmy \@tokens_freeze = \@tokens;\n\t\t\tmy \@tokens = \@tokens_freeze;$action_code\t\t\t}";

			while (exists $action->{branch}) {
				$action = $action->{branch};
				if ($action->{type} eq 'elsif_statement') {
					my $condition = $action->{match_list};
					my $conditional_actions = $action->{block};

					my $condition_code = $self->compile_syntax_condition($condition);
					my $action_code = $self->compile_syntax_action($context_type, $condition, $conditional_actions);

					push @code, "elsif ($condition_code) {\n\t\t\tmy \@tokens_freeze = \@tokens;\n\t\t\tmy \@tokens = \@tokens_freeze;$action_code\t\t\t}";
				} else {
					my $conditional_actions = $action->{block};
					my $action_code = $self->compile_syntax_action($context_type, undef, $conditional_actions);

					push @code, "else {$action_code\t\t\t}";
				}
			}

		} elsif ($action->{type} eq 'switch_statement') {
			my $first = 1;
			foreach my $case (@{$action->{switch_cases}}) {
				$self->{current_line} = $case->{line_number};
				if ($case->{type} eq 'match_case') {
					my $condition_code = $self->compile_syntax_condition($case->{match_list});
					my $action_code = $self->compile_syntax_action($context_type, $case->{match_list}, $case->{block});

					if ($first) {
						push @code, "if ($condition_code) {\n\t\t\tmy \@tokens_freeze = \@tokens;\n\t\t\tmy \@tokens = \@tokens_freeze;$action_code\t\t\t}";
						$first = 0;
					} else {
						push @code, "elsif ($condition_code) {\n\t\t\tmy \@tokens_freeze = \@tokens;\n\t\t\tmy \@tokens = \@tokens_freeze;$action_code\t\t\t}";
					}
				} elsif ($case->{type} eq 'default_case') {
					my $action_code = $self->compile_syntax_action($context_type, undef, $case->{block});
					push @code, "else {$action_code\t\t\t}";
				} else {
					$self->confess_at_current_line("invalid switch case type: $case->{type}");
				}
			}

		} elsif ($action->{type} eq 'while_statement') {
			my $condition = $action->{match_list};
			my $conditional_actions = $action->{block};

			my $condition_code = $self->compile_syntax_condition($condition);
			my $action_code = $self->compile_syntax_action($context_type, $condition, $conditional_actions);

			push @code, "while ($condition_code) {\n\t\t\tmy \@tokens_freeze = \@tokens;\n\t\t\tmy \@tokens = \@tokens_freeze;$action_code\t\t\t}";


		} elsif ($action->{type} eq 'warn_statement') {
			my $expression = $self->compile_syntax_spawn_expression($context_type, $action->{expression});
			push @code, "warn ($expression);";

		} elsif ($action->{type} eq 'die_statement') {
			my $expression = $self->compile_syntax_spawn_expression($context_type, $action->{expression});
			push @code, "\$self->confess_at_current_offset($expression);";

		} else {
			die "undefined action '$action->{type}'";
		}
	}



	return join ("\n\t\t\t", '', @code) . "\n";
}

sub compile_syntax_spawn_expression {
	my ($self, $context_type, $expression) = @_;

	if ($expression->{type} eq 'undef') {
		return 'undef'

	} elsif ($expression->{type} eq 'get_token_line_number') {
		$self->confess_at_current_line("invalid spawn expression token: '$expression->{token}'") unless $expression->{token} =~ /\A\$(\d+)\Z/s;
		return "\$tokens[$1][2]";
	} elsif ($expression->{type} eq 'get_token_line_offset') {
		$self->confess_at_current_line("invalid spawn expression token: '$expression->{token}'") unless $expression->{token} =~ /\A\$(\d+)\Z/s;
		return "\$tokens[$1][3]";
	} elsif ($expression->{type} eq 'get_token_text') {
		$self->confess_at_current_line("invalid spawn expression token: '$expression->{token}'") unless $expression->{token} =~ /\A\$(\d+)\Z/s;
		return "\$tokens[$1][1]";

	} elsif ($expression->{type} eq 'get_context') {
		if ($context_type eq 'object_context') {
			return "\$context_object"
		} elsif ($context_type eq 'list_context') {
			return "\$context_list"
		} else {
			return "\$context_value"
		}

	} elsif ($expression->{type} eq 'pop_list') {
		if ($context_type eq 'list_context') {
			return "pop \@\$context_list";
		} else {
			$self->confess_at_current_line("use of pop in $context_type");
		}

	} elsif ($expression->{type} eq 'call_context') {
		# warn "got call_expression: $expression";
		my $context = $self->get_function_by_name($expression->{context});
		if (exists $expression->{argument}) {
			return "\$self->$context(" . $self->compile_syntax_spawn_expression($context_type, $expression->{argument}) . ")";
		} else {
			return "\$self->$context";
		}

	} elsif ($expression->{type} eq 'call_function') {
		# warn "got call_expression: $expression";
		my $function = $self->get_function_by_name($expression->{function});
		if (exists $expression->{argument}) {
			return "\$self->$function(" . $self->compile_syntax_spawn_expression($context_type, $expression->{argument}) . ")";
		} else {
			return "\$self->$function";
		}

	} elsif ($expression->{type} eq 'string') {
		$self->confess_at_current_line("invalid spawn expression string: '$expression->{string}'") unless $expression->{string} =~ /\A'(.*)'\Z/s;
		return "'$1'";
	} elsif ($expression->{type} eq 'empty_list') {
		return '[]'
	} elsif ($expression->{type} eq 'empty_hash') {
		return '{}'
	} elsif ($expression->{type} eq 'hash_constructor') {
		my $code = "{ ";
		my @items = @{$expression->{arguments}};
		while (@items) {
			my $field = shift @items;
			my $value = shift @items;
			$code .= $self->compile_syntax_spawn_expression($context_type, $field) . " => " . $self->compile_syntax_spawn_expression($context_type, $value) . ", ";
		}
		$code .= "}";
		return $code

	} else {
		$self->confess_at_current_line("invalid spawn expression: '$expression->{type}'");
	}

}

1;
