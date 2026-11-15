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
var passthrough_filter = null
const LIGHT_MODES = ["NATURAL", "SOFT LIFT", "BRIGHT", "MONO"]
const MESH_STYLES = ["FINE", "BOLD", "SURFACE"]
const COLOR_NAMES = ["CYAN", "MINT", "VIOLET", "AMBER", "WHITE"]
const MESH_COLORS = [Color(0.08, 0.9, 1.0), Color(0.15, 1.0, 0.62), Color(0.68, 0.42, 1.0), Color(1.0, 0.65, 0.2), Color(0.9, 0.96, 1.0)]
const MESH_MATERIAL = preload("res://assets/wireframe-material.tres")
const SETTINGS_FILE = "user://lumen-settings.cfg"
var mesh_style := 0
var mesh_color := 0

@onready var hint_label: Label3D = $XROrigin3D/XRCamera3D/LumenPanel/Hint
@onready var panel: Node3D = $XROrigin3D/XRCamera3D/LumenPanel

const ROW_Y = [0.225, 0.115, 0.005, -0.105, -0.215, -0.325]
var menu_rows: Array[Label3D] = []
var hovered_row := -1


func _ready():
	_build_menu()
	super._ready()

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
	_update_panel()


func _load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		light_mode = clampi(int(config.get_value("view", "light", 0)), 0, LIGHT_MODES.size() - 1)
		mesh_style = clampi(int(config.get_value("view", "style", 0)), 0, MESH_STYLES.size() - 1)
		mesh_color = clampi(int(config.get_value("view", "color", 0)), 0, COLOR_NAMES.size() - 1)


func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("view", "light", light_mode)
	config.set_value("view", "style", mesh_style)
	config.set_value("view", "color", mesh_color)
	if config.save(SETTINGS_FILE) != OK:
		push_warning("Unable to save Lumen Mesh preferences")


func _build_menu() -> void:
	for i in range(ROW_Y.size()):
		var row := Label3D.new()
		row.name = "MenuRow%d" % i
		row.position = Vector3(-0.50, ROW_Y[i], 0.02)
		row.pixel_size = 0.001
		row.font_size = 34
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.no_depth_test = true
		row.render_priority = 110
		row.outline_render_priority = 109
		panel.add_child(row)
		menu_rows.append(row)
	_update_panel()


func _update_panel() -> void:
	if menu_rows.size() != ROW_Y.size():
		return
	var mode: String = LIGHT_MODES[light_mode] if passthrough_filter else "UNAVAILABLE"
	var mesh_state := "ON" if scene_and_spatial_anchors_displayed else "OFF"
	var rows := [
		"LIGHT MODE           " + mode,
		"ROOM MESH             " + mesh_state,
		"MESH STYLE             " + MESH_STYLES[mesh_style],
		"MESH COLOR            " + COLOR_NAMES[mesh_color],
		"LOW LIGHT + MESH    ENABLE",
		"CAPTURE ROOM          START"
	]
	for i in range(rows.size()):
		menu_rows[i].text = (">   " if i == hovered_row else "     ") + rows[i]
		menu_rows[i].modulate = Color(0.37, 0.95, 1.0) if i == hovered_row else Color(0.90, 0.94, 0.98)


func display_scene_and_spatial_anchors(value: bool) -> void:
	if scene_and_spatial_anchors_displayed == value:
		return
	scene_manager.visible = value
	scene_and_spatial_anchors_displayed = value
	_update_panel()


# Coordinates are local to the menu plane. Keep hit targets larger than the text.
func _menu_row_at(point: Vector2) -> int:
	if absf(point.x) > 0.55:
		return -1
	for i in range(ROW_Y.size()):
		if absf(point.y - ROW_Y[i]) < 0.05:
			return i
	return -1


func _physics_process(_delta: float) -> void:
	var hit := -1
	var distance := 2.0
	var show_pointer := panel.visible and right_hand_pointer.get_is_active()
	if show_pointer:
		var origin := panel.to_local(right_hand_pointer.global_position)
		var direction := panel.global_transform.basis.inverse() * -right_hand_pointer.global_transform.basis.z
		if direction.z < -0.001:
			var t := -origin.z / direction.z
			if t > 0.0 and t < 5.0:
				var point := origin + direction * t
				hit = _menu_row_at(Vector2(point.x, point.y))
				if hit >= 0:
					distance = t
					scene_colliding_mesh.position = Vector3(0, 0, -t)
	scene_pointer_mesh.visible = show_pointer
	scene_colliding_mesh.visible = show_pointer and hit >= 0
	if show_pointer:
		scene_pointer_mesh.mesh.size.z = distance
		scene_pointer_mesh.position.z = -distance / 2.0
	if hit != hovered_row:
		hovered_row = hit
		_update_panel()


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
			light_mode = 1
			enable_passthrough(true)
			display_scene_and_spatial_anchors(true)
			_apply_light_mode()
			_save_preferences()
			hint_label.text = "MESH USES YOUR SAVED ROOM SCAN"
		5:
			hint_label.text = "FOLLOW THE HEADSET ROOM SETUP"
			scene_manager.request_scene_capture()


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
		hint_label.text = "FOLLOW THE HEADSET'S ROOM SETUP"
		scene_manager.request_scene_capture()


func _on_right_hand_button_pressed(name: String) -> void:
	if name == "trigger_click" and panel.visible and hovered_row >= 0:
		_activate_menu_row(hovered_row)
	elif name == "ax_button":
		light_mode = (light_mode + 1) % LIGHT_MODES.size()
		_apply_light_mode()
		_save_preferences()
	elif name == "by_button":
		panel.visible = not panel.visible
		if not panel.visible:
			hovered_row = -1


func _on_scene_manager_scene_capture_completed(success: bool) -> void:
	hint_label.text = "SCAN COMPLETE" if success else "SCAN CANCELLED OR UNAVAILABLE"
	if success:
		# Recreate scene anchors since the user may have changed them.
		if scene_manager.are_scene_anchors_created():
			scene_manager.remove_scene_anchors()
		scene_manager.create_scene_anchors()


func _on_scene_manager_scene_data_missing() -> void:
	scene_manager.request_scene_capture()
