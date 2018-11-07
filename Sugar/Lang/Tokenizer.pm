package Sugar::Lang::Tokenizer;
use strict;
use warnings;

use feature 'say';

use Carp;

use Sugar::IO::File;



sub new {
	my ($class, %opts) = @_;
	my $self = bless {}, $class;

	$self->{filepath} = Sugar::IO::File->new($opts{filepath}) if defined $opts{filepath};
	$self->{text} = $opts{text} if defined $opts{text};

	$self->{token_regexes} = $opts{token_regexes} // croak "token_regexes argument required for Sugar::Lang::Tokenizer";
	$self->{ignored_tokens} = $opts{ignored_tokens};

	$self->compile_tokenizer_regex;

	return $self
}

sub compile_tokenizer_regex {
	my ($self) = @_;
	use re 'eval';
	my $token_pieces = join '|',
			map "($self->{token_regexes}[$_*2+1])(?{'$self->{token_regexes}[$_*2]'})",
				0 .. $#{$self->{token_regexes}} / 2;
	$self->{tokenizer_regex} = qr/$token_pieces/so;

# 	# optimized selector for token names, because %+ is slow
# 	my @index_names = map $self->{token_regexes}[$_*2], 0 .. $#{$self->{token_regexes}} / 2;
# 	my @index_variables = map "\$$_", 1 .. @index_names;
# 	my $index_selectors = join "\n\tels",
# 			map "if (defined $index_variables[$_]) { return '$index_names[$_]', $index_variables[$_]; }",
# 			0 .. $#index_names;

# 	$self->{token_selector_callback} = eval "
# sub {
# 	$index_selectors
# }
# ";
}

sub parse {
	my ($self) = @_;

	my $text;
	$text = $self->{filepath}->read if defined $self->{filepath};
	$text = $self->{text} unless defined $text;

	croak "no text or filepath specified before parsing" unless defined $text;

	return $self->parse_tokens($text)
}


sub parse_tokens {
	my ($self, $text) = @_;
	$self->{text} = $text;
	
	my @tokens;

	my $line_number = 1;
	my $offset = 0;

	# study $text;
	while ($text =~ /\G$self->{tokenizer_regex}/gco) {
		# despite the absurdity of this solution, this is still faster than loading %+
		# my ($token_type, $token_text) = each %+;
		# my ($token_type, $token_text) = $self->{token_selector_callback}->();
		my ($token_type, $token_text) = ($^R, $^N);

		push @tokens, [ $token_type => $token_text, $line_number, $offset ];
		$offset = pos $text;
		# amazingly, this is faster than a regex or an index count
		# must be because perl optimizes out the string modification, and just performs a count
		$line_number += $token_text =~ y/\n//;
	}

	confess "parsing error on line $line_number:\nHERE ---->" . substr ($text, pos $text // 0, 200) . "\n\n\n"
			if not defined pos $text or pos $text != length $text;

	if (defined $self->{ignored_tokens}) {
		foreach my $ignored_token (@{$self->{ignored_tokens}}) {
			@tokens = grep $_->[0] ne $ignored_token, @tokens;
		}
	}

	@tokens = $self->filter_tokens(@tokens);

	$self->{tokens} = \@tokens;
	$self->{tokens_index} = 0;
	$self->{save_tokens_index} = 0;

	return $self->{tokens}
}


sub filter_tokens {
	my ($self, @tokens) = @_;
	# do nothing; overridable optional method
	return @tokens
}






sub more_tokens {
	my ($self, $offset) = @_;
	$offset //= 0;
	return $self->{tokens_index} + $offset < @{$self->{tokens}}
}

sub peek_token {
	my ($self) = @_;
	return undef unless $self->more_tokens;
	return $self->{tokens}[$self->{tokens_index}]
}

sub next_token {
	my ($self) = @_;
	return undef unless $self->more_tokens;
	return $self->{tokens}[$self->{tokens_index}++]
}

sub step_tokens {
	my ($self, $count) = @_;
	my @tokens = @{$self->{tokens}}[$self->{tokens_index} .. ($self->{tokens_index} + $count - 1)];
	$self->{tokens_index} += $count;
	return @tokens
}


sub is_token_type {
	my ($self, $type, $offset) = @_;
	return 0 unless $self->more_tokens;
	return $self->{tokens}[$self->{tokens_index} + ($offset // 0)][0] eq $type
}

sub is_token_val {
	my ($self, $type, $val, $offset) = @_;
	return 0 unless $self->more_tokens;
	my $token = $self->{tokens}[$self->{tokens_index} + ($offset // 0)];
	return (('*' eq $type or $token->[0] eq $type) and
			(ref $val ? $token->[1] =~ $val : $token->[1] eq $val))
}

sub assert_token_type {
	my ($self, $type, $offset) = @_;
	$self->confess_at_current_offset ("expected token type $type" . (defined $offset ? " (at offset $offset)" : '')
			. " instead got token type $self->{tokens}[$self->{tokens_index}][0] with value $self->{tokens}[$self->{tokens_index}][1]")
		unless $self->is_token_type($type, $offset);
}

sub assert_token_val {
	my ($self, $type, $val, $offset) = @_;
	$self->confess_at_current_offset ("expected token type $type with value '$val'" . (defined $offset ? " (at offset $offset)" : '')
			. " instead got token type $self->{tokens}[$self->{tokens_index}][0] with value $self->{tokens}[$self->{tokens_index}][1]")
		unless $self->is_token_val($type, $val, $offset);
}

sub assert_step_token_type {
	my ($self, $type) = @_;
	$self->assert_token_type($type);
	return $self->next_token
}

sub assert_step_token_val {
	my ($self, $type, $val) = @_;
	$self->assert_token_val($type, $val);
	return $self->next_token
}

sub confess_at_current_offset {
	my ($self, $msg) = @_;

	my $position;
	my $next_token = '';
	if ($self->more_tokens) {
		$position = 'line ' . $self->{tokens}[$self->{tokens_index}][2];
		my ($type, $val) = @{$self->peek_token};
		$next_token = " (next token is $type => <$val>)";
	} else {
		$position = 'end of file';
	}

	# say $self->dump_at_current_offset;

	confess "error on $position: $msg$next_token";
}

sub current_line_number {
	my ($self) = @_;
	my $index = 0;
	while ($self->more_tokens($index)) {
		return $self->{tokens}[$self->{tokens_index} + $index][2] unless $self->is_token_type( whitespace => $index );
		$index++;
	}
	return undef
}


sub dump {
	my ($self) = @_;

	return join "\n", map { "[$_->[2]:$_->[3]] $_->[0] => <$_->[1]>" } @{$self->{tokens}}
}

sub dump_at_current_offset {
	my ($self) = @_;

	my @tokens = @{$self->{tokens}};
	return join "\n", map { "[$_->[2]:$_->[3]] $_->[0] => <$_->[1]>" } @tokens[$self->{tokens_index} .. $#tokens]
}











1;
