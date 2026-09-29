class_name Rng
extends RefCounted

const MASK := 0xFFFFFFFF

var state: int = 0


func _init(seed_value: int = 0) -> void:
	state = seed_value & MASK


static func imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var high := (((a >> 16) * b) & 0xFFFF) << 16
	return (high + (a & 0xFFFF) * b) & MASK


static func hash_string(text: String) -> int:
	var h := 2166136261
	for i in text.length():
		h ^= text.unicode_at(i)
		h = imul(h, 16777619)
	return h & MASK


func next() -> float:
	state = (state + 0x6D2B79F5) & MASK
	var t := state
	t = imul(t ^ (t >> 15), t | 1)
	t ^= (t + imul(t ^ (t >> 7), t | 61)) & MASK
	return float((t ^ (t >> 14)) & MASK) / 4294967296.0


func range_int(low: int, high: int) -> int:
	return low + int(floor(next() * (high - low + 1)))


func chance(p: float) -> bool:
	return next() < p


func pick(items: Array):
	if items.is_empty():
		return null
	return items[int(floor(next() * items.size()))]
