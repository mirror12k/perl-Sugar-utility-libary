package Sugar::Lang::BaseSyntaxParser;
use parent 'Sugar::Lang::Tokenizer';
use strict;
use warnings;

use feature 'say';

use Carp;
use Data::Dumper;



sub parse {
	my ($self) = @_;
	return $self->parse_from_context('context_root');
}

sub parse_from_context {
	my ($self, $context) = @_;
	$self->SUPER::parse;

	$self->{syntax_tree} = $self->$context($self->{syntax_tree});
	$self->confess_at_current_offset("more tokens after parsing complete") if $self->more_tokens;

	return $self->{syntax_tree}
}

1;
