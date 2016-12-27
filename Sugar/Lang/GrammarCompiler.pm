package Sugar::Lang::GrammarCompiler;
use parent "Sugar::Lang::BaseSyntaxParser";
use strict;
use warnings;

use feature "say";

use Data::Dumper;

use Sugar::IO::File;



our $tokens = [
	'symbol' => qr/\{|\}|\[|\]|=>|=|,/,
	'identifier' => qr/[a-zA-Z_][a-zA-Z0-9_]*+/,
	'string' => qr/'([^\\']|\\[\\'])*+'/s,
	'regex' => qr/\/([^\\\/]|\\.)*+\/[msixpodualn]*/s,
	'variable' => qr/\$\w++/,
	'context_reference' => qr/!\w++/,
	'comment' => qr/\#[^\n]*+\n/s,
	'whitespace' => qr/\s++/s,
];

our $ignored_tokens = [
	'comment',
	'whitespace',
];

our $contexts = {
	assign_hash => \&context_assign_hash,
	assign_scope => \&context_assign_scope,
	context_definition => \&context_context_definition,
	def_value => \&context_def_value,
	enter_match_action => \&context_enter_match_action,
	ignored_tokens_list => \&context_ignored_tokens_list,
	match_action => \&context_match_action,
	match_list => \&context_match_list,
	root => \&context_root,
	spawn_expression => \&context_spawn_expression,
	spawn_expression_list => \&context_spawn_expression_list,
	token_definition => \&context_token_definition,
};



sub new {
	my ($class, %opts) = @_;

	$opts{token_regexes} = $tokens;
	$opts{ignored_tokens} = $ignored_tokens;
	$opts{contexts} = $contexts;

	my $self = $class->SUPER::new(%opts);

	return $self
}

use Sugar::Lang::SyntaxIntermediateCompiler;

sub main {
	my $parser = Sugar::Lang::GrammarCompiler->new;
	foreach my $file (@_) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		my $tree = $parser->parse;
		# say Dumper $tree;

		my $compiler = Sugar::Lang::SyntaxIntermediateCompiler->new(syntax_definition_intermediate => $tree);
		say $compiler->to_package;
	}
}

