trie: trie.vala
	valac --debug --pkg gee-0.8 trie.vala

check: trie
	./trie
