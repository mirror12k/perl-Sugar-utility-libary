#!/usr/bin/env perl
package Sugar::Test::Barrage;
use strict;
use warnings;

use feature 'say';

use Carp;

use Sugar::IO::Dir;




=pod

=head1 what is Sugar::Test::Barrage?

Barrage is a simple file-oriented testing utility for verifying an expiremental set of text line output against a control set.
output is compared line by line and a differing lines fail the test.

=head2 Sugar::Test::Barrage->new(%args)

initializes a new test barrage

=head3 arguments:

=over

=item
test_files_dir => required, defines the filepath to the directory of files/directories to test

=item
control_processor => required, processor which is assumed to return array of expected response lines

=item
test_processor => required, processor which is assumed to return array of expiremental response lines which will be compared against the expected response lines

=item
test_files_regex => optional regular expression reference, against which all test filepaths will be grepped. useful for isolating important files or files of a specific extension

=back

=head2 processors

the control processor and test processor may be either one of a string command line or a subroutine reference


=over

=item command line processor - 
passing a string as a processor indicates that it is a valid command line.
any occurance of /$testfile\b/ will be replaced by the actual test filepath, and the resulting command executed on shell

=item subroutine processor - 
passing a subroutine reference as a processor indicates for it to be executed directly with the file argument
the subroutine will receive as an argument, the test filepath as a Sugar::IO::File object

=back

=head2 $test->run([$subdir])

starts the execution of tests and prints out the status of each test.
optional subdir argument is directory name inside the given test_files_dir which will be
tested specifically instead of all files in the test_files_dir

=head1 example tests comparing interpreter against lua binary

this example uses Barrage to run the lua binary,
and compare the output to a perl script which interprets the same data

	use Sugar::Test::Barrage;

	Sugar::Test::Barrage->new(
		test_files_dir => 'lua_test_files',
		control_processor => "lua \$testfile",
		test_processor => "perl lua_interpreter.pl \$testfile",
	)->run;

=head2 example testing

this example uses Barrage to run the lua binary,
and compare the output to a perl script which interprets the same data

	use Sugar::Test::Barrage;

	Sugar::Test::Barrage->new(
		test_files_dir => 'run_tests',
		test_files_regex => qr/\.awesome$/,
		control_processor => "cat \$testfile.expected",
		test_processor => "perl my_processor.pl \$testfile",
	)->run;


=cut



sub new {
	my ($class, %args) = @_;

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
	@testfiles = grep $_ =~ $self->{test_files_regex}, @testfiles if defined $self->{test_files_regex};
	foreach my $testfile (@testfiles) {
		say "test file $testfile";

		my (@control_lines, @test_lines);
		if (ref $self->{control_processor}) {
			@control_lines = $self->{control_processor}->($testfile);
		} else {
			my $control_command = $self->{control_processor};
			$control_command =~ s/\$testfile\b/$testfile/g;
			@control_lines = `$control_command`;
		}

		if (ref $self->{test_processor}) {
			@test_lines = $self->{test_processor}->($testfile);
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


