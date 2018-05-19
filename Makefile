
sugar_grammar:
	./Sugar/Lang/SugarGrammarParser.pm grammar/sugar_grammar > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarGrammarParser.pm
sugarsweet_grammar:
	./Sugar/Lang/SugarGrammarParser.pm grammar/sugarsweet_grammar > Sugar/Lang/SugarsweetParser.pm
sugarsweet_compiler:
	./Sugar/Lang/SugarsweetCompiler.pm grammar/sugarsweet_compiler > temp_compiled_file
	chmod +x temp_compiled_file
	mv temp_compiled_file Sugar/Lang/SugarsweetCompiler.pm
