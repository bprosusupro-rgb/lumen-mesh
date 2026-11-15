extends StartXR

var passthrough_enabled: bool = false
var scene_and_spatial_anchors_displayed: bool = true

@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var right_hand_pointer: XRController3D = $XROrigin3D/RightHandPointer
@onready var scene_pointer_mesh: MeshInstance3D = $XROrigin3D/RightHandPointer/ScenePointerMesh
@onready var scene_colliding_mesh: MeshInstance3D = $XROrigin3D/RightHandPointer/SceneCollidingMesh
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var scene_manager: OpenXRFbSceneManager = $XROrigin3D/OpenXRFbSceneManager

var _setup := false
var light_mode := 0
var live_depth_enabled := false
var live_depth_node: MeshInstance3D
var depth_extension
var passthrough_filter = null
const LIGHT_MODES = ["DAY", "SOFT LIFT", "BRIGHT", "MONO"]
const MESH_STYLES = ["FINE", "BOLD", "SURFACE"]
const COLOR_NAMES = ["CYAN", "MINT", "VIOLET", "AMBER", "WHITE", "BLUE", "ROSE", "LIME", "ORANGE", "RED"]
const MESH_COLORS = [Color(0.08, 0.9, 1.0), Color(0.15, 1.0, 0.62), Color(0.68, 0.42, 1.0), Color(1.0, 0.65, 0.2), Color(0.9, 0.96, 1.0), Color(0.25, 0.55, 1.0), Color(1.0, 0.38, 0.62), Color(0.7, 1.0, 0.2), Color(1.0, 0.42, 0.12), Color(1.0, 0.18, 0.2)]
const MESH_MATERIAL = preload("res://assets/wireframe-material.tres")
const SETTINGS_FILE = "user://lumen-settings.cfg"
var mesh_style := 0
var mesh_color := 0

@onready var hint_label: Label3D = $XROrigin3D/LumenPanel/Hint
@onready var panel: Node3D = $XROrigin3D/LumenPanel
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var hud: Node3D = $XROrigin3D/XRCamera3D/Hud
@onready var hud_label: Label3D = $XROrigin3D/XRCamera3D/Hud/Readout

const ROW_POS = [Vector2(-0.335, 0.20), Vector2(-0.335, 0.06), Vector2(-0.335, -0.08), Vector2(-0.335, -0.22), Vector2(0.335, 0.20), Vector2(0.335, 0.06), Vector2(0.335, -0.08), Vector2(0.335, -0.22)]
const ROW_SHADER = preload("res://assets/menu_row.gdshader")
const DIRECTIONS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
var menu_rows: Array[Label3D] = []
var hovered_row := -1
var row_materials: Array[ShaderMaterial] = []
var hud_enabled := true
var north_set := false
var north_yaw := 0.0
var hud_update_timer := 0.0
var right_pinched := false
var left_pinched := false
@onready var hand_pointer: Node3D = $XROrigin3D/HandPointer
@onready var hand_beam: MeshInstance3D = $XROrigin3D/HandPointer/Beam
@onready var hand_dot: MeshInstance3D = $XROrigin3D/HandPointer/Dot
@onready var xr_origin: XROrigin3D = $XROrigin3D


func _ready():
	_build_menu()
	super._ready()
	pose_recentered.connect(_on_hud_recentered)

	for render_model in [%LeftControllerFbRenderModel, %RightControllerFbRenderModel]:
		render_model.openxr_fb_render_model_loaded.connect(_on_openxr_fb_render_model_loaded.bind(render_model))


func _on_openxr_session_begun() -> void:
	if _setup:
		return
	_setup = true

	# Meta recommends 72 Hz for Quest passthrough where supported.
	if 72.0 in xr_interface.get_available_display_refresh_rates():
		xr_interface.set_display_refresh_rate(72.0)
	Engine.physics_ticks_per_second = 72
	_load_preferences()
	_apply_mesh_style()
	enable_passthrough(true)
	passthrough_filter = Engine.get_singleton("OpenXRFbPassthroughExtension")
	_apply_light_mode()
	depth_extension = Engine.get_singleton("OpenXRMetaEnvironmentDepthExtension")
	_build_live_depth()
	_update_panel()


