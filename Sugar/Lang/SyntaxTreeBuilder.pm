package Sugar::Lang::SyntaxTreeBuilder;
use parent 'Sugar::Lang::Tokenizer';
use strict;
use warnings;

use feature 'say';

use Carp;
use Data::Dumper;



sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);

	$self->{syntax_definition} = $opts{syntax_definition} // croak "syntax_definition argument required for Sugar::Lang::SyntaxTreeBuilder";
	$self->{syntax_definition} = { map { $_ => $self->compile_syntax_context($_ => $self->{syntax_definition}{$_}) } keys %{$self->{syntax_definition}} };

	return $self
}

sub parse {
	my ($self) = @_;
	$self->SUPER::parse;

	$self->{current_context} = { type => 'context', context_type => 'root_context' };
	$self->{syntax_tree} = $self->{current_context};
	$self->{context_stack} = [];
	$self->{current_syntax_context} = $self->{syntax_definition}{$self->{current_context}{context_type}};

	while ($self->more_tokens) {
		$self->{current_syntax_context}->($self);
	}

	return $self->{syntax_tree}
}

sub enter_context {
	my ($self, $context_type) = @_;

	my $new_context = { type => 'context', context_type => $context_type };
	# push @{$self->{current_context}{children}}, $new_context;
	push @{$self->{context_stack}}, $self->{current_context};
	$self->{current_context} = $new_context;
	$self->{current_syntax_context} = $self->{syntax_definition}{$self->{current_context}{context_type}};
}

sub exit_context {
	my ($self) = @_;
	confess 'attempt to exit root context' if $self->{current_context}{context_type} eq 'root_context';

	$self->{current_context} = pop @{$self->{context_stack}};
	$self->{current_syntax_context} = $self->{syntax_definition}{$self->{current_context}{context_type}};
}

sub switch_context {
	my ($self, $context_type) = @_;
	confess 'attempt to switch context on root context' if $self->{current_context}{context_type} eq 'root_context';

	$self->{current_context}{context_type} = $context_type;
	$self->{current_syntax_context} = $self->{syntax_definition}{$self->{current_context}{context_type}};
}

sub extract_context_result {
	my ($self, $context_type, $modifier) = @_;

	my $previous_context = $self->{current_context};
	$self->enter_context($context_type);
	my $saved_context = $self->{current_context};

	while ($self->{current_context} != $previous_context) {
		# say "debug", Dumper $self->{current_context};
		$self->{current_syntax_context}->($self);
	}
	my $result;
	if (defined $modifier and $modifier eq 'ARRAY') {
		$result = [ @{$saved_context->{children}} ];
	} else {
		($result) = @{$saved_context->{children}};
	}
	# say 'got result: ', Dumper $result;
	return $result
}

sub extract_context {
	my ($self, $context_type) = @_;

	my $previous_context = $self->{current_context};
	$self->enter_context($context_type);
	my $saved_context = $self->{current_context};

	while ($self->{current_context} != $previous_context) {
		$self->{current_syntax_context}->($self);
	}
	$saved_context->{type} = $saved_context->{context_type};
	delete $saved_context->{context_type};
	return $saved_context
}

sub into_context {
	my ($self, $context_object) = @_;
	# my $store_type = $context_object->{type};
	# $context_object->{type} = 'context';
	my $previous_context = $self->{current_context};
	push @{$self->{context_stack}}, $self->{current_context};
	$self->{current_context} = $context_object;
	$self->{current_syntax_context} = $self->{syntax_definition}{$self->{current_context}{context_type}};

	while ($self->{current_context} != $previous_context) {
		$self->{current_syntax_context}->($self);
	}

	return $context_object
}

sub compile_syntax_context {
	my ($self, $context_name, $context) = @_;

	my $code = '
	sub {
		my ($self) = @_;
		say "in ' .$context_name. ' context";
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
		my $action_code = $self->compile_syntax_action($condition, $action);

		$code .= "\t\t" if $first_item;
		$code .= "if ($condition_code) { say 'in case $condition';$action_code\t\t} els";

		$first_item = 0;
	}

	$self->{context_default_case} //= { exit_context => 1 };
	my $action_code = $self->compile_syntax_default_action($self->{context_default_case});
	$code .= "e {$action_code\t\t}\n";

	$code .= "
		return;
	}
";
	say "compiled code: ", $code;
	return eval $code
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
		return "\$self->is_token_val('*' => qr/$condition/, $offset)"
	} else {
		return "\$self->is_token_val('*' => '$condition', $offset)"
	}
}

