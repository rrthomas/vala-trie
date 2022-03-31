trie: trie.vala
	valac --pkg gee-0.8 trie.vala

check: trie
	./trie
