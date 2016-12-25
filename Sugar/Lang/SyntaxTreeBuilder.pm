package Sugar::Lang::SyntaxTreeBuilder;
use parent 'Sugar::Lang::Tokenizer';
use strict;
use warnings;

use feature 'say';

use Carp;



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
	push @{$self->{current_context}{children}}, $new_context;
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
		my $action_code = $self->compile_syntax_action($action);

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
	my ($self, $action) = @_;

	my $follows_code = '';
	if (defined $action->{follows}) {
		$follows_code = "\$self->confess_at_current_offset('$action->{else}') unless "
			. $self->compile_syntax_condition($action->{follows}) . ';';

		if (ref $action->{follows}) {
			$follows_code .= "\n\t\t\t\$self->next_token;" x @{$action->{follows}};
		} else {
			$follows_code .= "\n\t\t\t\$self->next_token;";
		}
	}

	my $spawn_code = '';
	if (defined $action->{spawn}) {
		$spawn_code = "push \@{\$self->{current_context}{children}}, $action->{spawn};";
	}

	my $context_code = '';
	if (defined $action->{exit_context}) {
		$context_code = "\$self->exit_context;";
		$self->{context_default_case} = { die => 'unexpected token' } unless defined $self->{context_default_case};
	} elsif (defined $action->{enter_context}) {
		$context_code = "\$self->enter_context('$action->{enter_context}');";
	} elsif (defined $action->{switch_context}) {
		$context_code = "\$self->switch_context('$action->{switch_context}');";
	}

	my $die_code = '';
	if (defined $action->{die}) {
		$die_code = "\$self->confess_at_current_offset('$action->{die}');";
	}

	my $warn_code = '';
	if (defined $action->{warn}) {
		$warn_code = "warn '$action->{warn}';";
	}

	return "
			\$self->next_token;
			$follows_code
			$spawn_code
			$context_code
			$warn_code
			$die_code
"
}

sub compile_syntax_default_action {
	my ($self, $action) = @_;

	my $spawn_code = '';
	if (defined $action->{spawn}) {
		$spawn_code = "push \@{\$self->{current_context}{children}}, $action->{spawn};";
	}

	my $context_code = '';
	if (defined $action->{exit_context}) {
		$context_code = "\$self->exit_context;";
		$self->{context_default_case} = { die => 'unexpected token' } unless defined $self->{context_default_case};
	} elsif (defined $action->{enter_context}) {
		$context_code = "\$self->enter_context('$action->{enter_context}');";
	}

	my $die_code = '';
	if (defined $action->{die}) {
		$die_code = "\$self->confess_at_current_offset('$action->{die}');";
	}

	my $warn_code = '';
	if (defined $action->{warn}) {
		$warn_code = "warn '$action->{warn}';";
	}

	return "
			$spawn_code
			$context_code
			$warn_code
			$die_code
"
}

1;
