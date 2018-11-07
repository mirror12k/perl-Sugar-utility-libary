#!/usr/bin/env perl
package Sugar::Test::LangVerifier;
use strict;
use warnings;

use feature 'say';

use Carp;
use Term::ANSIColor;
use Data::Dumper;



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
			$self->compare_values($expected_result, $tree, '');
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


sub compare_values {
	my ($self, $v1, $v2, $access_key) = @_;

	return $self->compare_values_hash($v1, $v2, $access_key) if ref $v1 eq 'HASH';
	return $self->compare_values_array($v1, $v2, $access_key) if ref $v1 eq 'ARRAY';
	die "v1$access_key is not defined\n" if not defined $v1 and defined $v2;
	die "v2$access_key is not defined\n" if not defined $v2 and defined $v1;
	die "v1$access_key and v2$access_key do not match: [$v1] <=> [$v2]\n" unless $v1 eq $v2;
}


sub compare_values_hash {
	my ($self, $v1, $v2, $access_key) = @_;

	die "v1$access_key is not a hash\n" unless ref $v1 eq 'HASH';
	die "v2$access_key is not a hash\n" unless ref $v2 eq 'HASH';

	my %hash_keys;
	@hash_keys{keys %$v1, keys %$v2} = ();
	foreach my $key (keys %hash_keys) {
		# say "compare $key";
		next if exists $self->{ignore_keys}{$key};

		die "v1$access_key\->{$key} is missing\n" unless exists $v1->{$key};
		die "v2$access_key\->{$key} is missing\n" unless exists $v2->{$key};

		$self->compare_values($v1->{$key}, $v2->{$key}, "$access_key\->{$key}");
	}
}


sub compare_values_array {
	my ($self, $v1, $v2, $access_key) = @_;

	die "v1$access_key is not a array\n" unless ref $v1 eq 'ARRAY';
	die "v2$access_key is not a array\n" unless ref $v2 eq 'ARRAY';

	my $length_v1 = @$v1;
	my $length_v2 = @$v2;

	die "v1$access_key is missing items: $length_v1 vs $length_v2\n" if @$v1 < @$v2;
	die "v2$access_key is missing items $length_v1 vs $length_v2\n" if @$v2 < @$v1;
	
	foreach my $i (0 .. $#$v1) {
		$self->compare_values($v1->[$i], $v2->[$i], "$access_key\->[$i]");
	}
}



1;


