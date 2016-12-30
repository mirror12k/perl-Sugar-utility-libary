package Sugar::Lang::GrammarCompiler;
use parent 'Sugar::Lang::BaseSyntaxParser';
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use Sugar::IO::File;
use Sugar::Lang::SyntaxIntermediateCompiler;



our $tokens = [
	'symbol' => qr/\{|\}|\[|\]|=>|=|,/,
	'package_identifier' => qr/[a-zA-Z_][a-zA-Z0-9_]*+(\:\:[a-zA-Z_][a-zA-Z0-9_]*+)++/,
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
	assign_scope => \&context_assign_scope,
	context_definition => \&context_context_definition,
	def_value => \&context_def_value,
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


sub context_assign_scope {
	my ($self) = @_;
	my @spawned_value;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=>') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, $tokens[0][1];
			push @spawned_value, $self->context_spawn_expression();
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 2][1] eq ']' and $self->{tokens}[$self->{tokens_index} + 3][1] eq '=>') {
			my @tokens = $self->step_tokens(4);
			push @spawned_value, $tokens[0][1];
			push @spawned_value, [];
			push @spawned_value, $self->context_spawn_expression();
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, $tokens[0][1];
			push @spawned_value, {};
			push @spawned_value, $self->context_spawn_expression();
			$self->confess_at_current_offset('expected \'}\', \'=>\'')
				unless $self->{tokens}[$self->{tokens_index} + 0][1] eq '}' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=>';
			@tokens = (@tokens, $self->step_tokens(2));
			push @spawned_value, $self->context_spawn_expression();
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = $self->step_tokens(1);
			return @spawned_value;
		} else {
			my @tokens;
			$self->confess_at_current_offset('assign expression expected');
		}

	}
}

sub context_context_definition {
	my ($self) = @_;
	my @spawned_value;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = $self->step_tokens(1);
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'default' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, undef;
			push @spawned_value, [ $self->context_match_action ];
		} else {
			my @tokens;
			push @spawned_value, [ $self->context_match_list ];
			$self->confess_at_current_offset('expected \'{\'')
				unless $self->{tokens}[$self->{tokens_index} + 0][1] eq '{';
			@tokens = (@tokens, $self->step_tokens(1));
			push @spawned_value, [ $self->context_match_action ];
		}

	}
}

sub context_def_value {
	my ($self) = @_;
	my @spawned_value;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, $tokens[0][1];
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s) {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, $tokens[0][1];
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\w++\Z/) {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, $tokens[0][1];
			return @spawned_value;
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected token in def_value');
		}

	}
}

sub context_ignored_tokens_list {
	my ($self) = @_;
	my @spawned_value;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = $self->step_tokens(1);
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/) {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, $tokens[0][1];
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected token in ignored_tokens_list');
		}

	}
}

sub context_match_action {
	my ($self) = @_;
	my @spawned_value;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'assign' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, 'assign';
			push @spawned_value, [ $self->context_assign_scope ];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'spawn') {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, 'spawn';
			push @spawned_value, $self->context_spawn_expression();
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'return') {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, 'return';
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'match') {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, 'match';
			push @spawned_value, [ $self->context_match_list ];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'warn' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, 'warn';
			push @spawned_value, $tokens[1][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'die' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, 'die';
			push @spawned_value, $tokens[1][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = $self->step_tokens(1);
			return @spawned_value;
		} else {
			my @tokens;
			$self->confess_at_current_offset('expected \'}\' to close match actions list');
		}

	}
}

sub context_match_list {
	my ($self) = @_;
	my @spawned_value;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\w++\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq ',') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, $tokens[0][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\w++\Z/) {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, $tokens[0][1];
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq ',') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, $tokens[0][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\/([^\\\/]|\\.)*+\/[msixpodualn]*\Z/s) {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, $tokens[0][1];
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s and $self->{tokens}[$self->{tokens_index} + 1][1] eq ',') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, $tokens[0][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, $tokens[0][1];
			return @spawned_value;
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected end of match list');
		}

	}
}

sub context_root {
	my ($self) = @_;
	my @spawned_value;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=') {
			my @tokens = $self->step_tokens(2);
			$self->{current_context}{'variables'}{$tokens[0][1]} = ($self->context_def_value)[0];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'package' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+(\:\:[a-zA-Z_][a-zA-Z0-9_]*+)++\Z/) {
			my @tokens = $self->step_tokens(2);
			$self->{current_context}{'package_identifier'} = $tokens[1][1];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'tokens' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = $self->step_tokens(2);
			$self->{current_context}{'tokens'} = [ $self->context_token_definition ];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'ignored_tokens' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '{') {
			my @tokens = $self->step_tokens(2);
			$self->{current_context}{'ignored_tokens'} = [ $self->context_ignored_tokens_list ];
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'context' and $self->{tokens}[$self->{tokens_index} + 1][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 2][1] eq '{') {
			my @tokens = $self->step_tokens(3);
			$self->{current_context}{'contexts'}{$tokens[1][1]} = [ $self->context_context_definition ];
		} else {
			my @tokens;
			return @spawned_value;
		}

	}
}

sub context_spawn_expression {
	my ($self) = @_;
	my @spawned_value;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A\$\d++\Z/) {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, $tokens[0][1];
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A!\w++\Z/) {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, $tokens[0][1];
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A'([^\\']|\\[\\'])*+'\Z/s) {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, $tokens[0][1];
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq 'undef') {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, undef;
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq '[' and $self->{tokens}[$self->{tokens_index} + 1][1] eq ']') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, [];
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq '{' and $self->{tokens}[$self->{tokens_index} + 1][1] eq '}') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, {};
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] eq '[') {
			my @tokens = $self->step_tokens(1);
			push @spawned_value, [ $self->context_spawn_expression_list ];
			return @spawned_value;
		} else {
			my @tokens;
			$self->confess_at_current_offset('spawn expression expected');
		}

	}
}

sub context_spawn_expression_list {
	my ($self) = @_;
	my @spawned_value;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A!\w++\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq ']') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, $tokens[0][1];
			return @spawned_value;
		} else {
			my @tokens;
			$self->confess_at_current_offset('spawn expression list expected');
		}

	}
}

sub context_token_definition {
	my ($self) = @_;
	my @spawned_value;

	while ($self->more_tokens) {
		if ($self->{tokens}[$self->{tokens_index} + 0][1] eq '}') {
			my @tokens = $self->step_tokens(1);
			return @spawned_value;
		} elsif ($self->{tokens}[$self->{tokens_index} + 0][1] =~ /\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/ and $self->{tokens}[$self->{tokens_index} + 1][1] eq '=>') {
			my @tokens = $self->step_tokens(2);
			push @spawned_value, $tokens[0][1];
			push @spawned_value, $self->context_def_value();
		} else {
			my @tokens;
			$self->confess_at_current_offset('unexpected token in token_definition');
		}

	}
}

