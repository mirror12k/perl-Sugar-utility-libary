
all: sugar_grammar sugar_compiler sugarsweet_grammar sugarsweet_base_compiler sugarsweet_perl_compiler sugar_preprocessor sugar_preprocessor2 test_sugar_grammar test_json_example test_sugarsweet_multilang

sugar_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugar_grammar.sugar > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarGrammarParser.pm
sugar_compiler:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugar_compiler.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarGrammarCompiler.pm
sugarsweet_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugarsweet_grammar.sugar > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetParser.pm
sugarsweet_base_compiler:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugarsweet_base_compiler.sugarsweet > temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetBaseCompiler.pm
sugarsweet_perl_compiler:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugarsweet_perl_compiler.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetCompiler/Perl.pm
sugarsweet_php_compiler:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugarsweet_php_compiler.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetCompiler/PHP.pm
sugarsweet_python_compiler:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugarsweet_python_compiler.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetCompiler/Python.pm
sugarsweet_javascript_compiler:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugarsweet_javascript_compiler.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetCompiler/JavaScript.pm
sugarsweet_csharp_compiler:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugarsweet_csharp_compiler.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetCompiler/CSharp.pm

sugar_preprocessor:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugar_preprocessor.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarPreprocessor.pm

sugar_preprocessor2:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugar_preprocessor2.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarPreprocessor2.pm


all_trial: trial_sugar_grammar trial_sugar_compiler trial_sugarsweet_grammar trial_sugarsweet_compiler

trial_sugar_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugar_grammar.sugar > SugarGrammarParser.pm
	chmod +x SugarGrammarParser.pm
trial_sugar_compiler:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugar_compiler.sugarsweet > SugarGrammarCompiler.pm
	chmod +x SugarGrammarCompiler.pm
trial_sugarsweet_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugarsweet_grammar.sugar > SugarsweetParser.pm
	chmod +x SugarsweetParser.pm
trial_sugarsweet_compiler:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugarsweet_base_compiler.sugarsweet > SugarsweetCompiler/Perl.pm
	chmod +x SugarsweetCompiler/Perl.pm
trial_sugar_preprocessor:
	./Sugar/Lang/SugarsweetCompiler/Perl.pm grammar/sugar_preprocessor.sugarsweet > SugarPreprocessor.pm
	chmod +x SugarPreprocessor.pm

test_sugar_grammar:
	./tests/sugar_grammar_tests.pl
	./tests/sugar_grammar_endtoend_tests.pl

test_json_example:
	./Sugar/Lang/SugarGrammarCompiler.pm example/json_parser.sugar > example/JSONParser.pm
	./example/json_parser_tests.pl
	./Sugar/Lang/SugarGrammarCompiler.pm example/json_parser.synth > example/JSONParser.pm
	./example/json_parser_tests.pl

test_sugarsweet_multilang:
	./tests/sugarsweet_cross_compilation_tests.pl

profile_sugar_compiler:
	perl -d:NYTProf Sugar/Lang/SugarGrammarParser.pm grammar/sugar_grammar.sugar > temp_compiled_file
	rm temp_compiled_file

test_sugarsweet:
# 	make sugarsweet_base_compiler
# 	make sugarsweet_php_compiler
# 	make sugarsweet_python_compiler
# 	make sugarsweet_javascript_compiler
	make sugarsweet_csharp_compiler

# 	Sugar/Lang/SugarsweetCompiler/Perl.pm tests/test_class.sugarsweet > tests/TestClass.pm
# 	perl tests/TestClass.pm
# 	Sugar/Lang/SugarsweetCompiler/PHP.pm tests/test_class.sugarsweet > tests/TestClass.php
# 	php tests/TestClass.php
# 	Sugar/Lang/SugarsweetCompiler/Python.pm tests/test_class.sugarsweet > tests/TestClass.py
# 	python3 tests/TestClass.py
# 	Sugar/Lang/SugarsweetCompiler/JavaScript.pm tests/test_class.sugarsweet > tests/TestClass.js
# 	nodejs tests/TestClass.js
	Sugar/Lang/SugarsweetCompiler/CSharp.pm tests/sugarsweet_multilang/test_regex.sugarsweet > tests/TestClass.cs
	mcs tests/TestClass.cs
	./tests/TestClass.exe

