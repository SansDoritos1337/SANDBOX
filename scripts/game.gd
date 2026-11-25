extends Node3D

## Minimalny sandbox fizyczny: jedna kulka, płaska ziemia i sterowanie myszą.
const BALL_RADIUS := 0.8
const ARENA_LIMIT := 90.0
const DRAG_STRENGTH := 34.0
const DRAG_DAMPING := 9.0
const MAX_DRAG_FORCE := 180.0

var ball: RigidBody3D
var camera: Camera3D
var drag_target: Vector3 = Vector3.ZERO
var drag_target_velocity: Vector3 = Vector3.ZERO
var dragging := false
var impact_particles: GPUParticles3D
var status_label: Label
var last_impact_time := -10.0
var elapsed := 0.0

func _ready() -> void:
	_build_world()
	_build_ground()
	_build_ball()
	_build_camera()
	_build_effects()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	elapsed += delta
	if ball == null:
		return
	# Kamera zostaje blisko kulki, aby fizyczne detale były dobrze widoczne.
	var camera_target := ball.global_position + Vector3(0.0, 4.2, 8.2)
	camera.global_position = camera.global_position.lerp(camera_target, minf(delta * 7.0, 1.0))
	camera.look_at(ball.global_position, Vector3.UP)
	if dragging:
		status_label.text = "PRZECIĄGASZ KULKĘ  •  puść LPM, żeby ją wystrzelić"
	else:
		status_label.text = "LPM: złap i przeciągnij   •   PPM: popchnij   •   R: reset"

func _physics_process(_delta: float) -> void:
	if ball == null:
		return
	if dragging:
		var next_target := _mouse_ground_position()
		if next_target != Vector3.INF:
			drag_target_velocity = (next_target - drag_target) / maxf(get_physics_process_delta_time(), 0.001)
			drag_target = next_target
			var error := drag_target - ball.global_position
			var force := error * DRAG_STRENGTH - ball.linear_velocity * DRAG_DAMPING
			ball.apply_central_force(force.limit_length(MAX_DRAG_FORCE))
	if ball.global_position.y < -15.0:
		_reset_ball()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _mouse_hits_ball(event.position):
				dragging = true
				drag_target = ball.global_position
				drag_target_velocity = Vector3.ZERO
				ball.sleeping = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var shove := _mouse_ground_position()
			if shove != Vector3.INF:
				var direction := (ball.global_position - shove).normalized()
				if direction.length_squared() < 0.01:
					direction = Vector3(0.0, 0.45, -1.0).normalized()
				ball.apply_central_impulse(direction * 12.0 + Vector3.UP * 3.0)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dragging:
			dragging = false
			ball.linear_velocity += drag_target_velocity.limit_length(22.0) * 0.65
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reset_ball()

func _mouse_hits_ball(screen_position: Vector2) -> bool:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == ball

func _mouse_ground_position() -> Vector3:
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var ground_plane := Plane(Vector3.UP, 0.0)
	var intersection: Variant = ground_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return Vector3.INF
	var point: Vector3 = intersection
	point.x = clampf(point.x, -ARENA_LIMIT, ARENA_LIMIT)
	point.z = clampf(point.z, -ARENA_LIMIT, ARENA_LIMIT)
	point.y = BALL_RADIUS
	return point

func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#071427")
	sky_material.sky_horizon_color = Color("#263c59")
	sky_material.ground_bottom_color = Color("#111b29")
	sky_material.ground_horizon_color = Color("#263c59")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8ca9d0")
	environment.ambient_light_energy = 0.55
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.14
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("#d9e8ff")
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-3.0, 4.0, -3.0)
	rim_light.light_color = Color("#22bfff")
	rim_light.light_energy = 8.0
	rim_light.omni_range = 12.0
	add_child(rim_light)

func _build_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ziemia"
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(220.0, 220.0)
	var visual := MeshInstance3D.new()
	visual.mesh = plane_mesh
	visual.material_override = _make_ground_material()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(220.0, 0.5, 220.0)
	collision.shape = shape
	collision.position.y = -0.25
	ground.add_child(collision)
	add_child(ground)

