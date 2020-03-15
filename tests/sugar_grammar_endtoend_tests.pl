#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Term::ANSIColor;
use Data::Dumper;



package Sugar::Test::EndToEndLangVerifier;
use parent 'Sugar::Test::Generic';

use Carp;

sub new {
	my ($class, %args) = @_;
	my $self = $class->SUPER::new(%args);

	$self->{execute_callback} = \&execute_parser;

	$self->{parser_class} = $args{parser_class} // croak "parser_class argument required";
	$self->{compiler_class} = $args{compiler_class} // croak "compiler_class argument required";
	$self->{ignore_keys} = $args{ignore_keys} // { line_number => 1 };

	return $self
}

sub execute_parser {
	my ($self, %args) = @_;

	my $parser = $self->{parser_class}->new;
	$parser->{text} = $args{parser_code};
	my $tree = $parser->parse_from_context('context_root');
	# say Dumper ($tree);

	my $compiler = $self->{compiler_class}->new({ syntax_definition_intermediate => $tree, %{$args{compile_args} // {
			# compile_standalone => 1,
		}} });
	$compiler->compile_syntax_intermediate;
	my $code = $compiler->to_package;
	# say "debug code: $code";

	eval "$code";
	die "error evaling: $@" if $@;

	my $temp_class = $tree->{package_identifier};
	my $temp_parser = $temp_class->new;
	$temp_parser->{text} = $args{text};
	my $second_tree = $temp_parser->parse_from_context($args{context_key} // 'context_root');

	return $second_tree;
}



package main;

use Sugar::Lang::SugarGrammarParser;
use Sugar::Lang::SugarGrammarCompiler;

use Data::Dumper;


my $verifier = Sugar::Test::EndToEndLangVerifier->new(
	parser_class => 'Sugar::Lang::SugarGrammarParser',
	compiler_class => 'Sugar::Lang::SugarGrammarCompiler',
);

# ignore contexts_by_name as it's too complex to implement right now
# $verifier->{ignore_keys}{contexts_by_name} = 1;

$verifier->expect_result(
	'test loop parsing',
	parser_code => q#
package __test::test1
tokens {
	identifier => /[a-zA-Z_][a-zA-Z0-9_]*+/
	symbol => /\\{|\\}|\\[|\\]|,|:/
	whitespace => /\\s++/s
}
ignored_tokens { whitespace }

list sub root
	=> @[ [] = *identifier ]

	#,
	text => '
	a a b c asdf _234
',
	expected_result => [qw/a a b c asdf _234/]
);

$verifier->expect_result(
	'test pre and post loop parsing',
	parser_code => q#
package __test::test2
tokens {
	identifier => /[a-zA-Z_][a-zA-Z0-9_]*+/
	symbol => /\\{|\\}|\\[|\\]|,|:/
	whitespace => /\\s++/s
}
ignored_tokens { whitespace }

list sub root
	=> '[', @[ [] = *identifier ], ']'

	#,
	text => '
	[ a a b c asdf _234 ]
',
	expected_result => [qw/a a b c asdf _234/]
);

$verifier->expect_result(
	'test branch loop parsing',
	parser_code => q#
package __test::test3
tokens {
	string => /"(?:[^"\\\\]|\\\\["\\\\\\/bfnrt])*"/s
	identifier => /[a-zA-Z_][a-zA-Z0-9_]*+/
	symbol => /\\{|\\}|\\[|\\]|,|:/
	whitespace => /\\s++/s
}
ignored_tokens { whitespace }

list sub root
	=> '[', @[ [] = !thing ], ']'

item sub thing
	=> $_ = *identifier
		| $_ = *string
		| return

	#,
	text => '
	[ a   a b   c "asdf" _234 ]
',
	expected_result => [qw/a a b c "asdf" _234/]
);

$verifier->expect_result(
	'test optional parsing',
	parser_code => q#
package __test::test4
tokens {
	string => /"(?:[^"\\\\]|\\\\["\\\\\\/bfnrt])*"/s
	identifier => /[a-zA-Z_][a-zA-Z0-9_]*+/
	symbol => /\\{|\\}|\\[|\\]|,|:/
	whitespace => /\\s++/s
}
ignored_tokens { whitespace }

list sub root
	=> @[ [] = !thing ]

item sub thing
	=> $_ = *identifier, ?[ $_ = *string ]
		| return

	#,
	text => '
	asdf qwer "qqer" zxcv "z" asfd
',
	expected_result => [qw/asdf "qqer" "z" asfd/]
);

$verifier->expect_result(
	'test lookahead parsing',
	parser_code => q#
package __test::test5
tokens {
	identifier => /[a-zA-Z_][a-zA-Z0-9_]*+/
	symbol => /\\{|\\}|\\[|\\]|,|:/
	whitespace => /\\s++/s
}
ignored_tokens { whitespace }

list sub root
	=> @[ [] = !thing ]

list sub thing
	=> [] = *identifier, ?[ ( [] = *identifier ) ]
		| return

	#,
	text => '
	a c b b
',
	expected_result => [[qw/a c/], [qw/c b/], [qw/b b/], [qw/b/]]
);

$verifier->expect_result(
	'test moar lookahead parsing',
	parser_code => q#
package __test::test6
tokens {
	identifier => /[a-zA-Z_][a-zA-Z0-9_]*+/
	symbol => /\\{|\\}|\\[|\\]|,|:/
	whitespace => /\\s++/s
}
ignored_tokens { whitespace }

list sub root
	=> @[ [] = !thing ]

list sub thing
	=> [] = *identifier, ?[ ( [] = *identifier, ?[ ( [] = *identifier ) ] ) ]
		| return

	#,
	text => '
	a c b b
',
	expected_result => [[qw/a c b/], [qw/c b b/], [qw/b b/], [qw/b/]]
);

$verifier->run;
