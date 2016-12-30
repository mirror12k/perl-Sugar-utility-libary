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

	$self->{current_context} = { context_type => 'root' };
	$self->{syntax_tree} = $self->{current_context};
	$self->{context_stack} = [];
	# $self->{current_syntax_context} = $self->{contexts}{$self->{current_context}{context_type}};

	# while ($self->more_tokens) {
		# confess "undefined context_type referenced '$self->{current_context}{context_type}'"
		# 		unless defined $self->{contexts}{$self->{current_context}{context_type}};
		$self->{contexts}{$self->{current_context}{context_type}}->($self);
	# }

	$self->confess_at_current_offset("more tokens after parsing complete") if $self->more_tokens;

	return $self->{syntax_tree}
}

sub get_variable {
	my ($self, $identifier) = @_;
	confess "undefined variable requested: '$identifier'" unless exists $self->{syntax_definition_intermediate}{variables}{$identifier};
	return $self->{syntax_definition_intermediate}{variables}{$identifier}
}

sub get_context {
	my ($self, $value) = @_;
	if ($value =~ /\A\!(\w++)\Z/) {
		my $context_type = $1;
		confess "undefined context requested: '$context_type'" unless defined $self->{contexts}{$context_type};
		return $context_type

	} else {
		confess "unknown context type requested: '$value'";
	}
}

# sub enter_context {
# 	my ($self, $context_type) = @_;

# 	my $new_context = { context_type => $context_type };
# 	push @{$self->{context_stack}}, $self->{current_context};
# 	$self->{current_context} = $new_context;
# }

# sub nest_context {
# 	my ($self, $context_type) = @_;
# 	$self->{current_context}{children} //= [];
# 	my $new_context = { context_type => $context_type, children => $self->{current_context}{children} };
# 	push @{$self->{context_stack}}, $self->{current_context};
# 	$self->{current_context} = $new_context;
# }

# sub exit_context {
# 	my ($self) = @_;
# 	confess 'attempt to exit root context' if $self->{current_context}{context_type} eq 'root';
# 	my @ret = @{$self->{current_context}{children} // []};
# 	$self->{current_context} = pop @{$self->{context_stack}};

# 	return @ret
# }

# sub switch_context {
# 	my ($self, $context_type) = @_;
# 	confess 'attempt to switch context on root context' if $self->{current_context}{context_type} eq 'root';

# 	$self->{current_context}{context_type} = $context_type;
# }

# sub extract_context_result {
# 	my ($self, $context_type) = @_;

# 	# my $previous_context = $self->{current_context};
# 	# $self->enter_context($context_type);
# 	# my $saved_context = $self->{current_context};

# 	# my @ret;
# 	# while ($self->{current_context} != $previous_context) {
# 		# confess "undefined context_type referenced '$self->{current_context}{context_type}'"
# 		# 		unless defined $self->{contexts}{$self->{current_context}{context_type}};
# 		return $self->{contexts}{$context_type}->($self);
# 	# }
# 	# say "debug ret: ", join ', ', @ret;
# 	# if (defined $modifier and $modifier eq 'ARRAY') {
# 	# 	return \@ret
# 	# } else {
# 	# 	return @ret
# 	# }
# 	# say 'got result: ', Dumper $result;
# 	# return $result
# }

# sub into_context {
# 	my ($self, $context_object) = @_;
# 	my $previous_context = $self->{current_context};
# 	push @{$self->{context_stack}}, $self->{current_context};
# 	$self->{current_context} = $context_object;

# 	while ($self->{current_context} != $previous_context) {
# 		# confess "undefined context_type referenced '$self->{current_context}{context_type}'"
# 		# 		unless defined $self->{contexts}{$self->{current_context}{context_type}};
# 		$self->{contexts}{$self->{current_context}{context_type}}->($self);
# 	}

# 	return $context_object
# }

1;
