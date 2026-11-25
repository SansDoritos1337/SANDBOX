extends Node3D

## Mały, fizyczny plac zabaw: sterujesz jedną kulką, a resztę robi Godot Physics.
const BALL_RADIUS := 0.65
const ARENA_HALF := 16.0
const DRIVE_FORCE := 38.0

var ball: RigidBody3D
var camera: Camera3D
var score_label: Label
var message_label: Label
var boost_cooldown := 0.0
var message_time := 0.0
var score := 0
var jump_was_down := false
var boost_was_down := false
var reset_was_down := false


func _ready() -> void:
	_build_world()
	_build_arena()
	_build_bumpers()
	_build_ball()
	_build_camera()
	_build_hud()
	_show_message("Rozpędź się i odbijaj od neonowych bumperów!")


func _process(delta: float) -> void:
	if ball == null or camera == null:
		return
	var camera_target := ball.global_position + Vector3(0.0, 10.5, 14.0)
	camera.global_position = camera.global_position.lerp(camera_target, minf(delta * 4.5, 1.0))
	camera.look_at(ball.global_position, Vector3.UP)
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_label.visible = false
	_update_hud()


func _physics_process(delta: float) -> void:
	if ball == null:
		return
	boost_cooldown = maxf(0.0, boost_cooldown - delta)

	var drive := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		drive.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		drive.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		drive.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		drive.x += 1.0
	if drive.length_squared() > 0.0:
		drive = drive.normalized()
		# Siła przyłożona przy spodzie kuli wywołuje toczenie zamiast ślizgania.
		ball.apply_force(drive * DRIVE_FORCE, Vector3.DOWN * (BALL_RADIUS * 0.8))

	var jump_down := Input.is_key_pressed(KEY_SPACE)
	if jump_down and not jump_was_down and ball.get_contact_count() > 0:
		ball.apply_central_impulse(Vector3.UP * 8.0)
	jump_was_down = jump_down

	var boost_down := Input.is_key_pressed(KEY_SHIFT)
	if boost_down and not boost_was_down and boost_cooldown <= 0.0:
		var boost_direction := drive
		if boost_direction == Vector3.ZERO:
			boost_direction = Vector3(0.0, 0.0, -1.0)
		ball.apply_central_impulse(boost_direction * 9.0 + Vector3.UP * 1.8)
		boost_cooldown = 1.1
	boost_was_down = boost_down

	var reset_down := Input.is_key_pressed(KEY_R)
	if reset_down and not reset_was_down:
		_reset_ball()
	reset_was_down = reset_down

	# Automatyczny powrót, jeśli kulka wypadnie poza planszę.
	if ball.global_position.y < -12.0:
		_reset_ball()


func _build_world() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#10182e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9bb6ff")
	environment.ambient_light_energy = 0.55
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#d9e5ff")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)


func _build_arena() -> void:
	var floor_material := _material(Color("#18243d"), 0.32, 0.25)
	var rail_material := _material(Color("#33466f"), 0.25, 0.45)
	var trim_material := _material(Color("#43d9ff"), 0.24, 0.25, Color("#0a9dff"))
	_add_box("Podłoga", Vector3(0.0, -0.5, 0.0), Vector3(32.0, 1.0, 32.0), floor_material)

	# Subtelna siatka nadaje planszy skalę i pomaga ocenić ruch.
	var grid_material := _material(Color("#263958"), 0.4, 0.1)
	for i in range(-14, 15, 2):
		_add_visual_box("Linia siatki", Vector3(float(i), 0.012, 0.0), Vector3(0.025, 0.012, 31.0), grid_material)
		_add_visual_box("Linia siatki", Vector3(0.0, 0.012, float(i)), Vector3(31.0, 0.012, 0.025), grid_material)

	_add_box("Północna bariera", Vector3(0.0, 0.6, -ARENA_HALF), Vector3(32.0, 2.2, 0.7), rail_material)
	_add_box("Południowa bariera", Vector3(0.0, 0.6, ARENA_HALF), Vector3(32.0, 2.2, 0.7), rail_material)
	_add_box("Lewa bariera", Vector3(-ARENA_HALF, 0.6, 0.0), Vector3(0.7, 2.2, 32.0), rail_material)
	_add_box("Prawa bariera", Vector3(ARENA_HALF, 0.6, 0.0), Vector3(0.7, 2.2, 32.0), rail_material)

	# Niskie, ukośne rampy dają się podbijać i zeskakiwać z nich.
	_add_box("Rampa A", Vector3(-10.0, 0.25, -5.0), Vector3(7.0, 0.65, 4.0), trim_material, Vector3(0.0, 0.0, -0.16))
	_add_box("Rampa B", Vector3(10.0, 0.25, 5.0), Vector3(7.0, 0.65, 4.0), trim_material, Vector3(0.0, 0.0, 0.16))
	_add_box("Platforma", Vector3(0.0, 0.55, -10.0), Vector3(7.0, 0.5, 3.5), rail_material)


