class_name Iso
extends RefCounted

const TILE_W := 64.0
const TILE_H := 32.0
const ELEV := 44.0
const SEA_LEVEL := 0.38


static func lift(height: float, biome: String) -> float:
	if Biomes.is_water(biome):
		return 0.0
	return max(0.0, height - SEA_LEVEL) * ELEV + 4.0


static func project(tx: float, ty: float, lift_px: float = 0.0) -> Vector2:
	return Vector2((tx - ty) * TILE_W * 0.5, (tx + ty) * TILE_H * 0.5 - lift_px)


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
	return Vector2((a + b) * 0.5, (b - a) * 0.5)
