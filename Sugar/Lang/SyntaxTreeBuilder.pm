package Sugar::Lang::SyntaxTreeBuilder;
use parent 'Sugar::Lang::Tokenizer';
use strict;
use warnings;

use feature 'say';

use Carp;

use Sugar::IO::File;



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

	$self->{current_context} = { type => 'root_context' };
	$self->{context_stack} = [];
	$self->{current_syntax_context} = $self->{syntax_definition}{$self->{current_context}{type}};

	while ($self->more_tokens) {
		$self->{current_syntax_context}->($self);
	}

}

sub compile_syntax_context {
	my ($self, $context_name, $context) = @_;

	my $code = '
	sub {
		my ($self) = @_;
';
	my @items = @$context;
	my $first_item = 1;
	while (@items) {
		my $condition = shift @items;
		my $condition_code = $self->compile_syntax_condition($condition);
		my $action = shift @items;
		my $action_code = $self->compile_syntax_action($action);

		$code .= "\t\t" if $first_item;
		$code .= "if ($condition_code) {$action_code\t\t} els";

		$first_item = 0;
	}

	$code .= "e {
			\$self->confess_at_current_offset('unimplemented at $context_name context')
		}
	}";

	say "compiled code: ", $code;
	return eval $code
}

sub compile_syntax_condition {
	my ($self, $condition) = @_;
	return "\$self->is_token_val('*' => '$condition')"
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

	return "
			\$self->next_token;
			$follows_code
"
}

1;
