# Sugar utilities library and Sugar grammar language
A utilities library written because I'm tired of reinventing the same old generic code.

## Sugar::IO
A few IO tools for files, directories, and archives.

requires IO::Dir, IO::File, Carp, and overload perl packages.

### Sugar::IO::File
A minimalistic file interface. See the [pod documentation](Sugar/IO/File.pm) for more information.
```perl
use feature 'say';
use Sugar::IO::File;

my $file = Sugar::IO::File->new('some_file.txt');
if ($file->exists) {
	say "file $file already exists!";
} else {
	say "writing 'hello world' x 3 into $file";
	$file->write("hello world\n" x 3);
}

say "contents of $file: ", $file->read;

say "contents by $file lines:";
foreach my $line ($file->readlines) {
	say "line: $line";
}

say "deleting the file...";
$file->rm;
```

### Sugar::IO::Dir
A minimalistic directory interface. See the [pod documentation](Sugar/IO/Dir.pm) for more information.
```perl
use feature 'say';
use Sugar::IO::Dir;

my $dir = Sugar::IO::Dir->new('some_dir');

if ($dir->exists) {
	say "directory $dir already exists!";
} else {
	say "creating directory $dir";
	$dir->mk;
}

say "all items in $dir: ", join ', ', $dir->list;
say "all files in $dir: ", join ', ', $dir->files;
say "all dirs in $dir: ", join ', ', $dir->dirs;
say "all files (recursively found) in $dir: ", join ', ', $dir->recursive_files;

say "deleting $dir and all of its contents...";
$dir->rm;
```

### Sugar::IO::Archive
A WIP, currently only supports zip archives.

## Sugar::Test::Barrage
A utility to quickly write a testing suite for other projects. Uses a pair of 'processor's which are command line commands which will be executed onto each file in a given directory. Common use cases are when a program's output needs to be compared against a static file, or when a program's output needs to match that of another program. See the [pod documentation](Sugar/Test/Barrage.pm) for more details.

## Sugar::Lang
A full grammar language parser and compiler which produces packages capable of tokenizing and building syntax trees from a given file or text according to the compiled grammar. Sugar lang is itself compiled from a Sugar grammar file. See the [Sugar language documentation](Sugar/Lang) for more information.
