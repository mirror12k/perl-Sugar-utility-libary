#!/usr/bin/env perl
package Sugar::Test::LangVerifier;
use parent 'Sugar::Test::Generic';
use strict;
use warnings;

use feature 'say';

use Carp;
use Term::ANSIColor;
use Data::Dumper;



sub new {
	my ($class, %args) = @_;
	my $self = $class->SUPER::new(%args);

	$self->{execute_callback} = \&execute_parser;

	$self->{parser_class} = $args{parser_class} // croak "parser_class argument required";
	$self->{ignore_keys} = $args{ignore_keys} // { line_number => 1 };

	return $self
}

sub execute_parser {
	my ($self, %args) = @_;

	my $parser = $self->{parser_class}->new;
	$parser->{text} = $args{text};
	my $tree = $parser->parse_from_context($args{context_key} // 'context_root');

	return $tree;
}



1;


