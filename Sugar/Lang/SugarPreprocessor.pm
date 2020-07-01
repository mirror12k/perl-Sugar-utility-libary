#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

package Sugar::Lang::SugarPreprocessor;
sub new {
	my ($self, $args) = @_;
	$self = bless {}, $self;
	$self->{registered_commands} = [];
	return $self;
}

sub preprocess_lines {
	my ($self, $lines) = @_;
	my $remaining_text = '';
	while ((0 < scalar(@{$lines}))) {
		my $v = shift(@{$lines});
		if (($v =~ /\A\#\s*sugar_define\b/s)) {
			while (($v =~ /\\\Z/s)) {
				if ((0 == scalar(@{$lines}))) {
					die "incomplete command at the end of a file: $v";
				}
				$v = ($v =~ s/\\\Z//sr);
				$v .= "\n";
				$v .= shift(@{$lines});
			}
			if (($v =~ /\A\#\s*sugar_define\b\s+\{\/(.*?)\/([msixgcpodualn]*)\}\s+(.*)\Z/s)) {
				push @{$self->{registered_commands}}, { what => ($1), flags => ($2), into => ($3) };
			} else {
				die "invalid sugar_define: $v";
			}
		} else {
			$remaining_text .= "$v\n";
		}
	}
	foreach my $command (@{$self->{registered_commands}}) {
		my $regex = "(?$command->{flags}:$command->{what})";
		my $matched_stuff = [ ($remaining_text =~ /$regex/) ];
		while ((0 < scalar(@{$matched_stuff}))) {
			my $into = $command->{into};
			my $i = 1;
			foreach my $sub_to (@{$matched_stuff}) {
				$into = ($into =~ s/\$$i/$sub_to/gsr);
				$i += 1;
			}
			$remaining_text = ($remaining_text =~ s/$regex/$into/sr);
			$matched_stuff = [ ($remaining_text =~ /$regex/) ];
		}
	}
	return $remaining_text;
}

sub main {
	my ($self) = @_;

	my ($files_list) = @_;

	use Data::Dumper;
	require Sugar::IO::File;

	my $preprocessor = __PACKAGE__->new;
	foreach my $file (@$files_list) {
		my @lines = Sugar::IO::File->new($file)->readlines;
		# say Dumper \@lines;

		say $preprocessor->preprocess_lines(\@lines);
		# say Dumper $preprocessor->{registered_commands};
	}

}

caller or main(\@ARGV);