func _on_openxr_fb_render_model_loaded(render_model: OpenXRFbRenderModel) -> void:
	for mesh_instance in render_model.find_children("*", "MeshInstance3D", true, false):
		for i in range(mesh_instance.mesh.get_surface_count()):
			var material: Material = mesh_instance.mesh.surface_get_material(i)
			# Make sure these render before the depth buffer is filled with environment depth info.
			material.render_priority = -100


func enable_passthrough(enable: bool) -> void:
	if passthrough_enabled == enable:
		return

	var supported_blend_modes = xr_interface.get_supported_environment_blend_modes()
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in supported_blend_modes and XRInterface.XR_ENV_BLEND_MODE_OPAQUE in supported_blend_modes:
		if enable:
			# Switch to passthrough.
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
			get_viewport().transparent_bg = true
			world_environment.environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
		else:
			# Switch back to VR.
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
			get_viewport().transparent_bg = false
			world_environment.environment.background_color = Color(0.3, 0.3, 0.3, 1.0)
		passthrough_enabled = enable
	_update_panel()


func _apply_light_mode() -> void:
	if not passthrough_filter:
		_update_panel()
		return
	if light_mode == 0:
		passthrough_filter.set_passthrough_filter(OpenXRFbPassthroughExtension.PASSTHROUGH_FILTER_DISABLED)
	else:
		var settings := [Vector3.ZERO, Vector3(0.10, 1.0, 1.0), Vector3(0.22, 1.04, 0.95), Vector3(0.15, 1.06, 0.0)]
		var values: Vector3 = settings[light_mode]
		# This setter also selects the brightness/contrast filter.
		passthrough_filter.set_brightness_contrast_saturation(values.x, values.y, values.z)
	_update_panel()


func _apply_mesh_style() -> void:
	var color: Color = MESH_COLORS[mesh_color]
	var edge_alpha: float = [0.23, 0.50, 0.25][mesh_style]
	var fill_alpha: float = [0.0, 0.0, 0.10][mesh_style]
	var width: float = [0.45, 1.0, 0.55][mesh_style]
	MESH_MATERIAL.set_shader_parameter("wire_color", Color(color.r, color.g, color.b, edge_alpha))
	MESH_MATERIAL.set_shader_parameter("albedo", Color(color.r, color.g, color.b, fill_alpha))
	MESH_MATERIAL.set_shader_parameter("wire_width", width)
	if is_instance_valid(live_depth_node) and live_depth_node.material_override:
		live_depth_node.material_override.set_shader_parameter("live_color", color)
	_update_panel()


func _build_live_depth() -> void:
	# Shared vertices reduce depth-texture lookups versus six vertices per cell.
	var columns := 128
	var rows := 96
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize((columns + 1) * (rows + 1))
	uvs.resize(vertices.size())
	indices.resize(columns * rows * 6)
	for y in range(rows + 1):
		for x in range(columns + 1):
			var i := y * (columns + 1) + x
			var uv := Vector2(float(x) / columns, float(y) / rows)
			vertices[i] = Vector3(uv.x, uv.y, 0)
			uvs[i] = uv
	var k := 0
	for y in range(rows):
		for x in range(columns):
			var a := y * (columns + 1) + x
			var b := a + 1
			var c := a + columns + 1
			var d := c + 1
			for index in [a, b, d, a, d, c]:
				indices[k] = index
				k += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/live_depth.gdshader")
	material.set_shader_parameter("live_color", MESH_COLORS[mesh_color])
	live_depth_node = MeshInstance3D.new()
	live_depth_node.mesh = mesh
	live_depth_node.material_override = material
	live_depth_node.extra_cull_margin = 10000.0
	live_depth_node.visible = false
	xr_origin.add_child(live_depth_node)


func _toggle_live_depth() -> void:
	if not depth_extension or not depth_extension.is_environment_depth_supported():
		hint_label.text = "LIVE DEPTH UNAVAILABLE ON THIS DEVICE"
		return
	if live_depth_enabled:
		depth_extension.stop_environment_depth()
		live_depth_enabled = false
		live_depth_node.visible = false
	else:
		depth_extension.start_environment_depth()
		live_depth_enabled = depth_extension.is_environment_depth_started()
		live_depth_node.visible = live_depth_enabled
		hint_label.text = "DEPTH REQUESTED / CHECK SPATIAL DATA PERMISSION" if live_depth_enabled else "LIVE DEPTH COULD NOT START"
	_update_panel()


