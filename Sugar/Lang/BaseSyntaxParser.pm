package Sugar::Lang::BaseSyntaxParser;
use parent 'Sugar::Lang::Tokenizer';
use strict;
use warnings;

use feature 'say';

use Carp;
use Data::Dumper;



sub new {
	my ($class, %opts) = @_;
	my $self = $class->SUPER::new(%opts);

	$self->{contexts} = $opts{contexts}
			// croak "contexts argument required for Sugar::Lang::BaseSyntaxParser";

	return $self
}

sub parse {
	my ($self) = @_;
	$self->SUPER::parse;

	# $self->{syntax_tree} = {};

	# $self->{current_context} = { context_type => 'root' };
	# $self->{syntax_tree} = $self->{current_context};
	# $self->{context_stack} = [];
	# $self->{current_syntax_context} = $self->{contexts}{$self->{current_context}{context_type}};

	# while ($self->more_tokens) {
		# confess "undefined context_type referenced '$self->{current_context}{context_type}'"
		# 		unless defined $self->{contexts}{$self->{current_context}{context_type}};
	# }
	$self->{syntax_tree} = $self->context_root($self->{syntax_tree});

	$self->confess_at_current_offset("more tokens after parsing complete") if $self->more_tokens;

	return $self->{syntax_tree}
}

# sub get_variable {
# 	my ($self, $identifier) = @_;
# 	confess "undefined variable requested: '$identifier'" unless exists $self->{syntax_definition_intermediate}{variables}{$identifier};
# 	return $self->{syntax_definition_intermediate}{variables}{$identifier}
# }

# sub get_context {
# 	my ($self, $value) = @_;
# 	if ($value =~ /\A\!(\w++)\Z/) {
# 		my $context_type = $1;
# 		confess "undefined context requested: '$context_type'" unless defined $self->{contexts}{$context_type};
# 		return $context_type

# 	} else {
# 		confess "unknown context type requested: '$value'";
# 	}
# }

1;
