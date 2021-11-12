#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Sugar::Test::Barrage;



Sugar::Test::Barrage->new(
	test_files_dir => 'tests/sugarsweet_multilang',
	test_files_regex => qr/\.sugarsweet$/,
	control_processor => "cat \$testfile.expected",
	test_processor => "Sugar/Lang/SugarsweetCompiler/Perl.pm \$testfile > tests/TestClass.pm && perl tests/TestClass.pm",
)->run;

Sugar::Test::Barrage->new(
	test_files_dir => 'tests/sugarsweet_multilang',
	test_files_regex => qr/\.sugarsweet$/,
	control_processor => "cat \$testfile.expected",
	test_processor => "Sugar/Lang/SugarsweetCompiler/PHP.pm \$testfile > tests/TestClass.php && php tests/TestClass.php",
)->run;

Sugar::Test::Barrage->new(
	test_files_dir => 'tests/sugarsweet_multilang',
	test_files_regex => qr/\.sugarsweet$/,
	control_processor => "cat \$testfile.expected",
	test_processor => "Sugar/Lang/SugarsweetCompiler/Python.pm \$testfile > tests/TestClass.py && python3 tests/TestClass.py",
)->run;

# Sugar::Test::Barrage->new(
# 	test_files_dir => 'tests/sugarsweet_multilang',
# 	test_files_regex => qr/\.sugarsweet$/,
# 	control_processor => "cat \$testfile.expected",
# 	test_processor => "Sugar/Lang/SugarsweetCompiler/JavaScript.pm \$testfile > tests/TestClass.js && nodejs tests/TestClass.js",
# )->run;


