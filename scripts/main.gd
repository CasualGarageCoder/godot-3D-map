extends Node3D

# Assumptions:
#   - None
# Contract:
#   - Noise will be clamped between -1 and 1. Height will be set between 0 and $height.

# Map size (in cells)
@export var size : Vector2i = Vector2i(32, 32)

# Maximum height of the heightmap
@export var height : float = 32

# Noise that shape the heightmap
@export var noise : Noise

# Mouse sensitivity
@export var mouse_sensitivity : Vector2 = Vector2(0.01, 0.01)

# Mouse zoom-in ratio
@export var mouse_zoom_in_ratio : float = 0.9

# Mouse zoom-out ratio
@export var mouse_zoom_out_ratio : float = 1.1

# Camera
@onready var camera : Camera3D = $Camera

# Map displaying cells.
@onready var map : MultiMeshInstance3D = $Map

# Heightmap
@onready var heightmap : PackedVector3Array = PackedVector3Array()
@onready var previous_heightmap : PackedVector3Array = PackedVector3Array()

# Min-Max height
@onready var boundaries : Array[float] = [0.0, 0.0]

# Index of the middle cell
@onready var midpoint : int

# Camera angles (Y, Z)
@onready var current_angles : Vector2 = Vector2.ZERO
@onready var angles : Vector2 = Vector2.ZERO

# Camera distance
@onready var current_distance : float = 32
@onready var distance : float = 32

# Camera midpoint
@onready var current_midpoint : Vector3 = Vector3.ZERO
@onready var mid_point : Vector3 = Vector3.ZERO

# Mouse is dragged
@onready var drag : bool

# ------------------------------------------------------------------------------

func _ready() -> void:
	camera.look_at_from_position(Vector3(0.0, size.x * 2.0, size.y * 2.0), Vector3.ZERO)
	init_heightmaps()
	generate_heightmap()
	reset_map()
	update_heightmap_instances()
	reset_camera()

# Control ----------------------------------------------------------------------

func _input(event : InputEvent) -> void:
	var update_camera : bool = false
	match event.get_class():
		"InputEventKey":
			# TODO Make smooth transition on camera height and with cell status.
			if event.pressed and not event.echo:
				match event.keycode:
					KEY_ENTER:
						if noise.has_method("set_seed"):
							var new_seed = randi()
							print("New seed : %d" % (new_seed))
							noise.set_seed(new_seed)
							generate_heightmap()
							update_heightmap_instances()
							#reset_transforms()
		"InputEventMouseButton":
			var bevent : InputEventMouseButton = event
			match bevent.button_index:
				MOUSE_BUTTON_LEFT:
					drag = bevent.pressed
				MOUSE_BUTTON_WHEEL_UP:
					distance *= mouse_zoom_in_ratio
					distance = max(1, distance)
					update_camera = true
				MOUSE_BUTTON_WHEEL_DOWN:
					distance *= mouse_zoom_out_ratio
					distance = min(max(size.x, size.y) * 5, distance)
			
		"InputEventMouseMotion":
			if drag:
				var mevent : InputEventMouseMotion = event
				var motion : Vector2 = mevent.relative * mouse_sensitivity
				angles += motion
				angles.y = clamp(angles.y, 0.0, PI/2 - 0.01)

# View -------------------------------------------------------------------------

func reset_camera() -> void:
	angles = Vector2.ZERO
	distance = max(size.x, size.y) * 3
	current_angles = angles
	current_distance = distance
	mid_point = Vector3(0.0, heightmap[midpoint].z, 0.0)

func update_camera() -> void:
	var t : Vector3 = Vector3(0.0, heightmap[midpoint].z, 0.0)
	var pos : Vector3 = Vector3(distance, 0, 0).rotated(Vector3(0.0, 0.0, 1.0), angles.y).rotated(Vector3.UP, angles.x)
	camera.look_at_from_position(pos, t)

func reset_transforms() -> void:
	if map == null or map.multimesh == null:
		return
	var instance_count : int = min(heightmap.size(), map.multimesh.get_instance_count())
	for i in range(instance_count):
		var transfo : Transform3D = Transform3D()
		transfo = transfo.scaled(Vector3(1.0, 1.0, 1.0)).translated(Vector3(heightmap[i].x - (size.x / 2.0), 1.0, heightmap[i].y - (size.y / 2.0)))
		map.multimesh.set_instance_transform(i, transfo)
	
# Initialize/Reset multimesh instance based on heightmap
func reset_map() -> void:
	var instance_count : int = size.x * size.y
	map.multimesh.set_instance_count(instance_count)
	reset_transforms()

func update_heightmap_instances() -> void:
	var point_count : int = size.x * size.y
	var middle : Vector2 = size / 2.0
	var max_dist : float = middle.length_squared()

	for i in range(point_count):
		var pos : Vector2 = Vector2(heightmap[i].x, heightmap[i].y)
		var dist : float = pos.distance_squared_to(middle) / max_dist
		map.multimesh.set_instance_custom_data(i, Color(dist, previous_heightmap[i].z, heightmap[i].z))
	get_tree().create_tween().tween_method(set_shader_progress, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func set_shader_progress(value : float) -> void:
	map.material_override.set_shader_parameter("progress", value)
	#map.set_instance_shader_parameter("progress", value)


# Model ------------------------------------------------------------------------

func _process(delta : float) -> void:
	current_midpoint = lerp(current_midpoint, mid_point, 0.09)
	current_angles = lerp(current_angles, angles, 0.09)
	current_distance = lerp(current_distance, distance, 0.09)
	
	var pos : Vector3 = Vector3(current_distance, 0, 0).rotated(Vector3(0.0, 0.0, 1.0), current_angles.y).rotated(Vector3.UP, current_angles.x)
	camera.look_at_from_position(pos, current_midpoint)

func init_heightmaps() -> void:
	var point_count : int = size.x * size.y
	heightmap.resize(point_count)
	previous_heightmap.resize(point_count)
	midpoint = (size.y / 2) * (size.x + size.x / 2)

	var idx : int = 0
	for y in range(size.y):
		for x in range(size.x):
			heightmap[idx] = Vector3(x, y, 0.)
			previous_heightmap[idx] = heightmap[idx]
			idx = idx + 1

# Generate heightmap based on noise
func generate_heightmap() -> void:
	var point_count : int = size.x * size.y

	var tmp : PackedVector3Array = heightmap
	heightmap = previous_heightmap
	previous_heightmap = tmp
	var idx : int = 0
	var max : float = 0
	for y in range(size.y):
		for x in range(size.x):
			var h : float = 0. if noise == null else ((clampf(noise.get_noise_2d(x, y), -1.0, 1.0) + 1.0) / 2.0) * height
			heightmap[idx].z = h
			max = max(max, h)
			idx = idx + 1
	map.material_override.set_shader_parameter("height", max)
