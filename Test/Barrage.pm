#!/usr/bin/env perl
package Sugar::Test::Barrage;
use strict;
use warnings;

use feature 'say';

use Carp;

use Sugar::IO::Dir;





sub new {
	my ($class, %args) = @_;
	# croak "path argument required" unless defined $path;

	my $self = bless {}, $class;
	$self->{test_files_dir} = Sugar::IO::Dir->new($args{test_files_dir} // croak "test_files_dir argument required");
	$self->{test_files_regex} = $args{test_files_regex};
	$self->{control_processor} = $args{control_processor} // croak "control_processor argument required";
	$self->{test_processor} = $args{test_processor} // croak "test_processor argument required";

	return $self
}

sub run {
	my ($self, $subdir) = @_;

	my $testdir = $self->{test_files_dir};
	$testdir = $testdir->dir($subdir) if defined $subdir;

	my @testfiles = $testdir->recursive_files;
	@testfiles = grep $self->{test_files_regex} =~ $_, @testfiles if defined $self->{test_files_regex};
	foreach my $testfile (@testfiles) {
		say "test file $testfile";

		my (@control_lines, @test_lines);
		if (ref $self->{control_processor}) {
			@control_lines = $self->{control_processor}->($self, $testfile);
		} else {
			my $control_command = $self->{control_processor};
			$control_command =~ s/\$testfile\b/$testfile/g;
			@control_lines = `$control_command`;
		}

		if (ref $self->{test_processor}) {
			@test_lines = $self->{test_processor}->($self, $testfile);
		} else {
			my $test_command = $self->{test_processor};
			$test_command =~ s/\$testfile\b/$testfile/g;
			@test_lines = `$test_command`;
		}


		my $error = 0;
		if (@test_lines != @control_lines) {
			say "\tincorrect number of lines $#control_lines vs $#test_lines";
			$error = 1;
		}
		foreach (0 .. $#control_lines) {
			unless (defined $test_lines[$_] and $control_lines[$_] eq $test_lines[$_]) {
				say "\tinconsistent lines [$_]";
				print "\t\t$control_lines[$_]" if defined $control_lines[$_];
				print "\t\t$test_lines[$_]" if defined $test_lines[$_];

				$error = 1;
			}
		}

		if ($error) {
			say "test $testfile failed";
		} else {
			say "test $testfile successful";
		}
	}
}



1;


