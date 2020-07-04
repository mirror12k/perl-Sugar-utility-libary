#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

package Sugar::Lang::SugarsweetCompiler::Perl;
use parent 'Sugar::Lang::SugarsweetCompiler';

sub code_file_preamble {
	my ($self) = @_;
	return [ "#!/usr/bin/env perl", "use strict;", "use warnings;", "use feature 'say';", "" ];
}

sub code_file_postamble {
	my ($self) = @_;
	return [ "", "1;", "" ];
}

sub code_class_preamble {
	my ($self, $class_tree) = @_;
	my $class_name = join('::', @{$class_tree->{name}});
	my $code = [];
	push @{$code}, "package $class_name;";
	if ($class_tree->{parent_name}) {
		my $parent_name = join('::', @{$class_tree->{parent_name}});
		push @{$code}, "use parent '$parent_name';";
	}
	push @{$code}, "";
	return $code;
}

sub code_class_postamble {
	my ($self, $class_tree) = @_;
	return [];
}

sub code_constructor_preamble {
	my ($self, $function_tree) = @_;
	my $code = [];
	push @{$code}, "sub new {";
	if ((0 < scalar(@{$function_tree->{argument_list}}))) {
		my $argument_list = $self->compile_argument_list($function_tree->{argument_list});
		push @{$code}, "\tmy ($argument_list) = \@_;";
	}
	if ($self->{current_class_tree}->{parent_name}) {
		push @{$code}, "\t\$self = \$self->SUPER::new(\@_[1 .. \$#_]);";
	} else {
		push @{$code}, "\t\$self = bless {}, \$self;";
	}
	return $code;
}

sub code_constructor_postamble {
	my ($self, $function_tree) = @_;
	return [ "\treturn \$self;", "}", "" ];
}

sub code_function_preamble {
	my ($self, $function_tree) = @_;
	my $code = [];
	push @{$code}, "sub $function_tree->{name} {";
	if ((0 < scalar(@{$function_tree->{argument_list}}))) {
		my $argument_list = $self->compile_argument_list($function_tree->{argument_list});
		push @{$code}, "\tmy ($argument_list) = \@_;";
	}
	return $code;
}

sub code_function_postamble {
	my ($self, $function_tree) = @_;
	return [ "}", "" ];
}

sub is_my_native_function {
	my ($self, $function_tree) = @_;
	return ($function_tree->{native_type} eq 'perl5');
}

sub compile_native_function {
	my ($self, $function_tree) = @_;
	my $code = [];
	push @{$code}, "sub $function_tree->{name} {";
	if ((0 < scalar(@{$function_tree->{argument_list}}))) {
		my $argument_list = $self->compile_argument_list($function_tree->{argument_list});
		push @{$code}, "\tmy ($argument_list) = \@_;";
	}
	if (($function_tree->{block} =~ /\A\{\{(.*?)\}\}\Z/s)) {
		push @{$code}, $1;
	} else {
		die "failed to compile native block: $function_tree->{block}";
	}
	push @{$code}, "}";
	push @{$code}, "";
	if (($function_tree->{name} eq 'main')) {
		push @{$code}, 'caller or main(\@ARGV);';
		push @{$code}, '';
	}
	return $code;
}

sub main {
	my ($self) = @_;

	my ($files_list) = @_;

	# require Data::Dumper;
	require Sugar::IO::File;
	use Sugar::Lang::SugarsweetParser;

	my $parser = Sugar::Lang::SugarsweetParser->new;
	my $compiler = __PACKAGE__->new;
	foreach my $file (@$files_list) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		my $tree = $parser->parse;
		# say Dumper $tree;

		say $compiler->compile_file($tree);
	}

}

caller or main(\@ARGV);


1;

