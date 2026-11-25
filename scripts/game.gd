extends Node3D

const BALL_RADIUS := 0.72
const WORLD_LIMIT := 24.0
const DRIVE_FORCE := 54.0

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
	_build_ground()
	_build_terrain()
	_build_track()
	_build_ball()
	_build_camera()
	_build_hud()
	_show_message("MEGA KULKA — sprawdź teren i rampy!")

func _process(delta: float) -> void:
	if ball == null:
		return
	var target := ball.global_position + Vector3(0.0, 12.0, 17.0)
	camera.global_position = camera.global_position.lerp(target, minf(delta * 5.0, 1.0))
	camera.look_at(ball.global_position + Vector3.UP * 0.4, Vector3.UP)
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_label.visible = false
	_update_hud()

func _physics_process(delta: float) -> void:
	boost_cooldown = maxf(boost_cooldown - delta, 0.0)
	var drive := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): drive.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): drive.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): drive.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): drive.x += 1.0
	if drive != Vector3.ZERO:
		ball.apply_force(drive.normalized() * DRIVE_FORCE, Vector3.DOWN * (BALL_RADIUS * 0.8))

	var jump_down := Input.is_key_pressed(KEY_SPACE)
	if jump_down and not jump_was_down and ball.get_contact_count() > 0:
		ball.apply_central_impulse(Vector3.UP * 12.0)
	jump_was_down = jump_down

	var boost_down := Input.is_key_pressed(KEY_SHIFT)
	if boost_down and not boost_was_down and boost_cooldown == 0.0:
		var direction := drive.normalized() if drive != Vector3.ZERO else Vector3.BACK
		ball.apply_central_impulse(direction * 14.0 + Vector3.UP * 3.0)
		boost_cooldown = 0.75
	boost_was_down = boost_down

	var reset_down := Input.is_key_pressed(KEY_R)
	if reset_down and not reset_was_down:
		_reset_ball()
	reset_was_down = reset_down
	if ball.global_position.y < -18.0:
		_reset_ball()

func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#083d70")
	sky_material.sky_horizon_color = Color("#5ea4d6")
	sky_material.ground_bottom_color = Color("#10182d")
	sky_material.ground_horizon_color = Color("#26406b")
	sky_material.sun_angle_max = 42.0
	sky.sky_material = sky_material
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.16
	env.tonemap_white = 7.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("#88c4ff")
	env.ambient_light_energy = 0.7
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_detail_spread = 0.8
	env.ssao_enabled = true
	env.ssao_radius = 1.7
	env.ssao_intensity = 2.3
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.12
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.22
	world_environment.environment = env
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	sun.light_color = Color("#fff4da")
	sun.light_energy = 3.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 95.0
	sun.directional_shadow_split_1 = 0.12
	sun.directional_shadow_split_2 = 0.26
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_fade_start = 0.75
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_pancake_size = 20.0
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 18.0, 12.0)
	fill.light_color = Color("#6caeff")
	fill.light_energy = 42.0
	fill.omni_range = 42.0
	fill.omni_attenuation = 1.3
	add_child(fill)

func _build_ground() -> void:
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#233b28")
	ground_material.roughness = 0.82
	ground_material.metallic = 0.02
	_add_box("Główna ziemia", Vector3(0.0, -1.0, 0.0), Vector3(70.0, 2.0, 70.0), ground_material)

	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color("#6a756e")
	rock_material.roughness = 0.96
	for i in range(80):
		var random_x := randf_range(-29.0, 29.0)
		var random_z := randf_range(-29.0, 29.0)
		if absf(random_x) < 18.0 and absf(random_z) < 18.0:
			continue
		var size := randf_range(1.0, 4.0)
		_add_visual_sphere(Vector3(random_x, randf_range(-0.2, 0.9), random_z), size, rock_material)

func _build_terrain() -> void:
	var mountain_material := _material(Color("#55676a"), 0.94, 0.05)
	var snow_material := _material(Color("#dcecf0"), 0.75, 0.02)
	var mountain_positions := [
		Vector3(-34.0, 5.0, -30.0), Vector3(34.0, 7.0, -32.0),
		Vector3(-38.0, 10.0, 22.0), Vector3(38.0, 9.0, 24.0),
		Vector3(-5.0, 5.0, -42.0), Vector3(20.0, 4.0, -40.0)
	]
	for position in mountain_positions:
		var mountain := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 1.0
		cone.bottom_radius = 12.0
		cone.height = position.y * 2.0
		cone.radial_segments = 12
		mountain.mesh = cone
		mountain.material_override = mountain_material
		mountain.position = position
		add_child(mountain)

		var snow := MeshInstance3D.new()
		var snow_cone := CylinderMesh.new()
		snow_cone.top_radius = 0.7
		snow_cone.bottom_radius = 4.8
		snow_cone.height = position.y * 0.55
		snow_cone.radial_segments = 12
		snow.mesh = snow_cone
		snow.material_override = snow_material
		snow.position = position + Vector3.UP * (position.y * 0.72)
		add_child(snow)

