class_name World
extends RefCounted


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	Disasters.step(state, rng, census)
	Raiders.step(state, rng, census)
	Wonders.step(state, rng, census)
	Social.step(state, rng, census)
	Languages.step(state, rng, census)
