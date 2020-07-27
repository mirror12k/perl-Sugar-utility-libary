#!/usr/bin/env perl
package Sugar::CLI::ProjectCompiler;

use strict;
use warnings;
use feature 'say';

use Sugar::IO::File;
use Sugar::IO::Dir;



sub new {
	my ($self, $args) = @_;
	$self = bless {}, $self;
	return $self;
}

sub compile_project_directory {
	my ($src_dir, $bin_dir, %options) = @_;
	$src_dir = Sugar::IO::Dir->new($src_dir);
	$bin_dir = Sugar::IO::Dir->new($bin_dir);

	# grab our instructions
	my @instructions = Sugar::IO::File->new($options{project_file} // die 'required project_file option')->readlines;

	say "compiling project: $src_dir => $bin_dir";

	# create the directory if it doesn't exist yet
	$bin_dir->mk unless $bin_dir->exists;

	# my $index_file = Sugar::IO::File->new("$bin_dir/index.php");

	# get a list of all files
	my @all_files = $src_dir->recursive_files;

	foreach my $line (@instructions) {
		if ($line =~ /\A(.*?)\s*=>\s*(.*?):\s+(.*?)\Z/s) {
			my $filematch = $1;
			my $outpath = $2;
			my $command = $3;

			foreach my $source_path (@all_files) {
				my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
				if (my @matched_stuff = $relative_path =~ /\A$filematch\Z/) {
					my $destination_path = "$bin_dir/$outpath";

					foreach my $i (1 .. @matched_stuff) {
						$destination_path =~ s/\$$i/$matched_stuff[$i-1]/g;
					}

					my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
					my $destination_file = Sugar::IO::File->new($destination_path);
					$destination_file->dir->mk unless $destination_file->dir->exists;

					my $subcommand = $command;
					$subcommand =~ s/\$src_dir/$src_dir/g;
					$subcommand =~ s/\$bin_dir/$bin_dir/g;
					$subcommand =~ s/\$src/$source_path/g;
					$subcommand =~ s/\$bin/$destination_path/g;

					say "\t$subcommand";
					system "$subcommand";
				}
			}
		}
	}
}


sub main {

	die "usage: $0 <src directory> <bin directory>" unless @_ >= 2;

	my %options;
	while (@_ > 2) {
		my $arg = shift;
		if ($arg eq '--project_file') {
			$options{project_file} = shift;
		} elsif ($arg eq '--watch_directory') {
			$options{watch_directory} = 1;
		} else {
			die "invalid option: $arg";
		}
	}

	$options{project_file} //= "$_[0]/project_file";

	my $src_dir = $_[0];
	my $bin_dir = $_[1];
	compile_project_directory($src_dir, $bin_dir, %options);

	if ($options{watch_directory}) {
		require File::Hotfolder;
		File::Hotfolder::watch($src_dir,
			fork => 0,
			callback => sub { compile_project_directory($src_dir, $bin_dir, %options); },
		)->loop;
	}
}

caller or main(@ARGV);