func _build_track() -> void:
	var track_material := _material(Color("#193659"), 0.28, 0.5)
	var neon_material := _material(Color("#3fe9ff"), 0.15, 0.3, Color("#09c9ff") * 2.0)
	_add_box("Arena", Vector3.ZERO, Vector3(32.0, 1.0, 32.0), track_material)

	for i in range(-14, 15, 2):
		_add_visual_box(Vector3(float(i), 0.52, 0.0), Vector3(0.035, 0.025, 31.0), neon_material)
		_add_visual_box(Vector3(0.0, 0.52, float(i)), Vector3(31.0, 0.025, 0.035), neon_material)

	_add_box("Bariera północ", Vector3(0.0, 1.5, -16.0), Vector3(32.0, 3.0, 0.8), track_material)
	_add_box("Bariera południe", Vector3(0.0, 1.5, 16.0), Vector3(32.0, 3.0, 0.8), track_material)
	_add_box("Bariera zachód", Vector3(-16.0, 1.5, 0.0), Vector3(0.8, 3.0, 32.0), track_material)
	_add_box("Bariera wschód", Vector3(16.0, 1.5, 0.0), Vector3(0.8, 3.0, 32.0), track_material)

	_add_box("Mega rampa A", Vector3(-9.0, 1.0, -7.0), Vector3(8.0, 1.0, 6.0), neon_material, Vector3(0.0, 0.0, -0.28))
	_add_box("Mega rampa B", Vector3(9.0, 1.0, 7.0), Vector3(8.0, 1.0, 6.0), neon_material, Vector3(0.0, 0.0, 0.28))

	var positions := [Vector3(-6, 0.8, -2), Vector3(6, 0.8, 2), Vector3(0, 0.8, 6), Vector3(-3, 0.8, 11), Vector3(10, 0.8, -9), Vector3(-10, 0.8, 8)]
	for index in positions.size():
		var center: Vector3 = positions[index]
		var hue := float(index) / positions.size()
		var color := Color.from_hsv(hue, 0.8, 1.0)
		var bumper := StaticBody3D.new()
		bumper.position = center
		var mesh_instance := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 1.0
		cylinder.bottom_radius = 1.12
		cylinder.height = 1.6
		mesh_instance.mesh = cylinder
		mesh_instance.material_override = _material(color, 0.12, 0.55, color * 1.8)
		bumper.add_child(mesh_instance)
		var collider := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 1.1
		shape.height = 1.6
		collider.shape = shape
		bumper.add_child(collider)
		add_child(bumper)

		var area := Area3D.new()
		area.position = center
		var area_shape := SphereShape3D.new()
		area_shape.radius = 1.55
		var area_collider := CollisionShape3D.new()
		area_collider.shape = area_shape
		area.add_child(area_collider)
		area.body_entered.connect(_on_bumper_touched.bind(center))
		add_child(area)

func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.name = "MEGA_KULKA"
	ball.position = Vector3(0.0, 4.0, 0.0)
	ball.mass = 1.8
	ball.linear_damp = 0.08
	ball.angular_damp = 0.04
	ball.continuous_cd = true
	ball.contact_monitor = true
	ball.max_contacts_reported = 12
	ball.physics_material_override = PhysicsMaterial.new()
	ball.physics_material_override.friction = 0.85
	ball.physics_material_override.bounce = 0.55
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.material_override = _material(Color("#f8fcff"), 0.08, 0.72, Color("#38cfff") * 0.55)
	ball.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = BALL_RADIUS
	collider.shape = shape
	ball.add_child(collider)
	add_child(ball)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 12.0, 17.0)
	camera.fov = 68.0
	camera.current = true
	add_child(camera)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	score_label = Label.new()
	score_label.position = Vector2(24.0, 18.0)
	score_label.add_theme_font_size_override("font_size", 30)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(score_label)
	var controls := Label.new()
	controls.position = Vector2(24.0, 68.0)
	controls.text = "WASD — ruch  •  SPACJA — skok  •  SHIFT — boost  •  R — reset"
	controls.add_theme_font_size_override("font_size", 17)
	controls.add_theme_color_override("font_color", Color("#d1eaff"))
	layer.add_child(controls)
	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-350.0, 120.0)
	message_label.size = Vector2(700.0, 50.0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color("#77efff"))
	layer.add_child(message_label)

func _add_box(label: String, position: Vector3, size: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position
	body.rotation = rotation
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _add_visual_box(position: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _add_visual_sphere(position: Vector3, size: float, material: Material) -> void:
	var sphere_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	sphere_instance.mesh = sphere
	sphere_instance.position = position
	sphere_instance.material_override = material
	add_child(sphere_instance)

func _material(color: Color, roughness: float, metallic: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.0
	return material

func _on_bumper_touched(body: Node3D, center: Vector3) -> void:
	if body != ball:
		return
	var direction := (ball.global_position - center).normalized()
	ball.apply_central_impulse(direction * 14.0 + Vector3.UP * 5.0)
	score += 1
	_show_message("MEGA BUMPER!  +1")

func _reset_ball() -> void:
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position = Vector3(0.0, 4.0, 0.0)
	_show_message("Powrót na start")

func _show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	message_time = 2.2

func _update_hud() -> void:
	var speed := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	var boost_text := "BOOST GOTOWY" if boost_cooldown == 0.0 else "BOOST: %.1f" % boost_cooldown
	score_label.text = "PUNKTY: %03d   PRĘDKOŚĆ: %05.1f   %s" % [score, speed, boost_text]
