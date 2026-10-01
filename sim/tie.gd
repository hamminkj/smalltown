class_name Tie
extends RefCounted
## A relationship between two villagers.

enum Kind { FAMILY, WORK, NEIGHBOR, SCHOOL, MET }

var a: int
var b: int
var kind: int
var w: float          # tie strength, 0 to 1
var s := 0.5          # recent conversation success rate
var last_contact := 0
var talked_this_tick := false


func other(id: int) -> int:
	return b if id == a else a


static func key(x: int, y: int) -> String:
	return "%d_%d" % [mini(x, y), maxi(x, y)]
