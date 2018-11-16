#!/usr/bin/env perl
package Sugar::Test::Generic;
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
	$self->{test_list} = [];
	# execute_callback must be defined by sub classes
	# $self->{execute_callback} = sub { ... };

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
	my ($self, $test_name, %args) = @_;

	push @{$self->{test_list}}, sub {
		my $experimental_result;
		eval {
			$experimental_result = $self->{execute_callback}->($self, %args);
		};

		if ($@) {
			say color('bold bright_red'), "[#$self->{test_index}] $test_name: runtime error:", color('reset');
			say color('bright_red'), "\t\t$@";
			return;
		}

		eval {
			Sugar::Test::Compare::compare_values({ ignore_keys => $self->{ignore_keys} }, $args{expected_result}, $experimental_result);
		};

		if ($@) {
			say color('bold bright_red'), "[#$self->{test_index}] $test_name: value error:", color('reset');
			say color('bright_red'), "\t\t$@", color('reset');
			say Dumper $args{expected_result}, $experimental_result;
			# say Dumper $expected_result;
		} else {
			say color('bold bright_green'), "[#$self->{test_index}] $test_name: pass", color('reset');
		}
	};
}

sub expect_error {
	my ($self, $test_name, %args) = @_;

	push @{$self->{test_list}}, sub {
		# my $parser = $self->{parser_class}->new;
		# $parser->{text} = $text;
		# my $tree;
		# $tree = $parser->parse_from_context($context_key);
		my $experimental_result;
		eval {
			$experimental_result = $self->{execute_callback}->($self, %args);
		};

		if ($@ and $@ =~ $args{expected_error}) {
			say color('bold bright_green'), "[#$self->{test_index}] $test_name: pass", color('reset');
		} elsif ($@) {
			say color('bold bright_red'),
					"[#$self->{test_index}] $test_name: expected error: /$args{expected_error}/, got:", color('reset');
			say color('bright_red'), "\t\t$@", color('reset');
		} else {
			say color('bold bright_red'),
					"[#$self->{test_index}] $test_name: expected error: /$args{expected_error}/, got none", color('reset');
		}
	};
}


1;


