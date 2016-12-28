package Sugar::Lang::GrammarCompiler;
use parent "Sugar::Lang::BaseSyntaxParser";
use strict;
use warnings;

use feature "say";

use Data::Dumper;

use Sugar::IO::File;
use Sugar::Lang::SyntaxIntermediateCompiler;



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

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=>') {
			my @tokens = $self->step_tokens(2);
			return $self->switch_context($self->get_context('!spawn_expression'));
		} else {
			my @tokens;
			$self->confess_at_current_offset('\'}\' expected to close hash assignment');
		}

	}
}

sub context_assign_scope {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=>') {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->nest_context($self->get_context('!spawn_expression'));
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 2][1] eq ']' and $self->{tokens}[$self->{tokens_index} + 3][1] eq '=>') {
			my @tokens = $self->step_tokens(4);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			push @{$self->{current_context}{children}}, [];
			return $self->nest_context($self->get_context('!spawn_expression'));
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			push @{$self->{current_context}{children}}, {};
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!spawn_expression'));
			return $self->nest_context($self->get_context('!assign_hash'));
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = $self->step_tokens(1);
			return $self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('assign expression expected');
		}

	}
}

sub context_context_definition {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = $self->step_tokens(1);
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'default') {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, undef;
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!enter_match_action'), 'ARRAY');
		} else {
			my @tokens;
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!match_list'), 'ARRAY');
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!enter_match_action'), 'ARRAY');
		}

	}
}

sub context_def_value {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s) {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\w++\Z/) {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected token in def_value');
		}

	}
}

sub context_enter_match_action {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] eq '{') {
			my @tokens = $self->step_tokens(1);
			return $self->switch_context($self->get_context('!match_action'));
		} else {
			my @tokens;
			$self->confess_at_current_offset('expected \'{\' after match directive');
		}

	}
}

sub context_ignored_tokens_list {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = $self->step_tokens(1);
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/) {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $tokens[0][1];
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected token in ignored_tokens_list');
		}

	}
}

sub context_match_action {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'assign' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, 'assign';
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!assign_scope'), 'ARRAY');
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'spawn') {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, 'spawn';
			return $self->nest_context($self->get_context('!spawn_expression'));
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'enter_context' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A!\w++\Z/) {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, 'enter_context';
			push @{$self->{current_context}{children}}, $tokens[1][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'switch_context' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A!\w++\Z/) {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, 'switch_context';
			push @{$self->{current_context}{children}}, $tokens[1][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'nest_context' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A!\w++\Z/) {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, 'nest_context';
			push @{$self->{current_context}{children}}, $tokens[1][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'exit_context') {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, 'exit_context';
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'warn' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, 'warn';
			push @{$self->{current_context}{children}}, $tokens[1][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'die' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, 'die';
			push @{$self->{current_context}{children}}, $tokens[1][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = $self->step_tokens(1);
			return $self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('expected \'}\' to close match actions list');
		}

	}
}

sub context_match_list {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\w++\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq ',') {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, $tokens[0][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\w++\Z/) {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq ',') {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, $tokens[0][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s) {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq ',') {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, $tokens[0][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected end of match list');
		}

	}
}

sub context_root {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens = $self->step_tokens(2);
			$self->{current_context}{'variables'}{$tokens[0][1]} = $self->extract_context_result($self->get_context('!def_value'));
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'tokens' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = $self->step_tokens(2);
			$self->{current_context}{'tokens'} = $self->extract_context_result($self->get_context('!token_definition'), 'ARRAY');
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'ignored_tokens' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = $self->step_tokens(2);
			$self->{current_context}{'ignored_tokens'} = $self->extract_context_result($self->get_context('!ignored_tokens_list'), 'ARRAY');
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'context' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '{') {
			my @tokens = $self->step_tokens(3);
			$self->{current_context}{'contexts'}{$tokens[1][1]} = $self->extract_context_result($self->get_context('!context_definition'), 'ARRAY');
		} else {
			my @tokens;
			return $self->exit_context;
		}

	}
}

sub context_spawn_expression {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\d++\Z/) {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A!\w++\Z/) {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'undef') {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, undef;
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ']') {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, [];
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '}') {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, {};
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens = $self->step_tokens(1);
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!spawn_expression_list'), 'ARRAY');
			return $self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('spawn expression expected');
		}

	}
}

sub context_spawn_expression_list {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A!\w++\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq ']') {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			return $self->exit_context;
		} else {
			my @tokens;
			$self->confess_at_current_offset('spawn expression list expected');
		}

	}
}

sub context_token_definition {
	my ($self) = @_;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = $self->step_tokens(1);
			return $self->exit_context;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=>') {
			my @tokens = $self->step_tokens(2);
			push @{$self->{current_context}{children}}, $tokens[0][1];
			push @{$self->{current_context}{children}}, $self->extract_context_result($self->get_context('!def_value'));
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected token in token_definition');
		}

	}
}

