package Sugar::CLI::BaseCLI;
use strict;
use warnings;

use feature 'say';

use Term::ANSIColor;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	my $test_val = 1;

	$self->{commands} = {
		test_cmd => {
			description => 'test_cmd <argument> - prints your argument back',
			callback => sub {
				say "\t my test arg: $_[0]";
			},
		},
	};
	$self->{properties} = {
		test_val => {
			description => '[property] test_val - an example settable value',
			reference => \($test_val),
			# setter => sub { ... },
		},
	};

	return $self;
}

sub intro_msg {
	say color('bold bright_green'), __PACKAGE__, " loaded", color('reset');
	say "\t type 'help' for instructions";
}

sub caret_msg {
	print ("\n", color('bold bright_green'), 'cli', color('reset'), '> ');
	1;
}

sub run_cli {
	my ($self) = @_;

	$SIG{INT} = sub {
		die "interrupted!";
	};

	$self->intro_msg;

	$| = 1;
	while ($self->caret_msg and my $line = <>) {
		$line =~ s/\r?\n//s;
		next unless $line;
		next if $line =~ /\A\s*\#/s;

		eval {
			my ($cmd, @args) = split /\s+/, $line;

			if ($cmd =~ /\A!/) {
				$line =~ s/\A\s*!//s;
				system "$line";
			} elsif ($cmd eq 'exit') {
				exit;
			} elsif ($cmd eq 'help') {
				foreach my $key (sort keys %{$self->{commands}}) {
					say "\t $self->{commands}{$key}{description}";
				}
				say "";
				foreach my $key (sort keys %{$self->{properties}}) {
					say "\t $self->{properties}{$key}{description}";
					say "\t\t $key = ${$self->{properties}{$key}{reference}}";
				}
				say "";
				say "\t !whoami - execute bash commands";
				say "\t exit - exit";
			} elsif (exists $self->{commands}{$cmd}) {
				$self->{commands}{$cmd}{callback}->(@args);
			} elsif (exists $self->{properties}{$cmd}) {
				if (@args == 1) {
					if (exists $self->{properties}{$cmd}{setter}) {
						$self->{properties}{$cmd}{setter}->($args[0]);
					} else {
						${$self->{properties}{$cmd}{reference}} = $args[0];
					}
				}
				say "\t $cmd = ${$self->{properties}{$cmd}{reference}}";
			} else {
				warn "unknown command: $cmd";
			}
		};

		say "error: $@" if $@;
	}
}



caller or BaseCLI->new->run_cli;


