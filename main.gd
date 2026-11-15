extends StartXR

var passthrough_enabled: bool = false
var scene_and_spatial_anchors_displayed: bool = true
var selected_spatial_anchor_node: Node3D = null

@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var right_hand_pointer: XRController3D = $XROrigin3D/RightHandPointer
@onready var right_hand_pointer_raycast: RayCast3D = $XROrigin3D/RightHandPointer/RayCast3D
@onready var scene_pointer_mesh: MeshInstance3D = $XROrigin3D/RightHandPointer/ScenePointerMesh
@onready var scene_colliding_mesh: MeshInstance3D = $XROrigin3D/RightHandPointer/SceneCollidingMesh
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var scene_manager: OpenXRFbSceneManager = $XROrigin3D/OpenXRFbSceneManager
@onready var spatial_anchor_manager: OpenXRFbSpatialAnchorManager = $XROrigin3D/OpenXRFbSpatialAnchorManager

const SPATIAL_ANCHORS_FILE = "user://openxr_fb_spatial_anchors.json"

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

@onready var status_label: Label3D = $XROrigin3D/XRCamera3D/LumenPanel/Status
@onready var hint_label: Label3D = $XROrigin3D/XRCamera3D/LumenPanel/Hint
@onready var panel: Node3D = $XROrigin3D/XRCamera3D/LumenPanel

const COLORS = [
	"#FF0000",  # Red
	"#00FF00",  # Green
	"#0000FF",  # Blue
	"#FFFF00",  # Yellow
	"#00FFFF",  # Cyan
	"#FF00FF",  # Magenta
	"#FF8000",  # Orange
	"#800080",  # Purple
]


func _ready():
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
	load_spatial_anchors_from_file()
	enable_passthrough(true)
	passthrough_filter = Engine.get_singleton("OpenXRFbPassthroughExtension")
	_apply_light_mode()
	_update_panel()


func load_spatial_anchors_from_file() -> void:
	var file := FileAccess.open(SPATIAL_ANCHORS_FILE, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		print("ERROR: Unable to parse ", SPATIAL_ANCHORS_FILE)
		return

	if not json.data is Dictionary:
		print("ERROR: ", SPATIAL_ANCHORS_FILE, " contains invalid data")
		return

	var anchor_data: Dictionary = json.data
	if anchor_data.size() > 0:
		spatial_anchor_manager.load_anchors(anchor_data.keys(), anchor_data, OpenXRFbSpatialEntity.STORAGE_LOCAL, true)


func save_spatial_anchors_to_file() -> void:
	var file := FileAccess.open(SPATIAL_ANCHORS_FILE, FileAccess.WRITE)
	if not file:
		print("ERROR: Unable to open file for writing: ", SPATIAL_ANCHORS_FILE)
		return

	var anchor_data := {}
	for uuid in spatial_anchor_manager.get_anchor_uuids():
		var entity: OpenXRFbSpatialEntity = spatial_anchor_manager.get_spatial_entity(uuid)
		anchor_data[uuid] = entity.custom_data

	file.store_string(JSON.stringify(anchor_data))
	file.close()


func _on_spatial_anchor_tracked(_anchor_node: XRAnchor3D, _spatial_entity: OpenXRFbSpatialEntity, is_new: bool) -> void:
	if is_new:
		save_spatial_anchors_to_file()


func _on_spatial_anchor_untracked(_anchor_node: XRAnchor3D, _spatial_entity: OpenXRFbSpatialEntity) -> void:
	save_spatial_anchors_to_file()


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


func _update_panel() -> void:
	if not is_instance_valid(status_label):
		return
	var view := "ON" if passthrough_enabled else "OFF"
	var mesh := "ON" if scene_and_spatial_anchors_displayed else "OFF"
	var mode: String = LIGHT_MODES[light_mode] if passthrough_filter else "UNAVAILABLE"
	status_label.text = "VIEW  %s     MESH  %s\nLIGHT  %s\nMESH  %s  /  %s" % [view, mesh, mode, MESH_STYLES[mesh_style], COLOR_NAMES[mesh_color]]


func display_scene_and_spatial_anchors(value: bool) -> void:
	if scene_and_spatial_anchors_displayed == value:
		return

	scene_manager.visible = value
	spatial_anchor_manager.visible = value
	right_hand_pointer.visible = value
	right_hand_pointer_raycast.enabled = value

	scene_and_spatial_anchors_displayed = value
	_update_panel()


func _physics_process(_delta: float) -> void:
	if right_hand_pointer.visible:
		var previous_selected_spatial_anchor_node = selected_spatial_anchor_node

		if right_hand_pointer_raycast.is_colliding():
			var collision_point: Vector3 = right_hand_pointer_raycast.get_collision_point()
			scene_colliding_mesh.global_position = collision_point

			var pointer_length: float = (collision_point - right_hand_pointer.global_position).length()
			scene_pointer_mesh.mesh.size.z = pointer_length
			scene_pointer_mesh.position.z = -pointer_length / 2.0

			var collider: CollisionObject3D = right_hand_pointer_raycast.get_collider()
			if collider and collider.get_collision_layer_value(3):
				selected_spatial_anchor_node = collider
			else:
				selected_spatial_anchor_node = null
		else:
			scene_pointer_mesh.mesh.size.z = 5
			scene_pointer_mesh.position.z = -2.5
			selected_spatial_anchor_node = null

		if previous_selected_spatial_anchor_node != selected_spatial_anchor_node:
			if previous_selected_spatial_anchor_node:
				previous_selected_spatial_anchor_node.set_selected(false)
			if selected_spatial_anchor_node:
				selected_spatial_anchor_node.set_selected(true)
				scene_colliding_mesh.visible = false
			else:
				scene_colliding_mesh.visible = true


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
	if name == "trigger_click" and right_hand_pointer.visible:
		if right_hand_pointer_raycast.is_colliding():
			if selected_spatial_anchor_node:
				var anchor_parent = selected_spatial_anchor_node.get_parent()
				if anchor_parent is XRAnchor3D:
					spatial_anchor_manager.untrack_anchor(anchor_parent.tracker)
			else:
				var anchor_transform := Transform3D()
				anchor_transform.origin = right_hand_pointer_raycast.get_collision_point()

				var collision_normal: Vector3 = right_hand_pointer_raycast.get_collision_normal()
				if collision_normal.is_equal_approx(Vector3.UP):
					anchor_transform.basis = anchor_transform.basis.rotated(Vector3(1.0, 0.0, 0.0), PI / 2.0)
				elif collision_normal.is_equal_approx(Vector3.DOWN):
					anchor_transform.basis = anchor_transform.basis.rotated(Vector3(1.0, 0.0, 0.0), -PI / 2.0)
				else:
					anchor_transform.basis = Basis.looking_at(right_hand_pointer_raycast.get_collision_normal())

				spatial_anchor_manager.create_anchor(anchor_transform, {color = COLORS[randi() % COLORS.size()]})
	elif name == "ax_button":
		light_mode = (light_mode + 1) % LIGHT_MODES.size()
		_apply_light_mode()
		_save_preferences()
	elif name == "by_button":
		panel.visible = not panel.visible


func _on_scene_manager_scene_capture_completed(success: bool) -> void:
	hint_label.text = "SCAN COMPLETE" if success else "SCAN CANCELLED OR UNAVAILABLE"
	if success:
		# Recreate scene anchors since the user may have changed them.
		if scene_manager.are_scene_anchors_created():
			scene_manager.remove_scene_anchors()
		scene_manager.create_scene_anchors()


func _on_scene_manager_scene_data_missing() -> void:
	scene_manager.request_scene_capture()
