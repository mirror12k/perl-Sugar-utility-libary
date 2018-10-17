
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace Sugar.Lang {
	public class Token {
		public string type;
		public string value;
		public int line_number;
		public int offset;
	}

	public class DynamicValue {
		string type = null;
		string string_obj = null;
		List<DynamicValue> list_obj = null;
		Dictionary<string, DynamicValue> hash_obj = null;
		object userdata_obj = null;

		public DynamicValue(int obj) {
			type = "value";
			string_obj = "" + obj;
		}

		public DynamicValue(string obj) {
			type = "value";
			string_obj = obj;
		}

		public DynamicValue(List<DynamicValue> obj) {
			type = "list";
			list_obj = obj;
		}

		public DynamicValue(Dictionary<string, DynamicValue> obj) {
			type = "hash";
			hash_obj = obj;
		}

		public DynamicValue(string userdata_type, object obj) {
			type = "userdata";
			userdata_obj = obj;
		}

		public static implicit operator string (DynamicValue v) {
			if (v.type != "value")
				throw new Exception("attempt to use " + v.type + " DynamicValue as a value");
			return v.string_obj;
		}

		public static implicit operator int (DynamicValue v) {
			if (v.type != "value")
				throw new Exception("attempt to use " + v.type + " DynamicValue as a value");
			return Int32.Parse(v.string_obj);
		}

		public static implicit operator List<DynamicValue> (DynamicValue v) {
			if (v.type != "list")
				throw new Exception("attempt to use " + v.type + " DynamicValue as a list");
			return v.list_obj;
		}

		public static implicit operator List<string> (DynamicValue v) {
			if (v.type != "list")
				throw new Exception("attempt to use " + v.type + " DynamicValue as a list");

			List<string> vals = new List<string>();
			foreach (var obj in v.list_obj) {
				vals.Add(obj);
			}
			return vals;
		}

		public static implicit operator List<int> (DynamicValue v) {
			if (v.type != "list")
				throw new Exception("attempt to use " + v.type + " DynamicValue as a list");

			List<int> vals = new List<int>();
			foreach (var obj in v.list_obj) {
				vals.Add(obj);
			}
			return vals;
		}

		public static implicit operator Dictionary<string, DynamicValue> (DynamicValue v) {
			if (v.type != "hash")
				throw new Exception("attempt to use " + v.type + " DynamicValue as a hash");
			return v.hash_obj;
		}

		public static implicit operator Dictionary<string, string> (DynamicValue v) {
			if (v.type != "hash")
				throw new Exception("attempt to use " + v.type + " DynamicValue as a hash");
			Dictionary<string, string> vals = new Dictionary<string, string>();
			foreach (var key in v.hash_obj.Keys) {
				vals[key] = (string)v.hash_obj[key];
			}
			return vals;
		}

		public static explicit operator DynamicValue (string v) {
			return new DynamicValue(v);
		}

		public static explicit operator DynamicValue (int v) {
			return new DynamicValue("" + v);
		}

		public static explicit operator DynamicValue (List<DynamicValue> v) {
			return new DynamicValue(v);
		}

		public static explicit operator DynamicValue (List<string> v) {
			List<DynamicValue> objs = new List<DynamicValue>();
			foreach (var s in v) {
				objs.Add((DynamicValue)s);
			}
			return new DynamicValue(objs);
		}

		public static explicit operator DynamicValue (List<int> v) {
			List<DynamicValue> objs = new List<DynamicValue>();
			foreach (var s in v) {
				objs.Add((DynamicValue)s);
			}
			return new DynamicValue(objs);
		}

		public static explicit operator DynamicValue (Dictionary<string, DynamicValue> v) {
			return new DynamicValue(v);
		}

		public static explicit operator DynamicValue (Dictionary<string, string> v) {
			Dictionary<string, DynamicValue> objs = new Dictionary<string, DynamicValue>();
			foreach (var key in v.Keys) {
				objs[key] = (DynamicValue)v[key];
			}
			return new DynamicValue(objs);
		}

		public object AsUserdata() {
			if (type != "userdata")
				throw new Exception("attempt to use " + type + " DynamicValue as a userdata");
			return userdata_obj;
		}

		public DynamicValue this[int index] {
			get {
				if (type != "list")
					throw new Exception("attempt to use " + type + " DynamicValue as a list");
				return list_obj[index];
			}
			set {
				if (type != "list")
					throw new Exception("attempt to use " + type + " DynamicValue as a list");
				list_obj[index] = value;
			}
		}

		public DynamicValue this[string index] {
			get {
				if (type != "hash")
					throw new Exception("attempt to use " + type + " DynamicValue as a hash");
				if (!hash_obj.ContainsKey(index))
					throw new Exception("missing key in hash value: '" + index + "'");
				return hash_obj[index];
			}
			set {
				if (type != "hash")
					throw new Exception("attempt to use " + type + " DynamicValue as a hash");
				hash_obj[index] = value;
			}
		}

		public bool ContainsKey(string key) {
			if (type != "hash")
				throw new Exception("attempt to use " + type + " DynamicValue as a hash");
			return hash_obj.ContainsKey(key);
		}

		public void Add(DynamicValue val) {
			if (type != "list")
				throw new Exception("attempt to use " + type + " DynamicValue as a list");
			list_obj.Add(val);
		}

		public void Add(string val) {
			if (type != "list")
				throw new Exception("attempt to use " + type + " DynamicValue as a list");
			list_obj.Add((DynamicValue)val);
		}
	}

	public class Tokenizer {
		public string filepath;
		public string text;
		public List<string> token_regexes;
		public List<string> ignored_tokens;
		public string tokenizer_regex;

		public List<Token> tokens;
		public int tokens_index = 0;

		// public static void Main(string[] args) {
		// 	var tok = new Tokenizer("test.dat", "", new List<string>{"word", @"\w+", "space", @"\s+"}, new List<string>{});
		// 	tok.Parse();

		// 	Console.WriteLine("is token word?" + tok.IsTokenType("word"));
		// 	Console.WriteLine("is token space?" + tok.IsTokenType("space"));
		// 	Console.WriteLine("is token hello?" + tok.IsTokenVal("*", "hello"));
		// 	// tok.AssertTokenType("space");
		// 	Console.WriteLine(tok.DumpAtCurrentOffset());
		// }

		public Tokenizer(string filepath, string text, List<string> token_regexes, List<string> ignored_tokens) {
			this.filepath = filepath;
			this.text = text;
			this.token_regexes = token_regexes;
			this.ignored_tokens = ignored_tokens;

			CompileTokenizerRegex();
		}

		public void CompileTokenizerRegex() {
			List<string> token_pieces = new List<string>();
			for (int i = 0; i < token_regexes.Count; i+=2) {
				token_pieces.Add("(?<" + token_regexes[i] + ">" + token_regexes[i+1] + ")");
			}
			tokenizer_regex = string.Join("|", token_pieces.ToArray());
		}

		public virtual Object Parse() {
			string data_text;
			if (filepath != "") {
				data_text = System.IO.File.ReadAllText(filepath);
			} else {
				data_text = text;
			}

			return ParseTokens(data_text);
		}

		public List<Token> ParseTokens(string data_text) {
			text = data_text;


			int line_number = 1;
			int offset = 0;

			var pattern = @"\G(?:" + tokenizer_regex + ")";
			Console.WriteLine("pattern: " + pattern);

			var regex = new Regex(pattern, RegexOptions.Singleline);
			// Console.WriteLine("regex.GroupNameFromNumber(1): " + regex.GroupNameFromNumber(1));
			// Console.WriteLine("regex.GroupNameFromNumber(2): " + regex.GroupNameFromNumber(2));
			Match match = regex.Match(text);

			List<Token> parsed_tokens = new List<Token>();
			while (match.Success) {
				foreach (var name in regex.GetGroupNames()) {
					if (name != "0" && match.Groups[name].Value != "") {
						Console.WriteLine("match: " + name + " => " + match.Groups[name].Value);
						parsed_tokens.Add(new Token {
							type=name,
							value=match.Groups[name].Value,
							line_number=line_number,
							offset=offset,
						});
						break;
					}
				}

				offset = match.Index + match.Value.Length;
				line_number += match.Value.Length - match.Value.Replace("\n", string.Empty).Length;
				// Console.WriteLine("offset line_number: " + offset + ", " + line_number);

				// Console.WriteLine("group: " + match.Groups[1].Index + " => " + match.Groups[1].Value);
				match = match.NextMatch();
			}

			if (offset != text.Length) {
				throw new Exception("parsing error on line " + line_number + ":\nHERE ---->"
					+ text.Substring(offset, (text.Length - offset > 200 ? 200 : text.Length - offset)));
			}
			// confess "parsing error on line $line_number:\nHERE ---->" . substr ($text, pos $text // 0, 200) . "\n\n\n"
			// 		if not defined pos $text or pos $text != length $text;

			List<Token> filtered_tokens = new List<Token>();
			foreach (var token in parsed_tokens) {
				if (!ignored_tokens.Contains(token.type)) {
					filtered_tokens.Add(token);
				}
			}

			filtered_tokens = FilterTokens(filtered_tokens);
			tokens = filtered_tokens;
			tokens_index = 0;

			return tokens;
		}

		public virtual List<Token> FilterTokens(List<Token> my_tokens) {
			return my_tokens;
		}

		public bool MoreTokens(int offset=0) {
			return tokens_index + offset < tokens.Count;
		}

		public Token PeekToken() {
			if (!MoreTokens()) {
				return null;
			}
			return tokens[tokens_index];
		}

		public Token NextToken() {
			if (!MoreTokens()) {
				return null;
			}
			return tokens[tokens_index++];
		}

		public List<Token> StepTokens(int count) {
			var stepped = tokens.GetRange(tokens_index, count);
			tokens_index += count;
			return stepped;
		}


		public bool IsTokenType(string type, int offset=0) {
			if (!MoreTokens()) {
				return false;
			}
			return tokens[tokens_index + offset].type == type;
		}

		public bool IsTokenVal(string type, string val, int offset=0) {
			if (!MoreTokens()) {
				return false;
			}
			var token = tokens[tokens_index + offset];
			return (type == "*" || token.type == type) && token.value == val;
		}

		public bool IsTokenVal(string type, Regex val, int offset=0) {
			if (!MoreTokens()) {
				return false;
			}
			var token = tokens[tokens_index + offset];
			return (type == "*" || token.type == type) && val.IsMatch(token.value);
		}

		public void AssertTokenType(string type, int offset=0) {
			if (!IsTokenType(type, offset)) {
				ConfessAtCurrentOffset("expected token type " + type
					+ (offset > 0 ? " (at offset " + offset + ")" : ""));
			}
		}

		public void AssertTokenVal(string type, string val, int offset=0) {
			if (!IsTokenVal(type, val, offset)) {
				ConfessAtCurrentOffset("expected token type " + type + " with value '" + val + "'"
					+ (offset > 0 ? " (at offset " + offset + ")" : ""));
			}
		}

		public void AssertTokenVal(string type, Regex val, int offset=0) {
			if (!IsTokenVal(type, val, offset)) {
				ConfessAtCurrentOffset("expected token type " + type + " with value '" + val + "'"
					+ (offset > 0 ? " (at offset " + offset + ")" : ""));
			}
		}

		public Token AssertStepTokenType(string type) {
			AssertTokenType(type);
			return NextToken();
		}

		public Token AssertStepTokenVal(string type, string val) {
			AssertTokenVal(type, val);
			return NextToken();
		}

		public Token AssertStepTokenVal(string type, Regex val) {
			AssertTokenVal(type, val);
			return NextToken();
		}

		public void ConfessAtCurrentOffset(string msg) {
			string position;
			string next_token = "";
			if (MoreTokens()) {
				var token = PeekToken();
				position = "line " + token.line_number;
				next_token = " (next token is " + token.type + " => <" + token.value + ">)";
			} else {
				position = "end of file";
			}

			// say $self->dump_at_current_offset;

			throw new Exception("error on " + position + ": " + msg + next_token);
		}

		public int CurrentLineNumber() {
			var index = 0;
			while (MoreTokens(index)) {
				if (!IsTokenType("whitespace")) {
					return tokens[tokens_index + index].line_number;
				}
				index++;
			}
			return -1;
		}


		public string Dump() {
			List<string> strings = new List<string>();
			foreach (var token in tokens) {
				strings.Add("[" + token.line_number + ":" + token.offset + "] " + token.type + " => <" + token.value + ">");
			}
			return string.Join("\n", strings.ToArray());
		}

		public string DumpAtCurrentOffset() {
			List<string> strings = new List<string>();
			for (int index = tokens_index; index < tokens.Count; index++) {
				var token = tokens[index];
				strings.Add("[" + token.line_number + ":" + token.offset + "] " + token.type + " => <" + token.value + ">");
			}
			return string.Join("\n", strings.ToArray());
		}
	}

	public abstract class BaseSyntaxParser : Tokenizer {
		public DynamicValue syntax_tree = null;

		public BaseSyntaxParser(string filepath, string text, List<string> token_regexes, List<string> ignored_tokens)
			: base(filepath, text, token_regexes, ignored_tokens) {}

		public override Object Parse() {
			base.Parse();

			syntax_tree = context_root(null);
			if (MoreTokens()) {
				ConfessAtCurrentOffset("more tokens after parsing complete");
			}
			return syntax_tree;
		}

		public abstract DynamicValue context_root(DynamicValue context_value=null);
	}
}