func _load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		light_mode = clampi(int(config.get_value("view", "light", 0)), 0, LIGHT_MODES.size() - 1)
		mesh_style = clampi(int(config.get_value("view", "style", 0)), 0, MESH_STYLES.size() - 1)
		mesh_color = clampi(int(config.get_value("view", "color", 0)), 0, COLOR_NAMES.size() - 1)
		hud_enabled = bool(config.get_value("view", "hud", true)) if int(config.get_value("view", "hud_revision", 0)) >= 7 else true
	if is_instance_valid(hud):
		hud.visible = hud_enabled


func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("view", "light", light_mode)
	config.set_value("view", "style", mesh_style)
	config.set_value("view", "color", mesh_color)
	config.set_value("view", "hud", hud_enabled)
	config.set_value("view", "hud_revision", 7)
	if config.save(SETTINGS_FILE) != OK:
		push_warning("Unable to save Lumen Mesh preferences")


func _build_menu() -> void:
	for i in range(ROW_POS.size()):
		var material := ShaderMaterial.new()
		material.shader = ROW_SHADER
		material.render_priority = 105
		var shape := QuadMesh.new()
		shape.size = Vector2(0.62, 0.115)
		shape.material = material
		var tile := MeshInstance3D.new()
		tile.name = "RowSurface%d" % i
		tile.position = Vector3(ROW_POS[i].x, ROW_POS[i].y, 0.008)
		tile.mesh = shape
		panel.add_child(tile)
		row_materials.append(material)
		var row := Label3D.new()
		row.name = "MenuRow%d" % i
		row.position = Vector3(ROW_POS[i].x - 0.28, ROW_POS[i].y, 0.02)
		row.pixel_size = 0.0008
		row.font_size = 32
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.no_depth_test = true
		row.render_priority = 110
		row.outline_render_priority = 109
		panel.add_child(row)
		menu_rows.append(row)
	_update_panel()


func _update_panel() -> void:
	if menu_rows.size() != ROW_POS.size():
		return
	var mode: String = LIGHT_MODES[light_mode] if passthrough_filter else "UNAVAILABLE"
	var mesh_state := "ON" if scene_and_spatial_anchors_displayed else "OFF"
	var rows := [
		"Light   /   " + mode,
		"Room mesh   /   " + mesh_state,
		"Style   /   " + MESH_STYLES[mesh_style],
		"Color   /   " + COLOR_NAMES[mesh_color],
		"Live depth   /   " + ("ON" if live_depth_enabled else "OFF"),
		"HUD   " + ("ON" if hud_enabled else "OFF"),
		"Set north   " + ("AGAIN" if north_set else "SET"),
		"Rescan room"
	]
	for i in range(rows.size()):
		menu_rows[i].text = (">  " if i == hovered_row else "    ") + rows[i]
		menu_rows[i].modulate = Color(0.70, 1.0, 1.0) if i == hovered_row else Color(0.90, 0.94, 0.98)
		row_materials[i].set_shader_parameter("highlighted", i == hovered_row)


func display_scene_and_spatial_anchors(value: bool) -> void:
	if scene_and_spatial_anchors_displayed == value:
		return
	scene_manager.visible = value
	scene_and_spatial_anchors_displayed = value
	_update_panel()


# Coordinates are local to the menu plane. Keep hit targets larger than the text.
func _menu_row_at(point: Vector2) -> int:
	for i in range(ROW_POS.size()):
		var offset: Vector2 = point - ROW_POS[i]
		if absf(offset.x) < 0.31 and absf(offset.y) < 0.06:
			return i
	return -1


# Reopening places the panel in front of the user; it remains fixed in the room.
func _menu_transform(head: Transform3D) -> Transform3D:
	var forward := -head.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	return Transform3D(Basis.looking_at(forward, Vector3.UP), head.origin + forward * 1.55 + Vector3.DOWN * 0.10)


