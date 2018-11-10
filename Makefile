
all: sugar_grammar sugar_compiler sugarsweet_grammar sugarsweet_compiler test_sugar_grammar

sugar_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugar_grammar.sugar > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarGrammarParser.pm
sugar_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugar_compiler.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarGrammarCompiler.pm
sugarsweet_grammar:
	./Sugar/Lang/SugarGrammarCompiler.pm grammar/sugarsweet_grammar.sugar > Sugar/Lang/SugarsweetParser.pm
sugarsweet_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugarsweet_compiler.sugarsweet > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetCompiler.pm


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

test_sugar_grammar:
	./tests/sugar_grammar_tests.pl

profile_sugar_compiler:
	perl -d:NYTProf Sugar/Lang/SugarGrammarParser.pm grammar/sugar_grammar.sugar > temp_compiled_file
	rm temp_compiled_file
