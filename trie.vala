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
	internal string? leaf;
	internal HashMap<unichar, Node> branch;

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

	internal bool has_index(string word, long len, int index) {
		if (this.leaf != null)
			return word == this.leaf;
		else {
			unichar u;
			if (word.get_next_char(ref index, out u)) {
				Node subtrie = this.branch[u];
				if (subtrie == null)
					return false;
				else
					return subtrie.has_index(word, len, index);
			} else {
				Node subtrie = this.branch[0];
				return subtrie.leaf != null && subtrie.leaf == word;
			}
		}
	}

	internal void add_index(string word, long len, int index) {
		if (this.leaf != null) {
			string old_leaf = this.leaf;
			if (old_leaf == word)
				return;
			this.leaf = null;
			this.branch = new HashMap<unichar, Node>();
			this.add_index(old_leaf, old_leaf.length, index);
			this.add_index(word, len, index);
		} else {
			unichar u;
			if (word.get_next_char(ref index, out u)) {
				Node subtrie = this.branch[u];
				if (subtrie == null)
					this.branch[u] = new Node.from_leaf(word);
				else
					subtrie.add_index(word, len, index);
			} else if (index == len) {
				this.branch[u] = new Node.from_leaf(word);
			}
		}
	}

	internal void remove_index(string word, long len, int index) {
		if (this.leaf == null) {
			unichar u;
			if (word.get_next_char(ref index, out u)) {
				Node subtrie = this.branch[u];
				if (subtrie == null)
					return;
				subtrie.remove_index(word, len, index);
				if (subtrie.leaf == null && subtrie.branch == null)
					this.branch.unset(u);
			} else if (index == len)
				this.branch.unset(0);
			if (this.branch.size == 1) {
				Map.Entry<unichar, Node> e = this.branch.entries.to_array()[0];
				if (e.value.leaf != null) {
					this.leaf = e.value.leaf;
					this.branch = null;
				}
			}
		} else if (this.leaf == word) {
			this.leaf = null;
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

	public bool has(string word) {
		if (this.root == null)
			return false;
		else
			return this.root.has_index(word, word.length, 0);
	}

	public void add(string word) {
		if (this.root == null)
			this.root = new Node.from_leaf(word);
		else
			this.root.add_index(word, word.length, 0);
	}

	public void remove(string word) {
		if (this.root == null)
			return;
		this.root.remove_index(word, word.length, 0);
		if (this.root.leaf == null && this.root.branch == null)
			this.root = null;
	}
}

void test(Trie t, string expected) {
	string output = t.to_string();
	if (output != expected) {
		Test.message(output);
		Test.fail();
	}
}

public int main(string[] args) {
	Test.init(ref args);

	Test.add_func("/trie/empty", () => {
		Trie t = new Trie();
		assert(!t.has("foo"));
		test(t, "Trie(empty)");
	});

	Test.add_func("/trie/add_one", () => {
		Trie t = new Trie();
		t.add("foo");
		assert(t.has("foo"));
		test(t, "Trie(\"foo\")");
	});

	Test.add_func("/trie/add_multiple", () => {
		Trie t = new Trie();
		t.add("foo");
		t.add("bar");
		assert(t.has("foo"));
		assert(t.has("bar"));
		test(t, "Trie({f: \"foo\", b: \"bar\"})");
	});

	Test.add_func("/trie/add_multiple_with_duplicate", () => {
		Trie t = new Trie();
		t.add("foo");
		assert(t.has("foo"));
		t.add("bar");
		t.add("foo");
		assert(t.has("foo"));
		assert(t.has("bar"));
		test(t, "Trie({f: \"foo\", b: \"bar\"})");
	});

	Test.add_func("/trie/add_prefix", () => {
		Trie t = new Trie();
		t.add("foo");
		t.add("food");
		assert(t.has("foo"));
		assert(t.has("food"));
		test(t, "Trie({f: {o: {o: {: \"foo\", d: \"food\"}}}})");
	});

	Test.add_func("/trie/add_one_remove_one", () => {
		Trie t = new Trie();
		t.add("foo");
		t.remove("foo");
		assert(!t.has("foo"));
		test(t, "Trie(empty)");
	});

	Test.add_func("/trie/add_two_remove_one", () => {
		Trie t = new Trie();
		t.add("foo");
		t.add("bar");
		t.remove("foo");
		assert(!t.has("foo"));
		assert(t.has("bar"));
		test(t, "Trie(\"bar\")");
	});

	Test.add_func("/trie/add_three_remove_one", () => {
		Trie t = new Trie();
		t.add("foo");
		t.add("bar");
		t.add("baz");
		t.remove("bar");
		assert(t.has("foo"));
		assert(!t.has("bar"));
		assert(t.has("baz"));
		test(t, "Trie({f: \"foo\", b: \"baz\"})");
	});

	Test.add_func("/trie/remove_from_empty", () => {
		Trie t = new Trie();
		t.remove("foo");
		assert(!t.has("foo"));
		test(t, "Trie(empty)");
	});

	Test.add_func("/trie/add_three_remove_nonexistent", () => {
		Trie t = new Trie();
		t.add("foo");
		t.add("bar");
		t.add("baz");
		t.remove("bad");
		assert(t.has("foo"));
		assert(t.has("bar"));
		assert(t.has("baz"));
		assert(!t.has("bad"));
		test(t, "Trie({f: \"foo\", b: {a: {z: \"baz\", r: \"bar\"}}})");
	});

	return Test.run();
}
