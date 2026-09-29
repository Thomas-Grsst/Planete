extends Camera2D

signal tapped(world_pos: Vector2)

const MIN_ZOOM := 0.35
const MAX_ZOOM := 4.0
const TAP_SLOP := 12.0
const GLIDE := 8.0

var target_zoom := 3.0
var target_pos := Vector2.ZERO
var _touches := {}
var _press_pos := Vector2.ZERO
var _moved := false
var _pinch_start := 0.0
var _pinch_zoom := 1.0
var _dragging_mouse := false
var _shake := 0.0


func _ready() -> void:
	zoom = Vector2.ONE * target_zoom
	target_pos = position


func shake(amount: float) -> void:
	_shake = max(_shake, amount)


func focus(world_pos: Vector2) -> void:
	target_pos = world_pos


func jump(world_pos: Vector2) -> void:
	target_pos = world_pos
	position = world_pos


func _process(delta: float) -> void:
	var k: float = clamp(delta * GLIDE, 0.0, 1.0)
	position = position.lerp(target_pos, k)
	zoom = zoom.lerp(Vector2.ONE * target_zoom, k)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_shake = move_toward(_shake, 0.0, delta * 8.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion and _dragging_mouse:
		if event.position.distance_to(_press_pos) > TAP_SLOP:
			_moved = true
		_pan(event.relative)
	elif event is InputEventScreenTouch:
		_touch(event)
	elif event is InputEventScreenDrag:
		_drag(event)
	elif event is InputEventMagnifyGesture:
		target_zoom = clamp(target_zoom * event.factor, MIN_ZOOM, MAX_ZOOM)


func _mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		target_zoom = clamp(target_zoom * 1.12, MIN_ZOOM, MAX_ZOOM)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		target_zoom = clamp(target_zoom / 1.12, MIN_ZOOM, MAX_ZOOM)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_mouse = event.pressed
		if event.pressed:
			_press_pos = event.position
			_moved = false
		elif not _moved:
			tapped.emit(get_canvas_transform().affine_inverse() * event.position)


func _pan(relative: Vector2) -> void:
	target_pos -= relative / zoom.x
	position = target_pos


func _touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		_press_pos = event.position
		_moved = _touches.size() > 1
		if _touches.size() == 2:
			var pts: Array = _touches.values()
			_pinch_start = pts[0].distance_to(pts[1])
			_pinch_zoom = target_zoom
		return
	_touches.erase(event.index)
	if _touches.is_empty() and not _moved and event.position.distance_to(_press_pos) < TAP_SLOP:
		tapped.emit(get_canvas_transform().affine_inverse() * event.position)


func _drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		var pts: Array = _touches.values()
		var d: float = pts[0].distance_to(pts[1])
		if _pinch_start > 0:
			target_zoom = clamp(_pinch_zoom * d / _pinch_start, MIN_ZOOM, MAX_ZOOM)
		return
	if event.position.distance_to(_press_pos) > TAP_SLOP:
		_moved = true
	_pan(event.relative)
