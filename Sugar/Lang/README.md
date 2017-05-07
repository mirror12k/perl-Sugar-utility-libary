# Sugar Grammar Language Documentation
Sugar grammar lang is an effective parser language for tokenizing and parsing syntax trees. Creating a new parser with Sugar is easy and fast, with the compilation process hiding away all of the nasty details of tokens iteration.

## Compiling Sugar Grammar
Grammar compilers are produced by running ```perl Sugar/Lang/GrammarCompiler.pm <grammar filepath> > output_package```, which will produce a fully functional perl package. This perl package is still dependant on Sugar for several abstracted features, but can be run anywhere with Sugar bundled to it. This package will be full functional and instantiable as so:

```perl
# we can instantiate it with a filepath
my $compiler = MyAwesomeCompiler->new(filepath => 'some_file.txt');
my $syntax_tree = $compiler->parse;

# alternatively we can pass text directly to the compiler
my $compiler = MyAwesomeCompiler->new(text => 'public class test {}');
my $syntax_tree = $compiler->parse;
```

This produced syntax tree can then be passed to a compiling backend as necessary.

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

keyword_token = /static|var|public|private|class/s
symbol_token = /\{|\}|;/s
identifier_token = /\w++/s
```

Then tell Sugar that these are your tokens. Order is important, as that is the order in which the regexs will be compiled together, so make sure that higher precendence tokens are first.
```perl
tokens {
	whitespace => $whitespace_token
	comment => $cstyle_comment_token

	keyword => $keyword_token
	symbol => $symbol_token
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

Now we declare our root context. We will be using a hash ref as the root of our syntax tree, so we declare root as an object context:
```perl
object context root {
	# we branch out into a switch to match multiple possibilities
	switch {
		# this case looks for a 'static' token, 'var' token, an identifier token, and a ';' token
		# it will only match if all of these properties are met
		'static', 'var', $identifier_token, ';' {
			# now that we've matched these tokens, we can refer to them using perl-like variables ($0, $1, $2, $3)
			# here we push the text of the identifier token we matched into a list under the property 'static_variables' of our object
			${'static_variables'}[] => $2
		}
		# this is case expects a 'public' token, a 'class' token, a token which matches the identifier regex, and finally a '{' token
		/public|private/, 'class', $identifier_token, '{' {
			# now that we've matched a class declaration, lets assign the values we have, and parse the variables list
			$_{'classes'}[] => {
				# to 'type' we assign a simple string
				'type' => 'class_definition'
				# to the access type, we assign the 'public' or 'private' we matched earlier
				'access_type' => $0
				# to 'class_name' we assign the identifier token which we matched earlier
				'class_name' => $2
				# we also call the class_variables context to produce a list of variables that belong to the class
				'variables' => !class_variables->[]
			}
			# finally we match the closing bracket of the class
			match '}'
		}
		# if we haven't matched any of the prior conditions, we want to display an error on the current line and leave
		default {
			die 'class declaration expected'
		}
	}
	# a context will loop until there are no more tokens left to parse
}
```

Since we are calling a 'class_variables' list context, we must define it as well:
```perl
list context class_variables {
	# while we have a 'var' token next, we can keep parsing variables
	while 'var' {
		# match the tokens we expect in a variable declaration
		match $identifier_token, ';'
		# now we can collect those tokens we matched into our list
		push $1
	}
	# return the list we have collected to the parent context
	return
}
```

There is way more stuff to learn, check out the [Sugar's own parser written in Sugar](../../grammar/sugar_grammar) for more information.
