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
	$self->{code_definitions} = {};
	$self->compile_syntax_intermediate;

	return $self
}

sub to_package {
	my ($self) = @_;

	my $code = '';

	$code .= 'package PACKAGE_NAME;
use parent "Sugar::Lang::BaseSyntaxParser";
use strict;
use warnings;

use feature "say";

use Data::Dumper;

use Sugar::IO::File;
use Sugar::Lang::SyntaxIntermediateCompiler;



';

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
	my $parser = PACKAGE_NAME->new;
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
	my ($self, $context_name, $context) = @_;

	my $code = '
	sub {
		my ($self) = @_;
';
	# $code .= "\t\tsay 'in context $context_name';\n"; # DEBUG INLINE TREE BUILDER

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
		my $action_code = $self->compile_syntax_action($condition, $action);

		my $debug_code = '';
		# $debug_code = "\n\t\t\tsay 'in case " . (ref $condition eq 'ARRAY' ? join ', ', @$condition : $condition) =~ s/'/\\'/gr . "';"; # DEBUG INLINE TREE BUILDER


		$code .= "\t\t" if $first_item;
		$code .= "if ($condition_code) {$debug_code$action_code\t\t} els";

		$first_item = 0;
	}

	$self->{context_default_case} //= [ 'exit_context' ];
	my $action_code = $self->compile_syntax_action(undef, $self->{context_default_case});
	unless ($first_item) {
		$code .= "e {$action_code\t\t}\n";
	} else {
		$code .= "$action_code\n";
	}

	$code .= "
		return;
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
	} elsif (ref $condition eq 'Regexp') {
		$condition =~ s#/#\\/#g;
		return "\$self->is_token_val('*' => qr/$condition/, $offset)"
	} elsif ($condition =~ m#\A\$(\w++)\Z#s) {
		my $value = $self->get_variable($1);
		return $self->compile_syntax_condition($value, $offset)
	} elsif ($condition =~ m#\A/(.*)/([msixpodualn]*)\Z#s) {
		return "\$self->is_token_val('*' => qr/\\A$1\\Z/$2, $offset)"
	} elsif ($condition =~ /\A'.*'\Z/s) {
		return "\$self->is_token_val('*' => $condition, $offset)"
	} else {
		confess "invalid syntax condition '$condition'";
	}
}

sub compile_syntax_action {
	my ($self, $condition, $actions_list) = @_;

	my @code;
	push @code, "my \@tokens;";

	if (defined $condition and ref $condition eq 'ARRAY') {
		push @code, "push \@tokens, \$self->next_token->[1];" foreach 0 .. $#$condition;
	} elsif (defined $condition) {
		push @code, "push \@tokens, \$self->next_token->[1];";
	}
	
	my @actions = @$actions_list;
	while (@actions) {
		my $action = shift @actions;

		if ($action eq 'spawn') {
			push @code, "push \@{\$self->{current_context}{children}}, " . $self->compile_syntax_spawn_expression(shift @actions) . ";";
		# } elsif ($action eq 'spawn_into_context') {
		# 	push @code, "push \@{\$self->{current_context}{children}}, \$self->into_context("
		# 			. $self->compile_syntax_spawn_expression(shift @actions) . ");";
		} elsif ($action eq 'assign') {
			my @assign_items = @{shift @actions};
			while (@assign_items) {
				my $field = shift @assign_items;
				my $value = shift @assign_items;
				if (ref $value eq 'HASH') {
					my $key = shift @assign_items;
					$key = $self->compile_syntax_spawn_sub_expression($key);
					$value = shift @assign_items;
					$field = $self->compile_syntax_spawn_sub_expression($field);
					push @code, "\$self->{current_context}{$field}{$key} = " . $self->compile_syntax_spawn_expression($value) . ";";
				} elsif (ref $value eq 'ARRAY' and @$value == 0) {
					$value = shift @assign_items;
					$field = $self->compile_syntax_spawn_sub_expression($field);
					push @code, "push \@{\$self->{current_context}{$field}}, " . $self->compile_syntax_spawn_expression($value) . ";";
				} else {
					$field = $self->compile_syntax_spawn_sub_expression($field);
					push @code, "\$self->{current_context}{$field} = " . $self->compile_syntax_spawn_expression($value) . ";";
				}
			}
		}

		if ($action eq 'exit_context') {
			push @code, "\$self->exit_context;";
			$self->{context_default_case} = [ die => 'unexpected token' ] unless defined $self->{context_default_case};
		} elsif ($action eq 'enter_context') {
			my $context_type = shift (@actions) =~ s/(['\\])/\\$1/gr;
			push @code, "\$self->enter_context(\$self->get_context('$context_type'));";
		} elsif ($action eq 'switch_context') {
			my $context_type = shift (@actions) =~ s/(['\\])/\\$1/gr;
			push @code, "\$self->switch_context(\$self->get_context('$context_type'));";
		} elsif ($action eq 'nest_context') {
			my $context_type = shift (@actions) =~ s/(['\\])/\\$1/gr;
			push @code, "\$self->nest_context(\$self->get_context('$context_type'));";
		}

		if ($action eq 'die') {
			# my $msg = shift (@actions) =~ s/(['\\])/\\$1/gr;
			push @code, "\$self->confess_at_current_offset(" . $self->compile_syntax_spawn_sub_expression(shift @actions) . ");";
			# push @code, "\$self->confess_at_current_offset('$msg');";
		}

		if ($action eq 'warn') {
			# my $msg = shift (@actions) =~ s/(['\\])/\\$1/gr;
			push @code, "warn " . $self->compile_syntax_spawn_sub_expression(shift @actions) . ";";
		}
	}



	return join ("\n\t\t\t", '', @code) . "\n";
}

sub compile_syntax_spawn_expression {
	my ($self, $expression) = @_;
	if (not defined $expression) {
		return 'undef'
	} elsif (ref $expression eq 'HASH') {
		return '{}'
	} elsif (ref $expression eq 'ARRAY' and @$expression == 0) {
		return '[]'
	} elsif (ref $expression eq 'ARRAY' and @$expression == 1) {
		my $context_type = $expression->[0] =~ s/'/\\'/gr;
		return "\$self->extract_context_result(\$self->get_context('$context_type'), 'ARRAY')"
	} elsif (ref $expression eq 'ARRAY') {
		my $code = "{ ";
		my @items = @$expression;
		while (@items) {
			my $field = quotemeta shift @items;
			my $value = shift @items;
			$code .= "'$field' => " . $self->compile_syntax_spawn_sub_expression($value) . ", ";
		}
		$code .= "}";
		return $code
	} else {
		return $self->compile_syntax_spawn_sub_expression($expression)
	}
}

sub compile_syntax_spawn_sub_expression {
	my ($self, $expression) = @_;

	if (not defined $expression) {
		return "undef";
	} elsif ($expression =~ /\A\![a-zA-Z_][a-zA-Z_0-9]*\Z/) {
		return "\$self->extract_context_result(\$self->get_context('$expression'))";
	} elsif ($expression =~ /\A\$previous_spawn\Z/) {
		return "pop \@{\$self->{current_context}{children}}";
	} elsif ($expression =~ /\A\$(\d+)\Z/) {
		return "\$tokens[$1]";
	} elsif ($expression =~ /\A'(.*)'\Z/s) {
		my $value = $1;
		return "'$value'";
	} else {
		confess "invalid spawn expression: '$expression'";
	}
}

1;
