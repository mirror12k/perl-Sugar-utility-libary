package Sugar::IO::MinJSON;
use strict;
use warnings;

use feature 'say';

use base 'Exporter';

our @EXPORT = qw/
	minjson_parse
	minjson_serialize
/;




# minimalistic json spec
# only strings, objects, and arrays

# {obj:{},list:[],string:mine,list2:[asdf,"qwer"],"c":"d"}

# parsing pseudo code:

# parse_string(s, index)
# 	pstring = ""
# 	c = s[index]
# 	if (c == '"') {
# 		index++;
# 		while (c != '"') {
# 			if (c == '\\') {
# 				pstring += s[++index];
# 				c = s[++index];
# 			} else {
# 				pstring += c;
# 				c = s[++index];
# 			}
# 		}
# 		index++;
# 	} else {
# 		while (c != '{' and c != '}' and c != '[' and c != ']' and c != ':' and c != ',' and c != '"') {
# 			pstring += c;
# 			c = s[++index];
# 		}
# 	}
# 	return pstring, index;
# parse_expression(s, index)
# 	c = s[index];
# 	if (c == '{') {
# 		c = s[++index];
# 		obj = {};

# 		if (c == '}') {
# 			return obj, index + 1;
# 		}

# 		do {
# 			key, index = parse_string(s, index);
# 			c = s[index++];
# 			assert(c == ':');
# 			value, index = parse_expression(s, index);
# 			obj[key] = value;
# 			c = s[index++];
# 		} while (c == ',');

# 		assert(c == '}');
# 		return obj, index;
# 	} else if (c == '[') {
# 		c = s[++index];
# 		list = [];
		
# 		if (c == ']') {
# 			return list, index + 1;
# 		}

# 		do {
# 			value, index = parse_expression(s, index);
# 			list.push(value)
# 			c = s[index++];
# 		} while (c == ',');
# 		assert(c == ']');

# 		return list, index;
# 	} else {
# 		str, index = parse_string(s, index);
# 		return str, index;
# 	}


# serialize pseudo code:
# serialize (item) {
# 	if (item isa object) {
# 		list entries;
# 		foreach (key in item) {
# 			entries.push(serialize_string(key) + ":" + serialize(item[key]));
# 		}
# 		return join ",", entries;
# 	} else if (item isa list) {
# 		list entries;
# 		foreach (entry in item) {
# 			entries.push(serialize(entry));
# 		}
# 		return join ",", entries;
# 	} else {
# 		return serialize_string(item);
# 	}
# }

# serialize_string (str) {
# 	if (str.contains('{') or str.contains('}') or str.contains('[') or str.contains(']')
# 		or str.contains(':') or str.contains(',') or str.contains('"')) {
# 		str.replace('\\', "\\\\");
# 		str.replace('"', "\\\"");
# 		return '"' + str '"';
# 	} else {
# 		return str;
# 	}
# }



sub minjson_parse {
	my ($s) = @_;
	return parse_expression(\$s);
}


sub parse_string {
	my ($s) = @_;
	
	if ($$s =~ /\G"(([^"\\]|\\.)*+)"/gsc) {
		return $1 =~ s/\\(.)/$1/grs;
	} elsif ($$s =~ /\G([^\{\}\[\]:,"]*+)/gsc) {
		return $1;
	} else {
		die "invalid string: '$$s'";
	}
}

sub parse_expression {
	my ($s) = @_;
	if ($$s =~ /\G\{\}/gsc) {
		return {};
	} elsif ($$s =~ /\G\{/gsc) {
		my %obj;
		do {
			my $key = parse_string($s);
			die "missing ':' after key: '$$s'" unless $$s =~ /\G:/gsc;
			my $value = parse_expression($s);
			$obj{$key} = $value;
		} while ($$s =~ /\G,/gsc);
		die "missing '}' after value: '$$s'" unless $$s =~ /\G}/gsc;
		return \%obj;
	} elsif ($$s =~ /\G\[\]/gsc) {
		return [];
	} elsif ($$s =~ /\G\[/gsc) {
		my @list;
		do {
			my $value = parse_expression($s);
			push @list, $value;
		} while ($$s =~ /\G,/gsc);
		die "missing ']' after value: '$$s'" unless $$s =~ /\G]/gsc;
		return \@list;
	} else {
		return parse_string($s);
	}
}

sub minjson_serialize {
	my ($item) = @_;
	if (ref $item eq 'HASH') {
		my $s = join ",", map minjson_serialize("$_") . ":" . minjson_serialize($item->{$_}), keys %$item;
		return "{$s}";
	} elsif (ref $item eq 'ARRAY') {
		my $s =join ",", map minjson_serialize($_), @$item;
		return "[$s]";
	} else {
		return $item unless $item =~ /[\{\}\[\]:,"]/s;
		return '"' . ($item =~ s/([\\"])/\\$1/grs) . '"';
	}
}



# # my $input = '[asdf,"qwer, \\\\ \"lel",zxcv,{a:b,c:d,"asdf":"qwer",l:[1,2,3]}]';
# my $input = '{obj:{},list:[],string:mine,list2:[asdf,"qwer"],"c":"d"}';
# my $result = minjson_parse($input);
# say "input: $input";
# use Data::Dumper;
# say "result: ", Dumper $result;
# say "result: ", minjson_serialize({a => 2, c => 15, l => [1,2,3], s => "whos a [] what"});


1;
