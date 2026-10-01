class_name Place
extends RefCounted
## A location villagers can be at: a home, workplace, school, or public space.

var id: int
var title: String
var kind: String            # "home", "work", "school", "public"
var pos := Vector2.ZERO     # map coordinates in an 800 x 720 design space
var box := Vector2(120, 70)
var built := true
var buildable := false      # an empty lot the player can build on
var home_lang := ""         # for homes: the household's language
var event_start := -1       # tick when the current event begins
var event_until := -1       # tick when the current event ends
var event_theme := ""       # "mixer" or "heritage"
var signs: Array = []       # [{concept, variant, source}]


## The language people expect to use here when both options are about equal.
func norm_lang(tick: int = -1) -> String:
	if kind == "home" and home_lang != "":
		return home_lang
	if tick >= 0 and has_event(tick) and event_theme == "heritage":
		return "H"
	return "T"


func has_event(tick: int) -> bool:
	return tick >= event_start and tick < event_until


## True while an event is scheduled or running (so it can't be booked twice).
func event_booked(tick: int) -> bool:
	return tick < event_until
