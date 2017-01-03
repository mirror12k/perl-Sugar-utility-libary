package Sugar::Lang::SyntaxIntermediateCompiler;
use strict;
use warnings;

use feature 'say';

use Carp;



sub new {
	my ($class, %opts) = @_;
	my $self = bless {}, $class;

	$self->{syntax_definition_intermediate} = $opts{syntax_definition_intermediate}
			// croak "syntax_definition_intermediate argument required for Sugar::Lang::SyntaxIntermediateCompiler";

	$self->{variables} = $self->{syntax_definition_intermediate}{variables};
	$self->{tokens} = [];
	$self->{ignored_tokens} = $self->{syntax_definition_intermediate}{ignored_tokens};
	$self->{contexts} = $self->{syntax_definition_intermediate}{contexts};
	$self->{object_contexts} = $self->{syntax_definition_intermediate}{object_contexts};
	$self->{code_definitions} = {};
	$self->{package_identifier} = $self->{syntax_definition_intermediate}{package_identifier} // 'PACKAGE_NAME';
	$self->compile_syntax_intermediate;

	return $self
}

sub to_package {
	my ($self) = @_;

	my $code = '';

	$code .= "package $self->{package_identifier};
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use Sugar::IO::File;
use Sugar::Lang::SyntaxIntermediateCompiler;



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
		$code .= "\t$context_type => \\&context_$context_type,\n";
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
		# say Dumper $tree;

		my $compiler = Sugar::Lang::SyntaxIntermediateCompiler->new(syntax_definition_intermediate => $tree);
		say $compiler->to_package;
	}
}

caller or main(@ARGV);