sub compile_syntax_action {
	my ($self, $condition, $action) = @_;
	my @actions;

	push @actions, "my \@tokens;";

	if (ref $condition eq 'ARRAY') {
		push @actions, "push \@tokens, \$self->next_token->[1];" foreach 0 .. $#$condition;
	} else {
		push @actions, "push \@tokens, \$self->next_token->[1];";
	}

	if (defined $action->{spawn}) {
		push @actions, "push \@{\$self->{current_context}{children}}, " . $self->compile_syntax_spawn_expression($action->{spawn}) . ";";
	} elsif (defined $action->{spawn_into_context}) {
		push @actions, "push \@{\$self->{current_context}{children}}, \$self->into_context("
				. $self->compile_syntax_spawn_expression($action->{spawn_into_context}) . ");";
	} elsif (defined $action->{assign}) {
		my @assign_items = @{$action->{assign}};
		while (@assign_items) {
			my $field = shift @assign_items;
			my $value = shift @assign_items;
			if (ref $field eq 'ARRAY') {
				$field = quotemeta $field->[0];
				push @actions, "push \@{\$self->{current_context}{'$field'}}, " . $self->compile_syntax_spawn_expression($value) . ";";
			} else {
				$field = quotemeta $field;
				push @actions, "\$self->{current_context}{'$field'} = " . $self->compile_syntax_spawn_expression($value) . ";";
			}
		}
	} elsif (defined $action->{extract}) {
		my @extract_items = @{$action->{extract}};
		while (@extract_items) {
			my $field = quotemeta shift @extract_items;
			my $context_type = shift @extract_items;
			if (ref $context_type eq 'ARRAY') {
				$context_type = quotemeta $context_type->[0];
				push @actions, "\$self->{current_context}{'$field'} = \$self->extract_context_result('$context_type', 'ARRAY');";
			} else {
				$context_type = quotemeta $context_type;
				push @actions, "\$self->{current_context}{'$field'} = \$self->extract_context_result('$context_type');";
			}
		}
	} elsif (defined $action->{extract_context}) {
		my $context_type = quotemeta $action->{extract_context};
		push @actions, "push \@{\$self->{current_context}{children}}, \$self->extract_context('$context_type');";
	}

	if (defined $action->{assign_last}) {
		my @assign_items = @{$action->{assign_last}};
		while (@assign_items) {
			my $field = shift @assign_items;
			my $value = shift @assign_items;
			if (ref $field eq 'ARRAY') {
				$field = quotemeta $field->[0];
				push @actions, "push \@{\$self->{current_context}{children}[-1]{'$field'}}, $value;";
			} else {
				$field = quotemeta $field;
				push @actions, "\$self->{current_context}{children}[-1]{'$field'} = $value;";
			}
		}
	}

	if (defined $action->{exit_context}) {
		push @actions, "\$self->exit_context;";
		$self->{context_default_case} = { die => 'unexpected token' } unless defined $self->{context_default_case};
	} elsif (defined $action->{enter_context}) {
		my $context_type = quotemeta $action->{enter_context};
		push @actions, "\$self->enter_context('$context_type');";
	} elsif (defined $action->{switch_context}) {
		my $context_type = quotemeta $action->{switch_context};
		push @actions, "\$self->switch_context('$context_type');";
	}

	if (defined $action->{die}) {
		my $msg = quotemeta $action->{die};
		push @actions, "\$self->confess_at_current_offset('$msg');";
	}

	if (defined $action->{warn}) {
		my $msg = quotemeta $action->{warn};
		push @actions, "warn '$msg';";
	}

	return join ("\n\t\t\t", '', @actions) . "\n";
}

sub compile_syntax_default_action {
	my ($self, $action) = @_;

	my @actions;
	if (defined $action->{spawn}) {
		push @actions, "push \@{\$self->{current_context}{children}}, $action->{spawn};";
	}

	if (defined $action->{exit_context}) {
		push @actions, "\$self->exit_context;";
		$self->{context_default_case} = { die => 'unexpected token' } unless defined $self->{context_default_case};
	} elsif (defined $action->{enter_context}) {
		my $context_type = quotemeta $action->{enter_context};
		push @actions, "\$self->enter_context('$context_type');";
	} elsif (defined $action->{switch_context}) {
		my $context_type = quotemeta $action->{switch_context};
		push @actions, "\$self->switch_context('$context_type');";
	}

	if (defined $action->{die}) {
		push @actions, "\$self->confess_at_current_offset('$action->{die}');";
	}

	if (defined $action->{warn}) {
		push @actions, "warn '$action->{warn}';";
	}

	return join ("\n\t\t\t", '', @actions) . "\n";
}

sub compile_syntax_spawn_expression {
	my ($self, $expression) = @_;
	if (ref $expression eq 'ARRAY') {
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

	if ($expression =~ /\A\&([a-zA-Z_][a-zA-Z_0-9]*)\Z/) {
		return "\$self->extract_context_result('$1')";
	} elsif ($expression =~ /\A\$previous_spawn\Z/) {
		return "pop \@{\$self->{current_context}{children}}";
	} elsif ($expression =~ /\A\$tokens\[(\d+)\]\Z/) {
		return "\$tokens[$1]";
	} else {
		my $value = quotemeta $expression;
		return "'$value'";
	}
}

1;
