#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

package Sugar::Lang::SugarPreprocessor2;

	sub new {
		my ($self, $args) = @_;
		$self = bless {}, $self;
		$self->{registered_commands} = [];
		$self->{cached_defines} = {};
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
				my $into = shift(@{$lines});
				while (($into =~ /\\\Z/s)) {
					if ((0 == scalar(@{$lines}))) {
						die "incomplete command at the end of a file: $into";
					}
					$into = ($into =~ s/\\\Z//sr);
					$into .= "\n";
					$into .= shift(@{$lines});
				}
				if (($v =~ /\A\#\s*sugar_define\b\s*(?:\#(\w+)\s*)?\{\/(.*?)\/([msixgcpodualn]*)\}\s*\Z/s)) {
					push @{$self->{registered_commands}}, { define_key => ($1), what => ($2), flags => ($3), into => ($into) };
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
				if ($command->{define_key}) {
					$self->cache_match($command->{define_key}, $matched_stuff);
				}
				my $into = $self->sub_into($command->{into}, $matched_stuff);
				$remaining_text = ($remaining_text =~ s/$regex/$into/sr);
				$matched_stuff = [ ($remaining_text =~ /$regex/) ];
			}
		}
		return $remaining_text;
	}
	
	sub cache_match {
		my ($self, $key, $matched_stuff) = @_;
		if (not ($self->{cached_defines}->{$key})) {
			$self->{cached_defines}->{$key} = [];
		}
		push @{$self->{cached_defines}->{$key}}, $matched_stuff;
	}
	
	sub sub_into {
		my ($self, $into, $matched_stuff) = @_;
		my $i = 1;
		foreach my $sub_to (@{$matched_stuff}) {
			if (not (defined ($sub_to))) {
				$sub_to = '';
			}
			$into = ($into =~ s/\$$i|\$\{$i\}/$sub_to/gsr);
			$i += 1;
		}
		my $inner_cache_keys = [];
		while (($into =~ /\#\s*sugar_inner_define\b\s*(?:\#(\w+)\s*)?\{\/(.*?)\/([msixgcpodualn]*)\}\s*\{\{(.*?)\}\}/s)) {
			my $inner_command = { define_key => ($1), what => ($2), flags => ($3), into => ($4) };
			$inner_command->{into} = ($inner_command->{into} =~ s/\$\{l(\d+)\}/\${$1}/gsr);
			$inner_command->{into} = ($inner_command->{into} =~ s/\$l(\d+)/\$$1/gsr);
			$into = ($into =~ s/\#\s*sugar_inner_define\b\s*(?:\#(\w+)\s*)?\{\/(.*?)\/([msixgcpodualn]*)\}\s*\{\{(.*?)\}\}//sr);
			my $regex = "(?$inner_command->{flags}:$inner_command->{what})";
			my $matched_stuff = [ ($into =~ /$regex/) ];
			while ((0 < scalar(@{$matched_stuff}))) {
				if ($inner_command->{define_key}) {
					push @{$inner_cache_keys}, $inner_command->{define_key};
					$self->cache_match($inner_command->{define_key}, $matched_stuff);
				}
				my $inner_into = $self->sub_into($inner_command->{into}, $matched_stuff);
				$into = ($into =~ s/$regex/$inner_into/sr);
				$matched_stuff = [ ($into =~ /$regex/) ];
			}
		}
		while (($into =~ /\#foreach\b\s*\#(\w+)\s*\{\{(.*?)\}\}/s)) {
			my $cache_key = $1;
			my $looped_into = $2;
			$looped_into = ($looped_into =~ s/\$\{l(\d+)\}/\${$1}/gsr);
			$looped_into = ($looped_into =~ s/\$l(\d+)/\$$1/gsr);
			if (exists($self->{cached_defines}->{$cache_key})) {
				my $nested_into = join('', @{[ map { $self->sub_into($looped_into, $_) } @{$self->{cached_defines}->{$cache_key}} ]});
				$into = ($into =~ s/\#foreach\b\s*\#(\w+)\s*\{\{(.*?)\}\}/$nested_into/sr);
			} else {
				$into = ($into =~ s/\#foreach\b\s*\#(\w+)\s*\{\{(.*?)\}\}//sr);
			}
		}
		foreach my $inner_cache_key (@{$inner_cache_keys}) {
			$self->{cached_defines}->{$inner_cache_key} = [];
		}
		return $into;
	}
	
	sub main {
		my ($self) = @_;
	
	my ($files_list) = @_;

	# use Data::Dumper;
	require Sugar::IO::File;

	my $preprocessor = __PACKAGE__->new;
	foreach my $file (@$files_list) {
		my @lines = Sugar::IO::File->new($file)->readlines;
		# say Dumper \@lines;

		say $preprocessor->preprocess_lines(\@lines);
		# say Dumper $preprocessor->{cached_defines};
	}

	}
	
	caller or main(\@ARGV);
	

1;