func _build_bumpers() -> void:
	var bumper_positions: Array[Vector3] = [
		Vector3(-6.0, 0.55, -2.0), Vector3(6.0, 0.55, 2.0),
		Vector3(0.0, 0.55, 5.0), Vector3(-3.0, 0.55, 10.0),
		Vector3(10.0, 0.55, -8.0), Vector3(-10.0, 0.55, 7.0),
	]
	for index in range(bumper_positions.size()):
		var center: Vector3 = bumper_positions[index]
		var color := Color.from_hsv(float(index) / 6.0, 0.72, 1.0)
		var bumper_material := _material(color, 0.22, 0.35, color * 0.65)
		var bumper := StaticBody3D.new()
		bumper.name = "Bumper_%d" % index
		bumper.position = center
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.82
		cylinder.bottom_radius = 0.92
		cylinder.height = 1.25
		var bumper_mesh := MeshInstance3D.new()
		bumper_mesh.mesh = cylinder
		bumper_mesh.material_override = bumper_material
		bumper.add_child(bumper_mesh)
		var bumper_shape := CollisionShape3D.new()
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = 0.9
		cylinder_shape.height = 1.25
		bumper_shape.shape = cylinder_shape
		bumper.add_child(bumper_shape)
		add_child(bumper)

		var glow_area := Area3D.new()
		glow_area.position = center
		var glow_shape := CollisionShape3D.new()
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = 1.35
		glow_shape.shape = sphere_shape
		glow_area.add_child(glow_shape)
		glow_area.body_entered.connect(_on_bumper_touched.bind(center))
		add_child(glow_area)

		# Emisyjny pierścień jest dekoracją, nie osobną kulą fizyczną.
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.96
		ring_mesh.outer_radius = 1.04
		ring.mesh = ring_mesh
		ring.material_override = _material(color, 0.2, 0.1, color)
		ring.position = center + Vector3(0.0, 0.03, 0.0)
		ring.rotation_degrees.x = 90.0
		add_child(ring)


func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.name = "JedynaKulka"
	ball.position = Vector3(0.0, 2.8, 0.0)
	ball.mass = 1.4
	ball.linear_damp = 0.12
	ball.angular_damp = 0.08
	ball.continuous_cd = true
	ball.contact_monitor = true
	ball.max_contacts_reported = 8
	ball.physics_material_override = PhysicsMaterial.new()
	ball.physics_material_override.friction = 0.72
	ball.physics_material_override.bounce = 0.38
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = BALL_RADIUS
	sphere_mesh.height = BALL_RADIUS * 2.0
	var ball_mesh := MeshInstance3D.new()
	ball_mesh.mesh = sphere_mesh
	ball_mesh.material_override = _material(Color("#f5fbff"), 0.12, 0.55, Color("#43d9ff"))
	ball.add_child(ball_mesh)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = BALL_RADIUS
	collider.shape = shape
	ball.add_child(collider)
	add_child(ball)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Kamera"
	camera.position = Vector3(0.0, 10.5, 14.0)
	camera.fov = 58.0
	camera.current = true
	add_child(camera)
	camera.look_at(ball.global_position, Vector3.UP)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	score_label = Label.new()
	score_label.position = Vector2(24.0, 18.0)
	score_label.add_theme_font_size_override("font_size", 26)
	score_label.add_theme_color_override("font_color", Color("#f4f8ff"))
	layer.add_child(score_label)

	var controls := Label.new()
	controls.position = Vector2(24.0, 62.0)
	controls.text = "WASD / strzałki — toczenie   •   SPACJA — skok   •   SHIFT — dopalacz   •   R — reset"
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_color", Color("#b9c9e8"))
	layer.add_child(controls)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-300.0, 108.0)
	message_label.size = Vector2(600.0, 42.0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", Color("#7deaff"))
	layer.add_child(message_label)


func _add_box(label: String, position: Vector3, size: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position
	body.rotation = rotation
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	add_child(body)


func _add_visual_box(label: String, position: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.position = position
	visual.mesh = mesh
	visual.material_override = material
	add_child(visual)


func _material(color: Color, roughness: float, metallic: float, emission_color: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission_color != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission_color
	return material


func _on_bumper_touched(body: Node3D, center: Vector3) -> void:
	if body != ball:
		return
	var away := ball.global_position - center
	if away.length_squared() < 0.01:
		away = Vector3.UP
	away = away.normalized()
	ball.apply_central_impulse(away * 8.5 + Vector3.UP * 2.0)
	score += 1
	_show_message("BUMPER!  +1 punkt")


func _reset_ball() -> void:
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position = Vector3(0.0, 2.8, 0.0)
	_show_message("Kulka wróciła na start")


func _show_message(text: String) -> void:
	if message_label == null:
		return
	message_label.text = text
	message_label.visible = true
	message_time = 2.2


func _update_hud() -> void:
	if score_label == null:
		return
	var speed := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	var boost_text := "DOPALACZ GOTOWY" if boost_cooldown <= 0.0 else "DOPALACZ: %.1f s" % boost_cooldown
	score_label.text = "KULKA 3D     PUNKTY: %03d     PRĘDKOŚĆ: %04.1f     %s" % [score, speed, boost_text]