func _open_menu() -> void:
	panel.global_transform = _menu_transform(camera.global_transform)
	panel.visible = true
	hovered_row = -1
	_update_panel()


func _request_room_capture() -> void:
	if scene_manager.request_scene_capture():
		hint_label.text = "FOLLOW QUEST SPACE SETUP TO RESCAN"
	else:
		hint_label.text = "RESCAN UNAVAILABLE  /  USE QUEST SPACE SETUP"


# Hand joints are reported in XR-origin space; missing/invalid joints never generate clicks.
func _hand_sample(path: StringName) -> Dictionary:
	var tracker = XRServer.get_tracker(path)
	if not tracker is XRHandTracker:
		return {}
	var ids := [XRHandTracker.HAND_JOINT_WRIST, XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP, XRHandTracker.HAND_JOINT_THUMB_TIP]
	for id in ids:
		if (tracker.get_hand_joint_flags(id) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) == 0:
			return {}
	return {"wrist": tracker.get_hand_joint_transform(ids[0]).origin,
		"index": tracker.get_hand_joint_transform(ids[1]).origin,
		"thumb": tracker.get_hand_joint_transform(ids[2]).origin}


func _pinch_state(sample: Dictionary, previous: bool) -> bool:
	if sample.is_empty():
		return false
	var threshold := 0.045 if previous else 0.025
	return sample["index"].distance_to(sample["thumb"]) < threshold


func _physics_process(_delta: float) -> void:
	var left := _hand_sample(&"/user/hand_tracker/left")
	var left_now := _pinch_state(left, left_pinched)
	if left_now and not left_pinched:
		if panel.visible:
			panel.visible = false
		else:
			_open_menu()
	left_pinched = left_now

	var right := _hand_sample(&"/user/hand_tracker/right")
	var right_now := _pinch_state(right, right_pinched)
	var hand_active := false
	if not right.is_empty():
		var direction_local: Vector3 = right["index"] - right["wrist"]
		if direction_local.length() > 0.04:
			var direction_world := (xr_origin.global_transform.basis * direction_local).normalized()
			if absf(direction_world.dot(Vector3.UP)) < 0.98:
				hand_pointer.global_transform = Transform3D(Basis.looking_at(direction_world, Vector3.UP), xr_origin.global_transform * right["index"])
				hand_active = true
	var pointer: Node3D = hand_pointer if hand_active else right_hand_pointer
	var beam: MeshInstance3D = hand_beam if hand_active else scene_pointer_mesh
	var dot: MeshInstance3D = hand_dot if hand_active else scene_colliding_mesh
	var show_pointer := panel.visible and (hand_active or right_hand_pointer.get_is_active())
	hand_pointer.visible = show_pointer and hand_active
	scene_pointer_mesh.visible = show_pointer and not hand_active
	scene_colliding_mesh.visible = false
	hand_dot.visible = false
	var hit := -1
	var distance := 2.0
	if show_pointer:
		var origin := panel.to_local(pointer.global_position)
		var direction := panel.global_transform.basis.inverse() * -pointer.global_transform.basis.z
		if direction.z < -0.001:
			var t := -origin.z / direction.z
			if t > 0.0 and t < 5.0:
				var point := origin + direction * t
				hit = _menu_row_at(Vector2(point.x, point.y))
				if hit >= 0:
					distance = t
					dot.position = Vector3(0, 0, -t)
					dot.visible = true
		beam.mesh.size.z = distance
		beam.position.z = -distance / 2.0
	if hit != hovered_row:
		hovered_row = hit
		_update_panel()
	if hand_active and right_now and not right_pinched and panel.visible and hit >= 0:
		_activate_menu_row(hit)
	right_pinched = right_now


