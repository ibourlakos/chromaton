## Reads the lexicon (docs/lexicon/*.md) and builds the journal's Words data:
## every term tagged gameplay, with its player word, its Gameplay paragraph,
## the level that unlocks it and the journal tab with its page.
##
## Used by tools/make_words.gd (writes data/words.json) and the journal test
## (fails when the file and the lexicon drift apart). Not shipped: docs/ is
## left out of the export, data/words.json is what the game reads.
##
## What a term's file must give (docs/lexicon/lexicon.md):
##   # <Term>
##   - **Tags:** gameplay, ...
##   - **Player word:** <word>            (optional; else the term)
##   - **Journal:** unlocks in <Level name>; page on the <Tab> tab
##   ## Gameplay
##   <paragraphs>
## The level is matched by its name in levels/*.json, so renaming a level
## without updating the lexicon fails here instead of locking a word for good.
extends RefCounted

const Level = preload("res://core/level.gd")

const DIR := "res://docs/lexicon"
const OUT := "res://data/words.json"
const TABS := ["paint", "loom", "pieces", "inventions", "cloths", "scores", "words"]


## {"words": [...], "errors": [...]}. Words are in unlock order (campaign
## order of their levels), then alphabetical.
static func build(levels: Array) -> Dictionary:
	var words := []
	var errors := []
	var names := DirAccess.get_files_at(DIR)
	for file in names:
		if not file.ends_with(".md") or file == "lexicon.md":
			continue
		var f := FileAccess.open(DIR + "/" + file, FileAccess.READ)
		if f == null:
			errors.append("cannot read " + file)
			continue
		var w := parse(file.trim_suffix(".md"), f.get_as_text(), levels)
		if w.has("error"):
			errors.append("%s: %s" % [file, w["error"]])
		elif not w.is_empty():
			words.append(w)
	var order := {}
	for i in levels.size():
		order[levels[i].id] = i
	words.sort_custom(func(a, b):
		if order[a["level"]] != order[b["level"]]:
			return order[a["level"]] < order[b["level"]]
		return a["word"] < b["word"])
	return {"words": words, "errors": errors}


## One term: {} when it isn't tagged gameplay, {"error": ...} when it can't be read.
static func parse(id: String, text: String, levels: Array) -> Dictionary:
	var lines := text.replace("\r", "").split("\n")
	var term := ""
	var header := {}
	var gameplay := []
	var section := ""
	for line in lines:
		if line.begins_with("# ") and term == "":
			term = line.substr(2).strip_edges()
		elif line.begins_with("## "):
			section = line.substr(3).strip_edges()
		elif section == "" and line.begins_with("- **"):
			var close := line.find(":**")
			if close > 4:
				header[line.substr(4, close - 4)] = line.substr(close + 3).strip_edges()
		elif section == "Gameplay":
			gameplay.append(line)
	var tags := str(header.get("Tags", ""))
	if not "gameplay" in _tags(tags):
		return {}
	var journal := str(header.get("Journal", ""))
	var level := _level_in(journal, levels)
	if level == "":
		return {"error": "its Journal line names no level (\"unlocks in <Level name>\"): " + journal}
	var paragraphs := []
	for p in "\n".join(gameplay).strip_edges().split("\n\n"):
		var s := plain(p.replace("\n", " ").strip_edges())
		if s != "":
			paragraphs.append(s)
	if paragraphs.is_empty():
		return {"error": "no Gameplay paragraph"}
	var word := str(header.get("Player word", term))
	return {"id": id, "word": plain(word), "text": "\n\n".join(paragraphs), "level": level, "tab": _tab_in(journal)}


static func _tags(s: String) -> Array:
	var out := []
	for t in s.split(","):
		out.append(t.strip_edges().split(" ")[0])
	return out


## The level named right after "unlocks in" (the longest name that fits).
static func _level_in(journal: String, levels: Array) -> String:
	var at := journal.find("unlocks in ")
	if at < 0:
		return ""
	var rest := journal.substr(at + "unlocks in ".length())
	var found := ""
	var length := 0
	for level in levels:
		var n: String = level.name
		if rest.begins_with(n) and n.length() > length:
			var after := rest.substr(n.length(), 1)
			if after == "" or after in [";", ",", " ", "."]:
				found = level.id
				length = n.length()
	return found


## The tab named first as "the <Tab> tab", or "".
static func _tab_in(journal: String) -> String:
	var re := RegEx.new()
	re.compile("the (\\w+) tab")
	for m in re.search_all(journal):
		var t := m.get_string(1).to_lower()
		if t in TABS:
			return t
	return ""


## Markdown to plain text: links keep their words, emphasis marks go.
static func plain(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\[([^\\]]+)\\]\\([^)]*\\)")
	s = re.sub(s, "$1", true)
	s = s.replace("**", "").replace("`", "")
	re.compile("(^|[^\\w])\\*([^*]+)\\*")
	s = re.sub(s, "$1$2", true)
	return s


## The data file's text, as make_words writes it.
static func to_json(words: Array) -> String:
	return JSON.stringify({"words": words}, "\t") + "\n"