';

	foreach my $context_type (sort keys %{$self->{code_definitions}}) {
		$code .= $self->{code_definitions}{$context_type} =~ s/\A(\s*)sub {/$1sub context_$context_type {/r;
	}

	return $code
}

sub get_variable {
	my ($self, $identifier) = @_;
	confess "undefined variable requested: '$identifier'" unless exists $self->{variables}{$identifier};
	return $self->{variables}{$identifier}
}

sub get_function_by_name {
	my ($self, $value, $modifier) = @_;
	if ($value =~ /\A\!(\w++)\Z/) {
		my $context_type = $1;
		if (defined $modifier and $modifier eq 'OBJECT_CONTEXT') {
			confess "undefined object context requested: '$context_type'" unless defined $self->{object_contexts}{$context_type};
			return "context_$context_type"
		} else {
			confess "undefined context requested: '$context_type'" unless defined $self->{contexts}{$context_type};
			return "context_$context_type"
		}

	} elsif ($value =~ /\A\&(\w++)\Z/) {
		return "$1"

	} else {
		confess "unknown context type requested: '$value'";
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
	foreach my $context_type (keys %{$self->{syntax_definition_intermediate}{contexts}}) {
		my $context_definition = $self->{syntax_definition_intermediate}{contexts}{$context_type};
		$self->{code_definitions}{$context_type} = $self->compile_syntax_context($context_type, $context_definition);
	}
	foreach my $context_type (keys %{$self->{syntax_definition_intermediate}{object_contexts}}) {
		my $context_definition = $self->{syntax_definition_intermediate}{object_contexts}{$context_type};
		$self->{code_definitions}{$context_type} = $self->compile_syntax_context($context_type, $context_definition, 'object_context');
	}
}

sub compile_syntax_token_value {
	my ($self, $value, $modifier) = @_;
	if ($value =~ m#\A/([^\\/]|\\.)*+/[msixpodualn]*\Z#s) {
		return "qr$value"
	} elsif ($value =~ /\A\$(\w++)\Z/) {
		return $self->compile_syntax_token_value($self->get_variable($1))
	} else {
		confess "invalid syntax token value: $value";
	}
}

sub compile_syntax_context {
	my ($self, $context_name, $context, $modifier) = @_;

	my $code = '
sub {
';
	my @args_list = ('$self');
	push @args_list, '$context_object' if defined $modifier and $modifier eq 'object_context';
	my $args_list_string = join ', ', @args_list;
	$code .= "
	my ($args_list_string) = \@_;
";
	$code .= '
	my @spawned_value;
';
	# $code .= "\t\tsay 'in context $context_name';\n"; # DEBUG INLINE TREE BUILDER
	$code .= '
	while ($self->more_tokens) {
';
	my @items = @$context;
	my $first_item = 1;
	$self->{context_default_case} = undef;
	while (@items) {
		my $condition = shift @items;
		unless (defined $condition) {
			$self->{context_default_case} = shift @items;
			next
		}
		my $condition_code = $self->compile_syntax_condition($condition);
		my $action = shift @items;
		my $action_code = $self->compile_syntax_action($condition, $action, $modifier);

		my $debug_code = '';
		# $debug_code = "\n\t\t\tsay 'in case " . (ref $condition eq 'ARRAY' ? join ', ', @$condition : $condition) =~ s/'/\\'/gr . "';"; # DEBUG INLINE TREE BUILDER


		$code .= "\t\t" if $first_item;
		$code .= "if ($condition_code) {$debug_code$action_code\t\t} els";

		$first_item = 0;
	}

	$self->{context_default_case} //= [ 'return' ];
	my $action_code = $self->compile_syntax_action(undef, $self->{context_default_case}, $modifier);
	unless ($first_item) {
		$code .= "e {$action_code\t\t}\n";
	} else {
		$code .= "$action_code\n";
	}

	$code .= "
	}
}
";
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
		return join ' and ', @conditions
	# } elsif (ref $condition eq 'Regexp') {
	# 	$condition =~ s#/#\\/#g;
	# 	return "\$self->is_token_val('*' => qr/$condition/, $offset)"
	} elsif ($condition =~ m#\A\$(\w++)\Z#s) {
		return $self->compile_syntax_condition($self->get_variable($1), $offset)
	} elsif ($condition =~ m#\A/(.*)/([msixpodualn]*)\Z#s) {
		return "\$self->{tokens}[\$self->{tokens_index} + $offset][1] =~ /\\A$1\\Z/$2"
		# return "\$self->is_token_val('*' => qr/\\A$1\\Z/$2, $offset)"
	} elsif ($condition =~ /\A'.*'\Z/s) {
		return "\$self->{tokens}[\$self->{tokens_index} + $offset][1] eq $condition"
		# return "\$self->is_token_val('*' => $condition, $offset)"
	} else {
		confess "invalid syntax condition '$condition'";
	}
}

sub compile_syntax_action {
	my ($self, $condition, $actions_list, $modifier) = @_;

	my @code;

	if (defined $condition and ref $condition eq 'ARRAY') {
		my $count = @$condition;
		push @code, "my \@tokens = \$self->step_tokens($count);";
		# push @code, "push \@tokens, \$self->next_token->[1];" foreach 0 .. $#$condition;
	} elsif (defined $condition) {
		push @code, "my \@tokens = (\$self->next_token->[1]);";
		# push @code, "push \@tokens, \$self->next_token->[1];";
	} else {
		push @code, "my \@tokens;";
	}
	
	my @actions = @$actions_list;
	while (@actions) {
		my $action = shift @actions;

		if ($action eq 'spawn') {
			my $expression = shift @actions;
			# if (defined $expression and $expression =~ /\A!\w++\Z/ and defined $actions[0] and $actions[0] eq '->') {
			# 	shift @actions;
			# 	my $object_expression = shift @actions;
			# 	push @code, "push \@spawned_value, " . $self->compile_syntax_spawn_expression($expression, 'OBJECT_CONTEXT', $object_expression) . ";";
			# } else {
			push @code, "push \@spawned_value, " . $self->compile_syntax_spawn_expression($expression) . ";";
			# }
		} elsif ($action eq 'respawn') {
			my $expression = shift @actions;
			# if (defined $expression and $expression =~ /\A!\w++\Z/ and defined $actions[0] and $actions[0] eq '->') {
			# 	shift @actions;
			# 	my $object_expression = shift @actions;
			# 	push @code, "\$context_object = " . $self->compile_syntax_spawn_expression($expression, 'OBJECT_CONTEXT', $object_expression) . ";";
			# } else {
			push @code, "\$context_object = " . $self->compile_syntax_spawn_expression($expression) . ";";
			# }
		} elsif ($action eq 'assign') {
			my @assign_items = @{shift @actions};
			while (@assign_items) {
				my $field = shift @assign_items;
				my $value = shift @assign_items;
				if (ref $value eq 'HASH') {
					my $key = shift @assign_items;
					$key = $self->compile_syntax_spawn_expression($key, 'SCALAR');
					$value = shift @assign_items;
					$field = $self->compile_syntax_spawn_expression($field, 'SCALAR');
					push @code, "\$context_object->{$field}{$key} = " . $self->compile_syntax_spawn_expression($value, 'SCALAR') . ";";
				} elsif (ref $value eq 'ARRAY' and @$value == 0) {
					$value = shift @assign_items;
					$field = $self->compile_syntax_spawn_expression($field, 'SCALAR');
					push @code, "push \@{\$context_object->{$field}}, " . $self->compile_syntax_spawn_expression($value) . ";";
				} else {
					$field = $self->compile_syntax_spawn_expression($field, 'SCALAR');
					push @code, "\$context_object->{$field} = " . $self->compile_syntax_spawn_expression($value, 'SCALAR') . ";";
				}
			}
		} elsif ($action eq 'match') {
			my $match_condition = shift @actions;
			push @code, "\$self->confess_at_current_offset('expected "
				. (ref $match_condition eq 'ARRAY' ? join ', ', @$match_condition : $match_condition) =~ s/'/\\'/gr . "')";
			push @code, "\tunless " . $self->compile_syntax_condition($match_condition) . ";";

			if (defined $match_condition and ref $match_condition eq 'ARRAY') {
				my $count = @$match_condition;
				push @code, "\@tokens = (\@tokens, \$self->step_tokens($count));";
			} elsif (defined $match_condition) {
				push @code, "\@tokens = (\@tokens, \$self->next_token->[1]);";
			} else {
			}

		} elsif ($action eq 'return') {
			if (defined $modifier and $modifier eq 'object_context') {
				push @code, "return \$context_object;";
			} else {
				push @code, "return \@spawned_value;";
			}
			$self->{context_default_case} = [ die => "'unexpected token'" ] unless defined $self->{context_default_case};
		} elsif ($action eq 'die') {
			push @code, "\$self->confess_at_current_offset(" . $self->compile_syntax_spawn_expression(shift @actions) . ");";
		} elsif ($action eq 'warn') {
			push @code, "warn " . $self->compile_syntax_spawn_expression(shift @actions) . ";";
		} else {
			die "undefined action '$action'";
		}
	}



	return join ("\n\t\t\t", '', @code) . "\n";
}

sub compile_syntax_spawn_expression {
	my ($self, $expression, $modifier, $arg) = @_;
	if (not defined $expression) {
		return 'undef'
	} elsif (ref $expression eq 'HASH') {
		my @keys = keys %$expression;
		if (@keys) {
			my ($call_expression) = @keys;
			my $object_expression = $expression->{$call_expression};
			return $self->compile_syntax_spawn_expression($call_expression, 'OBJECT_CONTEXT', $object_expression)
		} else {
			return '{}'
		}
	} elsif (ref $expression eq 'ARRAY' and @$expression == 0) {
		return '[]'
	} elsif (ref $expression eq 'ARRAY' and @$expression == 1) {
		return "[ " . $self->compile_syntax_spawn_expression($expression->[0]) . " ]"
	} elsif (ref $expression eq 'ARRAY') {
		my $code = "{ ";
		my @items = @$expression;
		while (@items) {
			my $field = shift @items;
			my $value = shift @items;
			$code .= $self->compile_syntax_spawn_expression($field, 'SCALAR') . " => " . $self->compile_syntax_spawn_expression($value, 'SCALAR') . ", ";
		}
		$code .= "}";
		return $code
	} elsif ($expression =~ /\A[!\&][a-zA-Z_][a-zA-Z_0-9]*\Z/) {
		my $context_function = $self->get_function_by_name($expression, $modifier);
		if (defined $modifier and $modifier eq 'SCALAR') {
			return "(\$self->$context_function)[0]";
		} elsif (defined $modifier and $modifier eq 'OBJECT_CONTEXT') {
			return "(\$self->$context_function(" . $self->compile_syntax_spawn_expression($arg) . "))[0]";
		} else {
			return "\$self->$context_function()";
		}
	} elsif ($expression eq '$_') {
		return "\$context_object";
	} elsif ($expression =~ /\A\$(\d+)\Z/) {
		return "\$tokens[$1][1]";
	} elsif ($expression =~ /\A'(.*)'\Z/s) {
		my $value = $1;
		return "'$value'";
	} else {
		confess "invalid spawn expression: '$expression'";
	}
}

1;
