# Sugar Grammar Language Documentation
Sugar grammar lang is a language designed to specify which tokens a parser should parse in a file, how the syntax tree builder should read these tokens, and what output should be produced in the syntax tree. Additionally, it provides options to run various commands such as warnings and dies, and execute external functions.

## Compiling Sugar Grammar
Compiled grammar compilers are produced by running ```perl Sugar/Lang/GrammarCompiler.pm <grammar filepath> > output_package```, which will produce a fully functional perl package. This perl package is still dependant on Sugar as it is parented to Sugar::Lang::BaseSyntaxParser and Sugar::Lang::Tokenizer (TODO: make Sugar produce stand-alone packages). This package will be full functional and instantiable as so:

```perl
my $compiler = MyAwesomeCompiler->new(filepath => 'some_file.txt');
my $syntax_tree = $compiler->parse;
```

## Sugar Grammar Language
To start, (optionally) declare your package name:
```perl
# comments are declared perl style
package MyAwesomeCompiler
```

It is recommended to declare all of your token regexs inside variables, regexs are standard perl regexes with optional flags, variable interpolation is not allowed:
```perl
whitespace_token = /\s+/s
cstyle_comment_token = /\/\/[^\n]*+(\n|\Z)/s

keyword_token = /public|private|class/s
symbol_token = /\{|\}/s
identifier_token = /\w++/s
```

Then tell Sugar that these are your tokens. Order is important, as that is the order in which the regexs will be compiled together, so make sure that higher precendence tokens are first.
```perl
tokens {
	whitespace => $whitespace_token
	comment => $cstyle_comment_token

	keyword => $keyword_token
	identifier => $identifier_token
}
```

We however don't want our compiler to bother with whitespace and comment tokens, so we tell Sugar that we want to ignore them:
```perl
ignored_tokens {
	whitespace
	comment
}
```

Now a bit of information; Sugar works with contexts, either object or list contexts. These contexts have a set of conditional options which can execute commands when the conditions are met. List contexts produce a list of items that is returned as-is. Object contexts are always started with a single argument which is their object, they can then modify the object or even replace the object, and finally returning their current object. Contexts can call other contexts to collect more items, collect properties, or just to parse some tokens ahead.

Back to work, Sugar expects us to create a object context called 'root' which will be the entry point for our parser:
```perl
object context root {
	# this part is actually an if-elsif-else

	# this is our first case, which expects a 'public' token, a 'class' token, an identifier token which matches the identifier regex, and finally a '{' token
	# it will only match if all of these properties are met
	/public|private/, 'class', $identifier_token, '{' {
		# we then create a hash ref with specific fields, 
		# then we pass it off to the class_def object context which will parse the insides of the class before returning
		# finally we will push it into the 'classes' array member of the root context object
		assign {
			'classes'[] => !class_def->{
				# to 'type' we assign a simple string
				'type' => 'class_definition'
				# to the access type, we assign the 'public' or 'private' we matched earlier
				'access_type' => $0
				# to 'class_name' we assign the identifier token which we matched earlier
				'class_name' => $2
			}
		}
	}
	# by default, if the context fails to match anything, it will die()
}
```

Since we are calling a 'class_def' object context, we must define it as well:
```perl
object context class_def {
	# if we find an identifier token, we append it to the stash of class identifiers
	$identifier_token {
		assign {
			'identifiers'[] => $0
		}
	}
	# if we find a close bracket, we must return, thus closing the class definition context
	'}' {
		return
	}
	# we can manually specify our default case and what to do here, in this case we want the code to die explicitly
	default {
		die 'expected "}" token to close class definition'
	}
}
```

There is way more stuff to learn, check out the [Sugar's own parser written in Sugar](../../grammar/sugar_grammar) for more information.