func _make_ground_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
void fragment() {
	vec2 p = world_position.xz;
	float macro_noise = hash21(floor(p * 0.16));
	float fine_noise = hash21(floor(p * 2.8));
	float blades = smoothstep(0.08, 0.92, hash21(floor(p * 14.0)));
	vec3 soil = mix(vec3(0.035, 0.075, 0.045), vec3(0.12, 0.19, 0.075), macro_noise);
	vec3 grass = mix(vec3(0.055, 0.16, 0.045), vec3(0.19, 0.31, 0.085), blades * 0.7 + fine_noise * 0.3);
	float path = smoothstep(0.0, 0.025, abs(fract(p.x * 0.5) - 0.5)) * smoothstep(0.0, 0.025, abs(fract(p.y * 0.5) - 0.5));
	ALBEDO = mix(soil, grass, 0.74 + path * 0.12);
	ROUGHNESS = 0.94;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.name = "Kulka"
	ball.position = Vector3(0.0, 5.0, 0.0)
	ball.mass = 1.25
	ball.linear_damp = 0.055
	ball.angular_damp = 0.035
	ball.continuous_cd = true
	ball.contact_monitor = true
	ball.max_contacts_reported = 8
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.48
	physics_material.bounce = 0.72
	ball.physics_material_override = physics_material
	ball.body_entered.connect(_on_ball_body_entered)

	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	var mesh := MeshInstance3D.new()
	mesh.name = "Błyszcząca kula"
	mesh.mesh = sphere
	var ball_material := StandardMaterial3D.new()
	ball_material.albedo_color = Color("#d9f6ff")
	ball_material.metallic = 0.62
	ball_material.roughness = 0.12
	ball_material.emission_enabled = true
	ball_material.emission = Color("#049eff")
	ball_material.emission_energy_multiplier = 0.65
	mesh.material_override = ball_material
	ball.add_child(mesh)

	var collision := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = BALL_RADIUS
	collision.shape = sphere_shape
	ball.add_child(collision)
	add_child(ball)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Bliska kamera"
	camera.position = Vector3(0.0, 4.2, 8.2)
	camera.fov = 48.0
	camera.current = true
	add_child(camera)
	camera.look_at(ball.global_position, Vector3.UP)

func _build_effects() -> void:
	var trail := _make_particles(90, 0.65, Color("#38cfff"), 1.2, 2.5)
	trail.name = "Świetlisty ślad"
	trail.local_coords = false
	trail.position = Vector3.ZERO
	ball.add_child(trail)
	trail.emitting = true

	impact_particles = _make_particles(70, 0.8, Color("#a8f4ff"), 3.0, 9.0)
	impact_particles.name = "Iskry uderzenia"
	impact_particles.one_shot = true
	impact_particles.emitting = false
	add_child(impact_particles)

func _make_particles(amount: int, lifetime: float, color: Color, velocity_min: float, velocity_max: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.0
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 0.5, 0.0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = velocity_min
	process_material.initial_velocity_max = velocity_max
	process_material.gravity = Vector3(0.0, -5.0, 0.0)
	process_material.scale_min = 0.045
	process_material.scale_max = 0.12
	process_material.color = color
	particles.process_material = process_material
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.055
	particle_mesh.height = 0.11
	var particle_visual := MeshInstance3D.new()
	particle_visual.mesh = particle_mesh
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.albedo_color = color
	particle_material.emission_enabled = true
	particle_material.emission = color
	particle_material.emission_energy_multiplier = 2.0
	particle_visual.material_override = particle_material
	particles.draw_pass_1 = particle_visual
	particles.lifetime = lifetime
	return particles

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	status_label = Label.new()
	status_label.position = Vector2(26.0, 24.0)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("#e9f8ff"))
	status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(status_label)

func _on_ball_body_entered(_body: Node) -> void:
	if Time.get_ticks_msec() / 1000.0 - last_impact_time < 0.12:
		return
	last_impact_time = Time.get_ticks_msec() / 1000.0
	impact_particles.global_position = ball.global_position
	impact_particles.restart()
	impact_particles.emitting = true

func _reset_ball() -> void:
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position = Vector3(0.0, 5.0, 0.0)
	ball.sleeping = false
	if impact_particles != null:
		impact_particles.global_position = ball.global_position
		impact_particles.restart()
		impact_particles.emitting = true
