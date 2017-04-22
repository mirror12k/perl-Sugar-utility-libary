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
	$self->{item_contexts} = $self->{syntax_definition_intermediate}{item_contexts};
	$self->{list_contexts} = $self->{syntax_definition_intermediate}{list_contexts};
	$self->{object_contexts} = $self->{syntax_definition_intermediate}{object_contexts};
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
		$code .= $self->{code_definitions}{$context_type} =~ s/\A(\s*)sub \{/$1sub context_$context_type {/r;
	}

	return $code
}

sub get_variable {
	my ($self, $identifier) = @_;
	confess "undefined variable requested: '$identifier'" unless exists $self->{variables}{$identifier};
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
			confess "undefined context requested: '$context_type'";
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
		my $action_code = $self->compile_syntax_action($context_type, $condition, $action);

		my $debug_code = '';
		# $debug_code = "\n\t\t\tsay 'in case " . (ref $condition eq 'ARRAY' ? join ', ', @$condition : $condition) =~ s/'/\\'/gr . "';"; # DEBUG INLINE TREE BUILDER


		$code .= "\t\t" if $first_item;
		$code .= "if ($condition_code) {$debug_code$action_code\t\t} els";

		$first_item = 0;
	}

	$self->{context_default_case} //= [ 'return' ];
	my $action_code = $self->compile_syntax_action($context_type, undef, $self->{context_default_case});
	unless ($first_item) {
		$code .= "e {$action_code\t\t}\n";
	} else {
		$code .= "$action_code\n";
	}

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
		return join ' and ', @conditions
	} elsif ($condition =~ m#\A\$(\w++)\Z#s) {
		return $self->compile_syntax_condition($self->get_variable($1), $offset)
	} elsif ($condition =~ m#\A/(.*)/([msixpodualn]*)\Z#s) {
		return "\$self->{tokens}[\$self->{tokens_index} + $offset][1] =~ /\\A$1\\Z/$2"
	} elsif ($condition =~ /\A'.*'\Z/s) {
		return "\$self->{tokens}[\$self->{tokens_index} + $offset][1] eq $condition"
	} else {
		confess "invalid syntax condition '$condition'";
	}
}

sub compile_syntax_action {
	my ($self, $context_type, $condition, $actions_list) = @_;

	my @code;

	if (defined $condition and ref $condition eq 'ARRAY') {
		my $count = @$condition;
		push @code, "my \@tokens = \$self->step_tokens($count);";
	} elsif (defined $condition) {
		push @code, "my \@tokens = (\$self->next_token->[1]);";
	} else {
		push @code, "my \@tokens;";
	}
	
	my @actions = @$actions_list;
	while (@actions) {
		my $action = shift @actions;

		if ($action eq 'push') {
			my $expression = shift @actions;
			if ($context_type eq 'list_context') {
				push @code, "push \@\$context_list, " . $self->compile_syntax_spawn_expression($context_type, $expression) . ";";
			} else {
				confess "use of push in $context_type: '$expression'";
			}
		} elsif ($action eq 'assign_item') {
			my $value = shift @actions;
			if ($context_type eq 'object_context') {
				push @code, "\$context_object = " . $self->compile_syntax_spawn_expression($context_type, $value) . ";";
			} elsif ($context_type eq 'list_context') {
				push @code, "\$context_list = " . $self->compile_syntax_spawn_expression($context_type, $value) . ";";
			} else {
				push @code, "\$context_value = " . $self->compile_syntax_spawn_expression($context_type, $value) . ";";
			}
			
		} elsif ($action eq 'assign_field') {
			my $field = shift @actions;
			my $value = shift @actions;
			$field = $self->compile_syntax_spawn_expression($context_type, $field);
			push @code, "\$context_object->{$field} = " . $self->compile_syntax_spawn_expression($context_type, $value) . ";";
			
		} elsif ($action eq 'assign_array_field') {
			my $field = shift @actions;
			my $value = shift @actions;
			$field = $self->compile_syntax_spawn_expression($context_type, $field);
			push @code, "push \@{\$context_object->{$field}}, " . $self->compile_syntax_spawn_expression($context_type, $value) . ";";
			
		} elsif ($action eq 'assign_object_field') {
			my $field = shift @actions;
			my $key = shift @actions;
			my $value = shift @actions;
			$field = $self->compile_syntax_spawn_expression($context_type, $field);
			$key = $self->compile_syntax_spawn_expression($context_type, $key);
			push @code, "\$context_object->{$field}{$key} = " . $self->compile_syntax_spawn_expression($context_type, $value) . ";";

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
			if ($context_type eq 'object_context') {
				push @code, "return \$context_object;";
			} elsif ($context_type eq 'list_context') {
				push @code, "return \$context_list;";
			} else {
				push @code, "return \$context_value;";
			}
			$self->{context_default_case} = [ die => "'unexpected token'" ] unless defined $self->{context_default_case};
		} elsif ($action eq 'die') {
			push @code, "\$self->confess_at_current_offset(" . $self->compile_syntax_spawn_expression($context_type, shift @actions) . ");";
		} elsif ($action eq 'warn') {
			push @code, "warn " . $self->compile_syntax_spawn_expression($context_type, shift @actions) . ";";
		} else {
			die "undefined action '$action'";
		}
	}



	return join ("\n\t\t\t", '', @code) . "\n";
}

sub compile_syntax_spawn_expression {
	my ($self, $context_type, $expression) = @_;
	if (not defined $expression) {
		return 'undef'

	} elsif (ref $expression eq 'HASH') {
		my @keys = keys %$expression;
		if (@keys) {
			my ($call_expression) = @keys;
			my $object_expression = $expression->{$call_expression};
			# warn "got call_expression: $call_expression";
			my $context_function = $self->get_function_by_name($call_expression);
			return "(\$self->$context_function(" . $self->compile_syntax_spawn_expression($context_type, $object_expression) . "))[0]";
		} else {
			return '{}'
		}

	} elsif (ref $expression eq 'ARRAY' and @$expression == 0) {
		return '[]'

	} elsif (ref $expression eq 'ARRAY') {
		my $code = "{ ";
		my @items = @$expression;
		while (@items) {
			my $field = shift @items;
			my $value = shift @items;
			$code .= $self->compile_syntax_spawn_expression($context_type, $field) . " => " . $self->compile_syntax_spawn_expression($context_type, $value) . ", ";
		}
		$code .= "}";
		return $code

	} elsif ($expression =~ /\A[!\&][a-zA-Z_][a-zA-Z_0-9]*\Z/) {
		my $context_function = $self->get_function_by_name($expression);
		return "\$self->$context_function()";

	} elsif ($expression eq '$_') {
		if ($context_type eq 'object_context') {
			return "\$context_object"
		} elsif ($context_type eq 'list_context') {
			return "\$context_list"
		} else {
			return "\$context_value"
		}

	} elsif ($expression =~ /\A\$(\d+)\Z/) {
		return "\$tokens[$1][1]";

	} elsif ($expression =~ /\Apop\Z/) {
		if ($context_type eq 'list_context') {
			return "pop \@\$context_list";
		} else {
			confess "use of pop in $context_type";
		}

	} elsif ($expression =~ /\A'(.*)'\Z/s) {
		my $value = $1;
		return "'$value'";

	} else {
		confess "invalid spawn expression: '$expression'";
	}
}

1;
