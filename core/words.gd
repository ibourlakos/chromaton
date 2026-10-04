## The journal's Words: the player's lexicon, read from data/words.json
## (written by `.\make words` from docs/lexicon/, tools/lexicon.gd).
##
## Each word is {"id", "word", "text", "level", "tab"}: the lexicon file's
## name, the word as the player sees it, its Gameplay text (paragraphs split
## by a blank line), the level whose solve unlocks it and the journal tab with
## its fuller page ("" for none). In unlock order.
extends RefCounted

const PATH := "res://data/words.json"

static var _cache: Array = []


static func load_all() -> Array:
	if not _cache.is_empty():
		return _cache
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("cannot read " + PATH)
		return []
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary and d.get("words") is Array):
		push_error("cannot read " + PATH)
		return []
	_cache = d["words"]
	return _cache


## A word is unlocked once the level that introduces it is solved.
static func is_unlocked(word: Dictionary, progress) -> bool:
	return progress.unlock_all or progress.is_solved(str(word["level"]))


## The words a level's first solve unlocks.
static func unlocked_by(level_id: String) -> Array:
	return load_all().filter(func(w): return w["level"] == level_id)


static func find(id: String) -> Dictionary:
	for w in load_all():
		if w["id"] == id:
			return w
	return {}
