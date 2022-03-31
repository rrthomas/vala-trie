using GLib;
using Gee;

[CCode (has_target = false)]
delegate string ToStringFunc<T>(T t);

string hash_map_to_string<K, V>(
	HashMap<K, V> h,
	ToStringFunc<K> k_to_string,
	ToStringFunc<V> v_to_string
) {
	StringBuilder sb = new StringBuilder();
	sb.append("{");
	string sep = "";
	foreach (Map.Entry<K, V> e in h.entries) {
		sb.append(@"$sep$(k_to_string(e.key)): $(v_to_string(e.value))");
		sep = ", ";
	}
	sb.append("}");
	return sb.str;
}

private class Node {
	string? leaf;
	HashMap<unichar, Node> branch;

	private Node() {} // Forbid construction with no fields.

	public Node.from_leaf(string leaf) {
		this.leaf = leaf;
	}

	private Node.from_branch() {
		this.branch = new HashMap<unichar, Node>();
	}

	internal string to_string() {
		if (this.leaf != null)
			return @"\"$(this.leaf)\"";
		return hash_map_to_string<unichar, Node>(
			this.branch,
			(a) => { return a.to_string(); },
			(a) => { return a.to_string(); }
		);
	}

	internal void add_pos(string word, long pos) {
		if (leaf != null) {
			string tmp = this.leaf;
			if (tmp == word)
				return;
			this.leaf = null;
			this.branch = new HashMap<unichar, Node>();
			this.add_pos(tmp, pos);
			this.add_pos(word, pos);
		} else {
			unichar u = word[pos];
			Node subtrie = this.branch[u];
			if (subtrie == null)
				this.branch[u] = new Node.from_leaf(word);
			else
				subtrie.add_pos(word, pos + 1);
		}
	}
}

public class Trie {
	Node? root;

	public string to_string() {
		if (this.root == null)
			return "Trie(empty)";
		else
			return @"Trie($(this.root.to_string()))";
	}

	public void add(string word) {
		if (this.root == null)
			this.root = new Node.from_leaf(word);
		else
			this.root.add_pos(word, 0);
	}
}

public static int main(string[] args) {
	Test.init(ref args);

	Test.add_func("/trie/add_one", () => {
		Trie t = new Trie();
		t.add("foo");
		string s = t.to_string();
		if (s != "Trie(\"foo\")") {
			Test.message(s);
			Test.fail();
		}
	});

	Test.add_func("/trie/add_multiple", () => {
		Trie t = new Trie();
		t.add("foo");
		t.add("bar");
		string s = t.to_string();
		if (s != "Trie({f: \"foo\", b: \"bar\"})") {
			Test.message(s);
			Test.fail();
		}
	});

	Test.add_func("/trie/add_multiple_with_duplicate", () => {
		Trie t = new Trie();
		t.add("foo");
		t.add("bar");
		t.add("foo");
		string s = t.to_string();
		if (s != "Trie({f: \"foo\", b: \"bar\"})") {
			Test.message(s);
			Test.fail();
		}
	});

	Test.add_func("/trie/add_prefix", () => {
		Trie t = new Trie();
		t.add("foo");
		t.add("food");
		string s = t.to_string();
		if (s != "Trie({f: {o: {o: {: \"foo\", d: \"food\"}}}})") {
			Test.message(s);
			Test.fail();
		}
	});

	return Test.run();
}
