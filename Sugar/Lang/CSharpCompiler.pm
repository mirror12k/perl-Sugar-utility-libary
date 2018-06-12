#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

package Sugar::Lang::SugarGrammarCSharpCompiler;
sub new {
	my ($self, $args) = @_;
	$self = bless {}, $self;
	if (exists($args->{syntax_definition_intermediate})) {
		$self->load_syntax_definition_intermediate($args->{syntax_definition_intermediate});
	} else {
		die "syntax_definition_intermediate argument required for Sugar::Lang::SugarGrammarCompiler";
	}
	return $self;
}

sub load_syntax_definition_intermediate {
	my ($self, $intermediate) = @_;
	$self->{syntax_definition_intermediate} = $intermediate;
	$self->{global_variable_names} = $self->{syntax_definition_intermediate}->{global_variable_names};
	$self->{global_variable_expressions} = $self->{syntax_definition_intermediate}->{global_variable_expressions};
	$self->{variables_scope} = { '$_' => ('context_value'), '#tokens' => ('tokens0') };
	$self->{tokens_scope_index} = 0;
	$self->{token_definitions} = [];
	$self->{ignored_tokens} = $self->{syntax_definition_intermediate}->{ignored_tokens};
	$self->{contexts} = $self->{syntax_definition_intermediate}->{contexts};
	$self->{contexts_by_name} = $self->{syntax_definition_intermediate}->{contexts_by_name};
	$self->{subroutines} = $self->{syntax_definition_intermediate}->{subroutines};
	$self->{code_definitions} = {};
	if (exists($self->{syntax_definition_intermediate}->{package_identifier})) {
		$self->{package_identifier} = $self->{syntax_definition_intermediate}->{package_identifier};
	} else {
		$self->{package_identifier} = 'PACKAGE_NAME';
	}
}

