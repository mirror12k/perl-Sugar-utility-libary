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
	my $token_pieces = join '|', map "(?<$_>$self->{token_regexes}{$_})", keys %{$self->{token_regexes}};
	$self->{tokenizer_regex} = qr/$token_pieces/s;
}

sub parse {
	my ($self) = @_;

	my $text;
	$text = $self->{filepath}->read if defined $self->{filepath};
	$text = $self->{text};

	croak "no text or filepath specified before parsing" unless defined $text;

	return $self->parse_tokens($text)
}


sub parse_tokens {
	my ($self, $text) = @_;
	$self->{text} = $text;
	
	my @tokens;

	my $line_number = 1;
	my $offset = 0;

	my @token_types = keys %{$self->{token_regexes}};
	while ($text =~ /\G$self->{tokenizer_regex}/gc) {
		my ($token_type, $token_text) = each %+;
		push @tokens, [ $token_type => $token_text, $line_number, $offset ];
		$offset = pos $text;
		$line_number += ()= ($token_text =~ /\n/g);
	}

	die "error parsing file at " . substr ($text, pos $text // 0) if not defined pos $text or pos $text != length $text;

	if (defined $self->{ignored_tokens}) {
		foreach my $ignored_token (@{$self->{ignored_tokens}}) {
			@tokens = grep $_->[0] ne $ignored_token, @tokens;
		}
	}

	@tokens = $self->filter_tokens(@tokens);

	$self->{tokens} = \@tokens;
	$self->{tokens_index} = 0;

	return $self->{tokens}
}


sub filter_tokens {
	my ($self, @tokens) = @_;
	# do nothing; overridable optional method
	return @tokens
}



1;