caller or main(@ARGV);


	sub context_assign_hash {
		my ($self) = @_;
		if ($self->is_token_val('*' => '}', 0) and $self->is_token_val('*' => '=>', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			$self->switch_context($self->get_context('!spawn_expression'));
		} else {
			my @tokens;
			$self->confess_at_current_offset('\'}\' expected to close hash assignment');
		}

		return;
	}

	sub context_assign_scope {
		my ($self) = @_;
		if ($self->is_token_val('*' => qr/\A'([^\\']|\\[\\'])*+'\Z/s, 0) and $self->is_token_val('*' => '=>', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->nest_context($self->get_context('!spawn_expression'));
		} elsif ($self->is_token_val('*' => qr/\A'([^\\']|\\[\\'])*+'\Z/s, 0) and $self->is_token_val('*' => '[', 1) and $self->is_token_val('*' => ']', 2) and $self->is_token_val('*' => '=>', 3)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			push @{$self->{current_context}{children}}, [];
			$self->nest_context($self->get_context('!spawn_expression'));
		} elsif ($self->is_token_val('*' => qr/\A'([^\\']|\\[\\'])*+'\Z/s, 0) and $self->is_token_val('*' => '{', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			push @{$self->{current_context}{children}}, {};
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!spawn_expression'));
			$self->nest_context($self->get_context('!assign_hash'));
		} elsif ($self->is_token_val('*' => '}', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			$self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('assign expression expected');
		}

		return;
	}

	sub context_context_definition {
		my ($self) = @_;
		if ($self->is_token_val('*' => '}', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => 'default', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, undef;
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!enter_match_action'), 'ARRAY');
		} else {
			my @tokens;
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!match_list'), 'ARRAY');
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!enter_match_action'), 'ARRAY');
		}

		return;
	}

	sub context_def_value {
		my ($self) = @_;
		if ($self->is_token_val('*' => qr/\A'([^\\']|\\[\\'])*+'\Z/s, 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => qr/\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s, 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => qr/\A\$\w++\Z/, 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected token in def_value');
		}

		return;
	}

	sub context_enter_match_action {
		my ($self) = @_;
		if ($self->is_token_val('*' => '{', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			$self->switch_context($self->get_context('!match_action'));
		} else {
			my @tokens;
			$self->confess_at_current_offset('expected \'{\' after match directive');
		}

		return;
	}

	sub context_ignored_tokens_list {
		my ($self) = @_;
		if ($self->is_token_val('*' => '}', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => qr/\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/, 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected token in ignored_tokens_list');
		}

		return;
	}

	sub context_match_action {
		my ($self) = @_;
		if ($self->is_token_val('*' => 'assign', 0) and $self->is_token_val('*' => '{', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, 'assign';
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!assign_scope'), 'ARRAY');
		} elsif ($self->is_token_val('*' => 'spawn', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, 'spawn';
			$self->nest_context($self->get_context('!spawn_expression'));
		} elsif ($self->is_token_val('*' => 'enter_context', 0) and $self->is_token_val('*' => qr/\A!\w++\Z/, 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, 'enter_context';
			push @{$self->{current_context}{children}}, $tokens[1];
		} elsif ($self->is_token_val('*' => 'switch_context', 0) and $self->is_token_val('*' => qr/\A!\w++\Z/, 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, 'switch_context';
			push @{$self->{current_context}{children}}, $tokens[1];
		} elsif ($self->is_token_val('*' => 'nest_context', 0) and $self->is_token_val('*' => qr/\A!\w++\Z/, 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, 'nest_context';
			push @{$self->{current_context}{children}}, $tokens[1];
		} elsif ($self->is_token_val('*' => 'exit_context', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, 'exit_context';
		} elsif ($self->is_token_val('*' => 'warn', 0) and $self->is_token_val('*' => qr/\A'([^\\']|\\[\\'])*+'\Z/s, 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, 'warn';
			push @{$self->{current_context}{children}}, $tokens[1];
		} elsif ($self->is_token_val('*' => 'die', 0) and $self->is_token_val('*' => qr/\A'([^\\']|\\[\\'])*+'\Z/s, 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, 'die';
			push @{$self->{current_context}{children}}, $tokens[1];
		} elsif ($self->is_token_val('*' => '}', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			$self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('expected \'}\' to close match actions list');
		}

		return;
	}

	sub context_match_list {
		my ($self) = @_;
		if ($self->is_token_val('*' => qr/\A\$\w++\Z/, 0) and $self->is_token_val('*' => ',', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
		} elsif ($self->is_token_val('*' => qr/\A\$\w++\Z/, 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => qr/\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s, 0) and $self->is_token_val('*' => ',', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
		} elsif ($self->is_token_val('*' => qr/\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s, 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => qr/\A'([^\\']|\\[\\'])*+'\Z/s, 0) and $self->is_token_val('*' => ',', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
		} elsif ($self->is_token_val('*' => qr/\A'([^\\']|\\[\\'])*+'\Z/s, 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected end of match list');
		}

		return;
	}

	sub context_root {
		my ($self) = @_;
		if ($self->is_token_val('*' => qr/\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/, 0) and $self->is_token_val('*' => '=', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			$self->{current_context}{'variables'}{$tokens[0]} = $self->extract_context_result($self->get_context('!def_value'));
		} elsif ($self->is_token_val('*' => 'tokens', 0) and $self->is_token_val('*' => '{', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			$self->{current_context}{'tokens'} = $self->extract_context_result($self->get_context('!token_definition'), 'ARRAY');
		} elsif ($self->is_token_val('*' => 'ignored_tokens', 0) and $self->is_token_val('*' => '{', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			$self->{current_context}{'ignored_tokens'} = $self->extract_context_result($self->get_context('!ignored_tokens_list'), 'ARRAY');
		} elsif ($self->is_token_val('*' => 'context', 0) and $self->is_token_val('*' => qr/\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/, 1) and $self->is_token_val('*' => '{', 2)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			$self->{current_context}{'contexts'}{$tokens[1]} = $self->extract_context_result($self->get_context('!context_definition'), 'ARRAY');
		} else {
			my @tokens;
			$self->exit_context;
		}

		return;
	}

	sub context_spawn_expression {
		my ($self) = @_;
		if ($self->is_token_val('*' => qr/\A\$\d++\Z/, 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => qr/\A!\w++\Z/, 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => qr/\A'([^\\']|\\[\\'])*+'\Z/s, 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => 'undef', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, undef;
			$self->exit_context;
		} elsif ($self->is_token_val('*' => '[', 0) and $self->is_token_val('*' => ']', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, [];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => '{', 0) and $self->is_token_val('*' => '}', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, {};
			$self->exit_context;
		} elsif ($self->is_token_val('*' => '[', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!spawn_expression_list'), 'ARRAY');
			$self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('spawn expression expected');
		}

		return;
	}

	sub context_spawn_expression_list {
		my ($self) = @_;
		if ($self->is_token_val('*' => qr/\A!\w++\Z/, 0) and $self->is_token_val('*' => ']', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			$self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('spawn expression list expected');
		}

		return;
	}

	sub context_token_definition {
		my ($self) = @_;
		if ($self->is_token_val('*' => '}', 0)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			$self->exit_context;
		} elsif ($self->is_token_val('*' => qr/\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/, 0) and $self->is_token_val('*' => '=>', 1)) {
			my @tokens;
			push @tokens, $self->next_token->[1];
			push @tokens, $self->next_token->[1];
			push @{$self->{current_context}{children}}, $tokens[0];
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!def_value'));
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected token in token_definition');
		}

		return;
	}