sub to_package {
	my ($self) = @_;
	my $code = '';
	my $package_pieces = [ split('::', $self->{package_identifier}) ];
	my $namespace_pieces = [];
	my $last_piece = "";
	foreach my $piece (@{$package_pieces}) {
		if (($last_piece ne "")) {
			push @{$namespace_pieces}, $last_piece;
		}
		$last_piece = $piece;
	}
	my $class_name = $last_piece;
	$code .= "
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

using Sugar.Lang;


";
	if ((0 < scalar(@{$namespace_pieces}))) {
		my $class_namespace = join('.', @{$namespace_pieces});
		$code .= "
namespace $class_namespace {
";
	}
	$code .= "
public class $class_name : Sugar.Lang.BaseSyntaxParser {
";
	$code .= "\n\n//////////////////////////////\n///// variables and settings\n//////////////////////////////\n\n";
	if ((0 < scalar(@{$self->{global_variable_names}}))) {
		foreach my $key (@{$self->{global_variable_names}}) {
			my $value = $self->{global_variable_expressions}->{$key};
			$code .= "\tpublic static $value->{type} var_$key = $value->{value};\n";
		}
	}
	$code .= "\n\n";
	$code .= "\tpublic static List<string> grammar_tokens = new List<string> {\n";
	if ((0 < scalar(@{$self->{token_definitions}}))) {
		foreach my $token_definition (@{$self->{token_definitions}}) {
			$code .= "\t\t\"$token_definition->{key}\", $token_definition->{value},\n";
		}
	}
	$code .= "\t};\n\n";
	$code .= "\tpublic static List<string> grammar_ignored_tokens = new List<string> {\n";
	foreach my $token (@{$self->{ignored_tokens}}) {
		$code .= "\t\t\"$token\",\n";
	}
	$code .= "\t};\n\n";
	$code .= "\n\n//////////////////////////////\n///// api\n//////////////////////////////\n\n";
	$code .= "

\tpublic $class_name () : base(\"\", \"\", grammar_tokens, grammar_ignored_tokens) {}

\t// Parse is also part of the api, but no point in overriding it
\t// public override Object Parse();

";
	$code .= "\n\n//////////////////////////////\n///// sugar contexts functions\n//////////////////////////////\n\n";
	foreach my $context (@{$self->{contexts}}) {
		$code .= $self->{code_definitions}->{$context->{identifier}};
	}
	$code .= "
}
";
	if ((0 < scalar(@{$namespace_pieces}))) {
		$code .= "
}
";
	}
	return $code;
}

sub confess_at_current_line {
	my ($self, $msg) = @_;
	die "syntax error on line $self->{current_line}: $msg";
}

sub get_variable {
	my ($self, $variable) = @_;
	if (not (exists($self->{variables_scope}->{$variable}))) {
		$self->confess_at_current_line("undefined variable requested: '$variable'");
	}
	return $self->{variables_scope}->{$variable};
}

sub exists_variable {
	my ($self, $variable) = @_;
	return exists($self->{variables_scope}->{$variable});
}

sub add_variable {
	my ($self, $variable) = @_;
	if (($variable =~ /\A\$(\w+)\Z/s)) {
		$self->{variables_scope}->{$variable} = "var_$1";
		return $self->{variables_scope}->{$variable};
	} else {
		$self->confess_at_current_line("invalid variable in add_variable: '$variable'");
	}
}

sub get_function_by_name {
	my ($self, $name) = @_;
	if (($name =~ /\A\!(\w++)\Z/)) {
		my $context_identifier = $1;
		if (exists($self->{contexts_by_name}->{$context_identifier})) {
			return "context_$context_identifier";
		} else {
			$self->confess_at_current_line("undefined context requested: '$context_identifier'");
		}
	} elsif (($name =~ /\A\&(\w++)\Z/)) {
		return "$1";
	} else {
		$self->confess_at_current_line("unknown context type requested: '$name'");
	}
}

sub compile_syntax_intermediate {
	my ($self) = @_;
	foreach my $key (@{$self->{global_variable_names}}) {
		my $value = $self->compile_syntax_token_value($self->{global_variable_expressions}->{$key});
		my $value_type = 'string';
		if (($self->{global_variable_expressions}->{$key}->{type} eq 'substitution_regex_value')) {
			$value_type = 'Func<string, string>';
		}
		$self->{global_variable_expressions}->{$key} = { type => ($value_type), value => ($value) };
		$self->{variables_scope}->{"\$$key"} = "var_$key";
	}
	foreach my $token_definition (@{$self->{syntax_definition_intermediate}->{tokens}}) {
		my $key = $token_definition->{identifier};
		my $value = $self->compile_syntax_token_value($token_definition->{value});
		push @{$self->{token_definitions}}, { key => ($key), value => ($value) };
	}
	foreach my $context (@{$self->{syntax_definition_intermediate}->{contexts}}) {
		$self->{code_definitions}->{$context->{identifier}} = $self->compile_syntax_context($context);
	}
}

sub compile_syntax_token_value {
	my ($self, $value) = @_;
	if ($value->{type} eq 'regex_value') {
		if (($value->{value} =~ /\A\/(.*)\/([msixpodualn]*)\Z/s)) {
			return "\@\"(?$2:$1)\"";
		} else {
			$self->confess_at_current_line("failed to parse syntax regex value: $value->{value}");
		}
	} elsif ($value->{type} eq 'substitution_regex_value') {
		if (($value->{value} =~ /\As\/(.*)\/(.*)\/([msixpodualn]*)\Z/s)) {
			return "(s) => Regex.Replace(s, @\"(?$3:$1)\", \"$2\")";
		} else {
			$self->confess_at_current_line("failed to parse syntax substitution regex value: $value->{value}");
		}
	} elsif ($value->{type} eq 'variable_value') {
		return $self->get_variable($value->{value});
	} elsif ($value->{type} eq 'string_value') {
		return $value->{value};
	} else {
		$self->confess_at_current_line("invalid syntax token value: $value->{type}");
	}
}

sub compile_syntax_context {
	my ($self, $context) = @_;
	$self->{current_context} = $context;
	my $is_linear_context = 0;
	my $last_action;
	foreach my $action (@{$context->{block}}) {
		$last_action = $action;
	}
	if ($last_action) {
		if (($last_action->{type} eq 'return_statement')) {
			$is_linear_context = 1;
		} elsif (($last_action->{type} eq 'return_expression_statement')) {
			$is_linear_context = 1;
		}
	}
	my $code = [];
	my $context_object_type = 'DynamicValue';
	my $override_prefix = "";
	if (($context->{identifier} eq 'root')) {
		$override_prefix = " override";
	}
	if ($is_linear_context) {
		push @{$code}, "List<Token> tokens0 = new List<Token>();";
		$code = [ map { "\t$_" } @{$code} ];
		push @{$code}, '';
		push @{$code}, @{$self->compile_syntax_action(0, $context->{block})};
	} else {
		push @{$code}, "while (MoreTokens()) {";
		push @{$code}, "\tList<Token> tokens0 = new List<Token>();";
		push @{$code}, '';
		push @{$code}, @{$self->compile_syntax_action(0, $context->{block})};
		push @{$code}, "}";
		push @{$code}, "return context_value;";
		$code = [ map { "\t$_" } @{$code} ];
	}
	my $all_code = [];
	push @{$all_code}, "public$override_prefix DynamicValue context_$context->{identifier} (DynamicValue context_value=null) {";
	push @{$all_code}, @{$code};
	push @{$all_code}, "}";
	push @{$all_code}, "";
	return join('', @{[ map { "\t$_\n" } @{$all_code} ]});
}

sub compile_syntax_condition {
	my ($self, $condition, $offset) = @_;
	if (not ($offset)) {
		$offset = 0;
	}
	if ($condition->{type} eq 'function_match') {
		my $function = $self->get_function_by_name($condition->{function});
		if (exists($condition->{argument})) {
			my $expression_code = $self->compile_syntax_spawn_expression($condition->{argument});
			return "$function(tokens_index + $offset, $expression_code)";
		} else {
			return "$function(tokens_index + $offset)";
		}
	} elsif ($condition->{type} eq 'variable_match') {
		if (($condition->{variable} =~ /\A\$(\w++)\Z/s)) {
			my $variable = $self->get_variable($1);
			return "$variable->{IsMatch}(tokens[tokens_index + $offset].value)";
		} else {
			$self->confess_at_current_line("invalid variable condition value: $condition->{variable}");
		}
	} elsif ($condition->{type} eq 'regex_match') {
		if (($condition->{regex} =~ /\A\/(.*)\/([msixpodualn]*)\Z/s)) {
			return "Regex.IsMatch(\@\"\\A$1\\Z\", tokens[tokens_index + $offset].value)";
		} else {
			$self->confess_at_current_line("invalid regex condition value: $condition->{regex}");
		}
	} elsif ($condition->{type} eq 'string_match') {
		my $condition_string;
		if (($condition->{string} =~ /\A'(.*)'\Z/s)) {
			$condition_string = "\"$1\"";
		} else {
			$self->confess_at_current_line("invalid string condition value: $condition->{string}");
		}
		return "tokens[tokens_index + $offset].value == $condition_string";
	} elsif ($condition->{type} eq 'token_type_match') {
		return "tokens[tokens_index + $offset].type == \"$condition->{value}\"";
	} else {
		$self->confess_at_current_line("invalid syntax condition '$condition->{type}'");
	}
}

sub compile_syntax_match_list {
	my ($self, $match_list) = @_;
	my $conditions = [];
	push @{$conditions}, @{$match_list->{match_conditions}};
	push @{$conditions}, @{$match_list->{look_ahead_conditons}};
	my $compiled_conditions = [];
	push @{$compiled_conditions}, 'MoreTokens()';
	my $i = 0;
	foreach my $condition (@{$conditions}) {
		push @{$compiled_conditions}, $self->compile_syntax_condition($condition, $i);
		$i += 1;
	}
	return join(' && ', @{$compiled_conditions});
}

sub get_syntax_match_list_tokens_eaten {
	my ($self, $match_list) = @_;
	return scalar(@{$match_list->{match_conditions}});
}

sub syntax_match_list_as_string {
	my ($self, $match_list) = @_;
	my $conditions_string = join(', ', @{[ map { $self->syntax_condition_as_string($_) } @{$match_list->{match_conditions}} ]});
	if ((0 < scalar(@{$match_list->{look_ahead_conditons}}))) {
		my $look_ahead_string = join(', ', @{[ map { $self->syntax_condition_as_string($_) } @{$match_list->{look_ahead_conditons}} ]});
		if ((0 < length($conditions_string))) {
			$conditions_string = "$conditions_string, (look-ahead: $look_ahead_string)";
		} else {
			$conditions_string = "(look-ahead: $look_ahead_string)";
		}
	}
	$conditions_string = ($conditions_string =~ s/([\\'])/\\$1/gr);
	return $conditions_string;
}

sub syntax_condition_as_string {
	my ($self, $condition) = @_;
	if ($condition->{type} eq 'function_match') {
		return "$condition->{function}";
	} elsif ($condition->{type} eq 'variable_match') {
		return $self->get_variable($condition->{variable});
	} elsif ($condition->{type} eq 'regex_match') {
		return "$condition->{regex}";
	} elsif ($condition->{type} eq 'string_match') {
		return "$condition->{string}";
	} elsif ($condition->{type} eq 'token_type_match') {
		return "$condition->{value} token";
	} else {
		$self->confess_at_current_line("invalid syntax condition '$condition->{type}'");
	}
}

sub compile_syntax_action {
	my ($self, $match_list, $actions_list) = @_;
	my $code = [];
	my $previous_variables_scope = $self->{variables_scope};
	$self->{variables_scope} = { %{$previous_variables_scope} };
	if ($match_list) {
		$self->{tokens_scope_index} += 1;
		my $previous_tokens_variable = $self->get_variable('#tokens');
		my $new_tokens_variable = "tokens$self->{tokens_scope_index}";
		$self->{variables_scope}->{'#tokens'} = $new_tokens_variable;
		my $count = $self->get_syntax_match_list_tokens_eaten($match_list);
		push @{$code}, "List<Token> $new_tokens_variable = new List<Token>($previous_tokens_variable);";
		if (($count > 0)) {
			push @{$code}, "${new_tokens_variable}.AddRange(StepTokens($count));";
		}
	}
	foreach my $action (@{$actions_list}) {
		$self->{current_line} = $action->{line_number};
		if ($action->{type} eq 'push_statement') {
			my $expression = $self->compile_syntax_spawn_expression($action->{expression});
			if (($self->{current_context}->{type} eq 'list_context')) {
				push @{$code}, "context_value.Add($expression);";
			} else {
				$self->confess_at_current_line("use of push in $self->{current_context}{type}");
			}
		} elsif ($action->{type} eq 'assign_item_statement') {
			my $expression = $self->compile_syntax_spawn_expression($action->{expression});
			if ($self->exists_variable($action->{variable})) {
				my $variable = $self->get_variable($action->{variable});
				push @{$code}, "$variable = $expression;";
			} else {
				my $variable = $self->add_variable($action->{variable});
				push @{$code}, "Object $variable = $expression;";
			}
		} elsif ($action->{type} eq 'assign_field_statement') {
			my $key = $self->compile_syntax_spawn_expression($action->{key});
			my $expression = $self->compile_syntax_spawn_expression($action->{expression});
			my $variable = $self->get_variable($action->{variable});
			push @{$code}, "$variable\[$key] = $expression;";
		} elsif ($action->{type} eq 'assign_array_field_statement') {
			my $key = $self->compile_syntax_spawn_expression($action->{key});
			my $expression = $self->compile_syntax_spawn_expression($action->{expression});
			my $variable = $self->get_variable($action->{variable});
			push @{$code}, "$variable\[$key].Add($expression);";
		} elsif ($action->{type} eq 'assign_object_field_statement') {
			my $key = $self->compile_syntax_spawn_expression($action->{key});
			my $subkey = $self->compile_syntax_spawn_expression($action->{subkey});
			my $expression = $self->compile_syntax_spawn_expression($action->{expression});
			my $variable = $self->get_variable($action->{variable});
			push @{$code}, "$variable\[$key][$subkey] = $expression;";
		} elsif ($action->{type} eq 'return_statement') {
			push @{$code}, "return context_value;";
			if (not ($self->{context_default_case})) {
				$self->{context_default_case} = [ { type => ('die_statement'), expression => ({ type => ('string'), string => ("'unexpected token'") }) } ];
			}
		} elsif ($action->{type} eq 'return_expression_statement') {
			my $expression = $self->compile_syntax_spawn_expression($action->{expression});
			push @{$code}, "return (DynamicValue)($expression);";
			if (not ($self->{context_default_case})) {
				$self->{context_default_case} = [ { type => ('die_statement'), expression => ({ type => ('string'), string => ("'unexpected token'") }) } ];
			}
		} elsif ($action->{type} eq 'match_statement') {
			my $death_expression;
			if ($action->{death_expression}) {
				$death_expression = $self->compile_syntax_spawn_expression($action->{death_expression});
			} else {
				my $match_description = $self->syntax_match_list_as_string($action->{match_list});
				$death_expression = "\"expected $match_description\"";
			}
			my $match_expression = $self->compile_syntax_match_list($action->{match_list});
			push @{$code}, "if (!($match_expression)) {";
			push @{$code}, "\tConfessAtCurrentOffset($death_expression);";
			push @{$code}, "}";
			my $count = $self->get_syntax_match_list_tokens_eaten($action->{match_list});
			if (($count > 0)) {
				my $tokens_variable = $self->get_variable('#tokens');
				push @{$code}, "${tokens_variable}.AddRange(StepTokens($count));";
			}
		} elsif ($action->{type} eq 'if_statement') {
			my $condition_code = $self->compile_syntax_match_list($action->{match_list});
			my $action_code = $self->compile_syntax_action($action->{match_list}, $action->{block});
			push @{$code}, "if ($condition_code) {";
			push @{$code}, @{$action_code};
			my $branch = $action;
			while (exists($branch->{branch})) {
				$branch = $branch->{branch};
				if (($branch->{type} eq 'elsif_statement')) {
					my $condition_code = $self->compile_syntax_match_list($branch->{match_list});
					my $action_code = $self->compile_syntax_action($branch->{match_list}, $branch->{block});
					push @{$code}, "} else if ($condition_code) {";
					push @{$code}, @{$action_code};
				} else {
					my $action_code = $self->compile_syntax_action($branch->{match_list}, $branch->{block});
					push @{$code}, "} else {";
					push @{$code}, @{$action_code};
				}
			}
			push @{$code}, "}";
		} elsif ($action->{type} eq 'switch_statement') {
			my $first = 1;
			foreach my $case (@{$action->{switch_cases}}) {
				$self->{current_line} = $case->{line_number};
				if (($case->{type} eq 'match_case')) {
					my $condition_code = $self->compile_syntax_match_list($case->{match_list});
					my $action_code = $self->compile_syntax_action($case->{match_list}, $case->{block});
					if ($first) {
						push @{$code}, "if ($condition_code) {";
						push @{$code}, @{$action_code};
						$first = 0;
					} else {
						push @{$code}, "} else if ($condition_code) {";
						push @{$code}, @{$action_code};
					}
				} elsif (($case->{type} eq 'default_case')) {
					my $action_code = $self->compile_syntax_action(0, $case->{block});
					push @{$code}, "} else {";
					push @{$code}, @{$action_code};
				} else {
					$self->confess_at_current_line("invalid switch case type: $case->{type}");
				}
			}
			if (not ($first)) {
				push @{$code}, "}";
			}
		} elsif ($action->{type} eq 'while_statement') {
			my $condition_code = $self->compile_syntax_match_list($action->{match_list});
			my $action_code = $self->compile_syntax_action($action->{match_list}, $action->{block});
			push @{$code}, "while ($condition_code) {";
			push @{$code}, @{$action_code};
			push @{$code}, "}";
		} elsif ($action->{type} eq 'warn_statement') {
			my $expression = $self->compile_syntax_spawn_expression($action->{expression});
			push @{$code}, "Console.Error.WriteLine($expression);";
		} elsif ($action->{type} eq 'die_statement') {
			my $expression = $self->compile_syntax_spawn_expression($action->{expression});
			push @{$code}, "ConfessAtCurrentOffset($expression);";
		} else {
			die "undefined action '$action->{type}'";
		}
	}
	$self->{variables_scope} = $previous_variables_scope;
	if ($self->{match_list}) {
		$self->{tokens_scope_index} += -1;
	}
	return [ map { "\t$_" } @{$code} ];
}

sub compile_syntax_spawn_expression {
	my ($self, $expression) = @_;
	if ($expression->{type} eq 'access') {
		my $left = $self->compile_syntax_spawn_expression($expression->{left_expression});
		my $right = $self->compile_syntax_spawn_expression($expression->{right_expression});
		return "${left}[$right]";
	} elsif ($expression->{type} eq 'undef') {
		return 'null';
	} elsif ($expression->{type} eq 'get_token_line_number') {
		if (($expression->{token} =~ /\A\$(\d+)\Z/s)) {
			my $tokens_variable = $self->get_variable('#tokens');
			return "$tokens_variable\[$1].line_number";
		} else {
			$self->confess_at_current_line("invalid spawn expression token: '$expression->{token}'");
		}
	} elsif ($expression->{type} eq 'get_token_line_offset') {
		if (($expression->{token} =~ /\A\$(\d+)\Z/s)) {
			my $tokens_variable = $self->get_variable('#tokens');
			return "$tokens_variable\[$1].offset";
		} else {
			$self->confess_at_current_line("invalid spawn expression token: '$expression->{token}'");
		}
	} elsif ($expression->{type} eq 'get_token_text') {
		if (($expression->{token} =~ /\A\$(\d+)\Z/s)) {
			my $tokens_variable = $self->get_variable('#tokens');
			return "$tokens_variable\[$1].value";
		} else {
			$self->confess_at_current_line("invalid spawn expression token: '$expression->{token}'");
		}
	} elsif ($expression->{type} eq 'get_context') {
		return "context_value";
	} elsif ($expression->{type} eq 'pop_list') {
		$self->confess_at_current_line("pop is unimplemented in csharp");
	} elsif ($expression->{type} eq 'call_context') {
		my $context = $self->get_function_by_name($expression->{context});
		if (exists($expression->{argument})) {
			my $expression_code = $self->compile_syntax_spawn_expression($expression->{argument});
			return "$context($expression_code)";
		} else {
			return "$context()";
		}
	} elsif ($expression->{type} eq 'call_function') {
		my $function = $self->get_function_by_name($expression->{function});
		if (exists($expression->{argument})) {
			my $expression_code = $self->compile_syntax_spawn_expression($expression->{argument});
			return "$function($expression_code)";
		} else {
			return "$function()";
		}
	} elsif ($expression->{type} eq 'call_variable') {
		my $variable = $self->get_variable($expression->{variable});
		my $expression_code = $self->compile_syntax_spawn_expression($expression->{argument});
		return "$variable($expression_code)";
	} elsif ($expression->{type} eq 'variable_value') {
		my $variable = $self->get_variable($expression->{variable});
		return "$variable";
	} elsif ($expression->{type} eq 'call_substitution') {
		$self->confess_at_current_line("call_substitution is unimplemented in csharp");
	} elsif ($expression->{type} eq 'string') {
		if (($expression->{string} =~ /\A'(.*)'\Z/s)) {
			return "\"$1\"";
		} else {
			$self->confess_at_current_line("invalid string expression value: $expression->{string}");
		}
	} elsif ($expression->{type} eq 'bareword_string') {
		return "\"$expression->{value}\"";
	} elsif ($expression->{type} eq 'bareword') {
		return "\"$expression->{value}\"";
	} elsif ($expression->{type} eq 'empty_list') {
		return 'new DynamicValue(new List<DynamicValue>{})';
	} elsif ($expression->{type} eq 'empty_hash') {
		return 'new DynamicValue(new Dictionary<string, DynamicValue>{})';
	} elsif ($expression->{type} eq 'list_constructor') {
		my $code = "new DynamicValue(new List<DynamicValue>{ ";
		foreach my $field (@{$expression->{arguments}}) {
			my $field_expression_code = $self->compile_syntax_spawn_expression($field);
			$code .= "$field_expression_code, ";
		}
		$code .= "})";
		return $code;
	} elsif ($expression->{type} eq 'hash_constructor') {
		my $code = "new DynamicValue(new Dictionary<string, DynamicValue>{ ";
		my $arguments = $expression->{arguments};
		my $items = [ @{$arguments} ];
		while ((0 < scalar(@{$items}))) {
			my $field = shift(@{$items});
			my $value = shift(@{$items});
			my $field_expression_code = $self->compile_syntax_spawn_expression($field);
			my $value_expression_code = $self->compile_syntax_spawn_expression($value);
			$code .= "{$field_expression_code, $value_expression_code}, ";
		}
		$code .= "})";
		return $code;
	} else {
		$self->confess_at_current_line("invalid spawn expression: '$expression->{type}'");
	}
}

sub main {
	my ($self) = @_;

	my ($files_list) = @_;

	use Data::Dumper;
	use Sugar::IO::File;
	use Sugar::Lang::SugarGrammarParser;
	# use Sugar::Lang::SugarGrammarCompiler;

	my $parser = Sugar::Lang::SugarGrammarParser->new;
	foreach my $file (@$files_list) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		my $tree = $parser->parse;
		# say Dumper $tree;

		my $compiler = Sugar::Lang::SugarGrammarCSharpCompiler->new({syntax_definition_intermediate => $tree});
		$compiler->compile_syntax_intermediate;
		say $compiler->to_package;
	}

}

caller or main(\@ARGV);


