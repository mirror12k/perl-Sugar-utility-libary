
all: sugar_grammar sugar_compiler sugarsweet_grammar sugarsweet_compiler test_sugar_grammar test_json_example

sugar_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugar_grammar.sugar > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarGrammarParser.pm
sugar_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugar_compiler.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarGrammarCompiler.pm
sugarsweet_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugarsweet_grammar.sugar > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetParser.pm
sugarsweet_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugarsweet_compiler.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetCompiler.pm
sugar_preprocessor:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugar_preprocessor.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarPreprocessor.pm


all_trial: trial_sugar_grammar trial_sugar_compiler trial_sugarsweet_grammar trial_sugarsweet_compiler

trial_sugar_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugar_grammar.sugar > SugarGrammarParser.pm
	chmod +x SugarGrammarParser.pm
trial_sugar_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugar_compiler.sugarsweet > SugarGrammarCompiler.pm
	chmod +x SugarGrammarCompiler.pm
trial_sugarsweet_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugarsweet_grammar.sugar > SugarsweetParser.pm
	chmod +x SugarsweetParser.pm
trial_sugarsweet_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugarsweet_compiler.sugarsweet > SugarsweetCompiler.pm
	chmod +x SugarsweetCompiler.pm
trial_sugar_preprocessor:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugar_preprocessor.sugarsweet > SugarPreprocessor.pm
	chmod +x SugarPreprocessor.pm

test_sugar_grammar:
	./tests/sugar_grammar_tests.pl
	./tests/sugar_grammar_endtoend_tests.pl

test_json_example:
	./Sugar/Lang/SugarGrammarCompiler.pm example/json_parser.sugar > example/JSONParser.pm
	./example/json_parser_tests.pl
	./Sugar/Lang/SugarGrammarCompiler.pm example/json_parser.synth > example/JSONParser.pm
	./example/json_parser_tests.pl

profile_sugar_compiler:
	perl -d:NYTProf Sugar/Lang/SugarGrammarParser.pm grammar/sugar_grammar.sugar > temp_compiled_file
	rm temp_compiled_file