func _activate_menu_row(index: int) -> void:
	match index:
		0:
			light_mode = (light_mode + 1) % LIGHT_MODES.size()
			_apply_light_mode()
			_save_preferences()
		1:
			display_scene_and_spatial_anchors(not scene_and_spatial_anchors_displayed)
		2:
			mesh_style = (mesh_style + 1) % MESH_STYLES.size()
			_apply_mesh_style()
			_save_preferences()
		3:
			mesh_color = (mesh_color + 1) % COLOR_NAMES.size()
			_apply_mesh_style()
			_save_preferences()
		4:
			_toggle_live_depth()
		5:
			hud_enabled = not hud_enabled
			hud.visible = hud_enabled
			_save_preferences()
			_update_panel()
		6:
			hud_enabled = true
			hud.visible = true
			_save_preferences()
			var horizontal := _horizontal_yaw(camera.global_transform.basis)
			if is_nan(horizontal):
				hint_label.text = "LOOK LEVEL TO SET NORTH"
			else:
				north_yaw = horizontal
				north_set = true
				hint_label.text = "NORTH SET  /  RECALIBRATE AFTER RECENTER"
				_update_panel()
		7:
			_request_room_capture()


# Local XR orientation has no geographic north. User sets it each session.
func _horizontal_yaw(basis: Basis) -> float:
	var forward := -basis.z
	if Vector2(forward.x, forward.z).length() < 0.15:
		return NAN
	return rad_to_deg(atan2(forward.x, -forward.z))


func _format_heading(yaw: float, reference: float) -> String:
	var degrees := fposmod(yaw - reference, 360.0)
	var index := int(floor((degrees + 22.5) / 45.0)) % DIRECTIONS.size()
	return "%s  %03d°" % [DIRECTIONS[index], int(round(degrees)) % 360]


func _on_hud_recentered() -> void:
	north_set = false
	if is_instance_valid(hint_label):
		hint_label.text = "RECENTERED  /  SET NORTH AGAIN"
	_update_panel()


func _process(delta: float) -> void:
	if not hud_enabled or not is_instance_valid(hud_label):
		return
	hud_update_timer -= delta
	if hud_update_timer > 0.0:
		return
	hud_update_timer = 0.5
	var yaw := _horizontal_yaw(camera.global_transform.basis)
	var heading := "DIRECTION: SET NORTH" if not north_set else ("DIRECTION: LOOK LEVEL" if is_nan(yaw) else "DIRECTION: " + _format_heading(yaw, north_yaw))
	var mesh_status := "MESH ON" if scene_and_spatial_anchors_displayed else "MESH OFF"
	if live_depth_enabled:
		mesh_status += " / LIVE"
	var view_status: String = LIGHT_MODES[light_mode] if passthrough_enabled else "VIEW OFF"
	var now := Time.get_time_dict_from_system()
	var clock := "%02d:%02d" % [now.hour, now.minute]
	hud_label.text = "%s   |   %s   |   %d FPS\n%s   |   %s   |   B: SETTINGS" % [heading, clock, Engine.get_frames_per_second(), view_status, mesh_status]


func _on_left_hand_button_pressed(name):
	if name == "ax_button":
		display_scene_and_spatial_anchors(not scene_and_spatial_anchors_displayed)
	elif name == "by_button":
		enable_passthrough(not passthrough_enabled)
	elif name == "trigger_click":
		mesh_style = (mesh_style + 1) % MESH_STYLES.size()
		_apply_mesh_style()
		_save_preferences()
	elif name == "grip_click":
		mesh_color = (mesh_color + 1) % COLOR_NAMES.size()
		_apply_mesh_style()
		_save_preferences()
	elif name == "menu_button":
		_request_room_capture()


func _on_right_hand_button_pressed(name: String) -> void:
	if name == "trigger_click" and panel.visible and hovered_row >= 0:
		_activate_menu_row(hovered_row)
	elif name == "ax_button":
		light_mode = (light_mode + 1) % LIGHT_MODES.size()
		_apply_light_mode()
		_save_preferences()
	elif name == "by_button":
		if panel.visible:
			panel.visible = false
			hovered_row = -1
		else:
			_open_menu()


func _on_scene_manager_scene_capture_completed(success: bool) -> void:
	hint_label.text = "ROOM SCAN UPDATED" if success else "SCAN CANCELLED OR UNAVAILABLE"
	if success:
		# Recreate scene anchors since the user may have changed them.
		if scene_manager.are_scene_anchors_created():
			scene_manager.remove_scene_anchors()
		scene_manager.create_scene_anchors()


func _on_scene_manager_scene_data_missing() -> void:
	scene_manager.request_scene_capture()
