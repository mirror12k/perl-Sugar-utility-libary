#!/usr/bin/env perl
package Sugar::Test::LangVerifier;
use strict;
use warnings;

use feature 'say';

use Carp;
use Term::ANSIColor;
use Data::Dumper;


use Sugar::Test::Compare;



sub new {
	my ($class, %args) = @_;

	my $self = bless {}, $class;
	$self->{parser_class} = $args{parser_class} // croak "parser_class argument required";
	$self->{ignore_keys} = $args{ignore_keys} // { line_number => 1 };
	$self->{test_list} = [];

	return $self
}

sub run {
	my ($self) = @_;

	$self->{test_index} = 0;
	foreach my $test (@{$self->{test_list}}) {
		$self->{test_index}++;
		$test->();
	}
}

sub expect_result {
	my ($self, $test_name, $context_key, $text, $expected_result) = @_;

	push @{$self->{test_list}}, sub {
		my $parser = $self->{parser_class}->new;
		$parser->{text} = $text;
		my $tree;
		eval {
			$tree = $parser->parse_from_context($context_key);
		};

		if ($@) {
			say color('bold bright_red'), "[#$self->{test_index}] $test_name: parser error:", color('reset');
			say color('bright_red'), "\t\t$@";
			return;
		}

		eval {
			Sugar::Test::Compare::compare_values({ ignore_keys => $self->{ignore_keys} }, $expected_result, $tree);
		};

		if ($@) {
			say color('bold bright_red'), "[#$self->{test_index}] $test_name: value error:", color('reset');
			say color('bright_red'), "\t\t$@", color('reset');
			say Dumper $expected_result, $tree;
			# say Dumper $expected_result;
		} else {
			say color('bold bright_green'), "[#$self->{test_index}] $test_name: pass", color('reset');
		}
	};
}

sub expect_error {
	my ($self, $test_name, $context_key, $text, $expected_error) = @_;

	push @{$self->{test_list}}, sub {
		my $parser = $self->{parser_class}->new;
		$parser->{text} = $text;
		my $tree;
		eval {
			$tree = $parser->parse_from_context($context_key);
		};

		if ($@ and $@ =~ $expected_error) {
			say color('bold bright_green'), "[#$self->{test_index}] $test_name: pass", color('reset');
		} elsif ($@) {
			say color('bold bright_red'),
					"[#$self->{test_index}] $test_name: expected error: /$expected_error/, got:", color('reset');
			say color('bright_red'), "\t\t$@", color('reset');
		} else {
			say color('bold bright_red'),
					"[#$self->{test_index}] $test_name: expected error: /$expected_error/, got none", color('reset');
		}
	};
}


1;


