
all: sugar_grammar sugar_compiler sugarsweet_grammar sugarsweet_compiler test_sugar_grammar

sugar_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugar_grammar > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarGrammarParser.pm
sugar_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugar_compiler > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarGrammarCompiler.pm
sugarsweet_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugarsweet_grammar > Sugar/Lang/SugarsweetParser.pm
sugarsweet_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugarsweet_compiler > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetCompiler.pm


trial_sugar_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugar_grammar > SugarGrammarParser.pm
	chmod +x SugarGrammarParser.pm
trial_sugar_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugar_compiler > SugarGrammarCompiler.pm
	chmod +x SugarGrammarCompiler.pm
trial_sugarsweet_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugarsweet_grammar > SugarsweetParser.pm
	chmod +x SugarsweetParser.pm
trial_sugarsweet_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugarsweet_compiler > SugarsweetCompiler.pm
	chmod +x SugarsweetCompiler.pm

test_sugar_grammar:
	./tests/sugar_grammar_tests.pl
