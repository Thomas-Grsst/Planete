class_name Iso
extends RefCounted

const TILE_W := 64.0
const TILE_H := 32.0
const ELEV := 44.0
const SEA_LEVEL := 0.38

static var turn := 0


static func lift(height: float, biome: String) -> float:
	if Biomes.is_water(biome):
		return 0.0
	return max(0.0, height - SEA_LEVEL) * ELEV + 4.0


static func rotated(tx: float, ty: float) -> Vector2:
	match turn:
		1:
			return Vector2(ty, -tx)
		2:
			return Vector2(-tx, -ty)
		3:
			return Vector2(-ty, tx)
	return Vector2(tx, ty)


static func unrotated(r: Vector2) -> Vector2:
	match turn:
		1:
			return Vector2(-r.y, r.x)
		2:
			return Vector2(-r.x, -r.y)
		3:
			return Vector2(r.y, -r.x)
	return r


static func depth(tx: float, ty: float) -> float:
	var r := rotated(tx, ty)
	return r.x + r.y


static func screen_dir(d: Vector2i) -> Vector2i:
	var r := rotated(d.x, d.y)
	return Vector2i(roundi(r.x), roundi(r.y))


static func project(tx: float, ty: float, lift_px: float = 0.0) -> Vector2:
	var r := rotated(tx, ty)
	return Vector2((r.x - r.y) * TILE_W * 0.5, (r.x + r.y) * TILE_H * 0.5 - lift_px)


static func tile_lift(world: Dictionary, x: int, y: int) -> float:
	var t = WorldGen.tile_at(world, x, y)
	return 0.0 if t == null else lift(t["height"], t["biome"])


static func ground(world: Dictionary, tx: float, ty: float) -> Vector2:
	return project(tx, ty, lift_at(world, tx, ty))


static func lift_at(world: Dictionary, tx: float, ty: float) -> float:
	var x0 := int(floor(tx))
	var y0 := int(floor(ty))
	var fx := tx - x0
	var fy := ty - y0
	var a := tile_lift(world, x0, y0)
	var b := tile_lift(world, x0 + 1, y0)
	var c := tile_lift(world, x0, y0 + 1)
	var d := tile_lift(world, x0 + 1, y0 + 1)
	return lerp(lerp(a, b, fx), lerp(c, d, fx), fy)


static func unproject(pos: Vector2) -> Vector2:
	var a := pos.x / (TILE_W * 0.5)
	var b := pos.y / (TILE_H * 0.5)
	return unrotated(Vector2((a + b) * 0.5, (b - a) * 0.5))
