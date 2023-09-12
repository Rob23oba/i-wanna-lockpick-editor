extends Control
class_name LevelContainer
## Contains the level, centered, and at the correct aspect ratio
## Also is just the level editor for general input reasons (this should've been LevelContainerInner maybe but it's not that strong of a reason to clutter the responsibilities further)

@export var inner_container: Control
@export var level: Level
@export var level_viewport: SubViewport

@export var tile_map: TileMap
@export var door_editor: DoorEditor
@export var key_editor: KeyEditor

@export var ghost_door: Door
@export var ghost_key: Key
@export var ghost_canvas_group: CanvasGroup

@export var editor: LockpickEditor
var editor_data: EditorData

@export var danger_highlight: HoverHighlight
@export var selected_highlight: HoverHighlight
var hover_highlight: HoverHighlight:
	get:
		return editor_data.hover_highlight

# Ghosts shouldn't be seen when something's being dragged

var is_dragging := false:
	get:
		if selected_obj == null or Input.is_action_pressed(&"unbound_action"):
			is_dragging = false
		return is_dragging
	set(val):
		is_dragging = val and selected_obj != null and not Input.is_action_pressed(&"unbound_action")
var drag_offset := Vector2i.ZERO
var selected_obj: Node:
	set(val):
		selected_highlight.adapt_to(val)
	get:
		return selected_highlight.current_obj
var hovered_obj: Node:
	set(val):
		hover_highlight.adapt_to(val)
	get:
		return hover_highlight.current_obj
var danger_obj: Node:
	set(val):
		danger_highlight.adapt_to(val)
	get:
		return danger_highlight.current_obj
#var level_offset :=  Vector2(0, 0)

const OBJ_SIZE := Vector2(800, 608)
func _on_resized() -> void:
	# center it
	inner_container.position = (size - OBJ_SIZE) / 2
	inner_container.size = OBJ_SIZE

func _ready() -> void:
	level.door_gui_input.connect(_on_door_gui_input)
	level.key_gui_input.connect(_on_key_gui_input)
	resized.connect(_on_resized)
	level_viewport.size = Vector2i(800, 608) * 1.5
	level_viewport.get_parent().show()
	ghost_canvas_group.self_modulate.a = 0.5
	
	await get_tree().process_frame
	editor_data.selected_highlight = selected_highlight
	editor_data.danger_highlight = danger_highlight
	editor_data.hover_highlight = level.hover_highlight
	
	editor_data.side_tabs.tab_changed.connect(_retry_ghosts.unbind(1))
	editor_data.level.changed_doors.connect(_retry_ghosts)
	editor_data.level.changed_keys.connect(_retry_ghosts)
	editor_data.changed_level_data.connect(_on_changed_level_data)
	# deferred: fixes the door staying at the old mouse position (since the level pos moves when the editor kicks in)
	editor_data.changed_is_playing.connect(_retry_ghosts, CONNECT_DEFERRED)
	_retry_ghosts()
	selected_highlight.adapted_to.connect(_on_selected_highlight_adapted_to)

func _on_changed_level_data() -> void:
	# deselect everything
	selected_obj = null
	hovered_obj = null
	danger_obj = null

func _on_door_gui_input(event: InputEvent, door: Door) -> void:
	if editor_data.disable_editing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if remove_door(door):
					accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				editor_data.door_editor.door_data = door.door_data
				editor_data.side_tabs.current_tab = editor_data.side_tabs.get_tab_idx_from_control(editor_data.door_editor)
				accept_event()
				select_thing(door)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.is_action_pressed(&"unbound_action"):
			if remove_door(door):
				accept_event()

func _on_key_gui_input(event: InputEvent, key: Key) -> void:
	if editor_data.disable_editing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if remove_key(key):
					accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				editor_data.key_editor.key_data = key.key_data
				editor_data.side_tabs.current_tab = editor_data.side_tabs.get_tab_idx_from_control(editor_data.key_editor)
				accept_event()
				select_thing(key)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.is_action_pressed(&"unbound_action"):
			if remove_key(key):
				accept_event()


func _gui_input(event: InputEvent) -> void:
	if editor_data.disable_editing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				# if the event got this far, we want to deselect
				selected_obj = null
				if editor_data.tilemap_edit:
					place_tile_on_mouse()
					accept_event()
				elif editor_data.doors:
					if place_door_on_mouse():
						accept_event()
				elif editor_data.keys:
					if place_key_on_mouse():
						accept_event()
				elif editor_data.level_properties:
					if editor_data.player_spawn:
						place_player_spawn_on_mouse()
						accept_event()
					elif editor_data.goal_position:
						place_goal_on_mouse()
						accept_event()
			else: # mouse button released
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				selected_obj = null
				if remove_tile_on_mouse():
					accept_event()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if selected_obj && is_dragging:
				relocate_selected()
			elif Input.is_action_pressed(&"unbound_action"):
				if editor_data.doors:
					if place_door_on_mouse():
						accept_event()
				elif editor_data.keys:
					if place_key_on_mouse():
						accept_event()
			elif editor_data.tilemap_edit:
				place_tile_on_mouse()
				accept_event()
			elif editor_data.level_properties:
				if editor_data.player_spawn:
					place_player_spawn_on_mouse()
					accept_event()
				elif editor_data.goal_position:
					place_goal_on_mouse()
					accept_event()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
#			if editor_data.tilemap_edit:
				if remove_tile_on_mouse():
					accept_event()
		_retry_ghosts()

func select_thing(obj: Node) -> void:
	# is_dragging is set to true by _on_selected_highlight_adapted_to
	selected_obj = obj
	hovered_obj = obj
	danger_obj = null
	_retry_ghosts()

func place_tile_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord := get_mouse_tile_coord(32)
	level.place_tile(coord)

func remove_tile_on_mouse() -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord := get_mouse_tile_coord(32)
	return level.remove_tile(coord)

func place_door_on_mouse() -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord := get_mouse_coord(32)
	var door_data := door_editor.door.door_data.duplicated()
	door_data.position = coord
	var door := level.add_door(door_data)
	if not is_instance_valid(door): return false
	select_thing(door)
	return true

func remove_door(door: Door = null) -> bool:
	if not is_instance_valid(door): return false
	level.remove_door(door)
	selected_obj = null
	hovered_obj = null
	_retry_ghosts()
	return true

func remove_key(key: Key = null) -> bool:
	if not is_instance_valid(key): return false
	level.remove_key(key)
	select_thing(key)
	_retry_ghosts()
	return true

func place_key_on_mouse() -> bool:
	if editor_data.disable_editing: return false
	if is_mouse_out_of_bounds(): return false
	var coord := get_mouse_coord(16)
	var key_data := key_editor.key.key_data.duplicated()
	key_data.position = coord
	var key := level.add_key(key_data)
	if not is_instance_valid(key): return false
	selected_obj = key
	hovered_obj = key
	danger_obj = null
	return true

func place_player_spawn_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord := get_mouse_coord(16)
	level.place_player_spawn(coord)

func place_goal_on_mouse() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	var coord := get_mouse_coord(16)
	level.place_goal(coord)

func relocate_selected() -> void:
	if editor_data.disable_editing: return
	if is_mouse_out_of_bounds(): return
	if not is_dragging: return
	if not is_instance_valid(selected_obj): return
	var grid_size := 32
	if selected_obj is Door:
		grid_size = 32
	elif selected_obj is Key:
		grid_size = 16
	var used_coord := get_mouse_coord(grid_size) - round_coord(drag_offset, grid_size)
	var cond: bool
	var obj_pos: Vector2i = selected_obj.position
	if selected_obj is Door:
		cond = level.move_door(selected_obj, used_coord)
	elif selected_obj is Key:
		cond = level.move_key(selected_obj, used_coord)
	else:
		assert(false)
	
	if not cond and obj_pos != used_coord:
		_place_danger_obj()
	else:
		danger_obj = null
	# refreshes the position
	selected_obj = selected_obj
	hovered_obj = hovered_obj



func get_mouse_coord(grid_size: int) -> Vector2i:
	return round_coord(Vector2i(get_global_mouse_position() - get_level_pos()), grid_size)

func get_mouse_tile_coord(grid_size: int) -> Vector2i:
	return Vector2i((get_global_mouse_position() - get_level_pos()) / Vector2(grid_size, grid_size))

func round_coord(coord: Vector2i, grid_size: int) -> Vector2i:
	return coord / Vector2i(grid_size, grid_size) * Vector2i(grid_size, grid_size)

func is_mouse_out_of_bounds() -> bool:
	var local_pos := get_global_mouse_position() - get_level_pos()
	if local_pos.x < 0 or local_pos.y < 0 or local_pos.x >= level.level_data.size.x or local_pos.y >= level.level_data.size.y:
		return true
	return false

func get_level_pos() -> Vector2:
	return level_viewport.get_parent().global_position + level.global_position - level.get_camera_position()

#var unique_queue := {}
#func _defer_unique(f: Callable) -> void:
#	if not unique_queue.get(f):
#		unique_queue[f] = true
#		f.call_deferred()
#		_erase_from_queue.bind(f).call_deferred()
#
#func _erase_from_queue(f: Callable) -> void:
#	unique_queue[f] = false


func _retry_ghosts() -> void:
	ghost_key.hide()
	ghost_door.hide()
	
	if not is_dragging:
		_place_ghosts()

func _place_ghosts() -> void:
	assert(not is_dragging)
	for i in 2:
		var grid_size: int = [32, 16][i]
		var obj: Node = [ghost_door, ghost_key][i]
		var cond: bool = [editor_data.doors, editor_data.keys][i]
		
		if not cond or editor_data.is_playing:
			continue
		if obj is Door:
			obj.door_data = door_editor.door_data
		elif obj is Key:
			obj.key_data = key_editor.key_data
		var maybe_pos := get_mouse_coord(grid_size)
		obj.position = maybe_pos
		
		var is_valid := true
		
		
		if not Rect2i(Vector2i.ZERO, level.level_data.size).has_point(maybe_pos):
			is_valid = false
		elif level.is_space_occupied(Rect2i(maybe_pos, obj.get_rect().size)):
			is_valid = false
		elif obj is Door and not obj.door_data.check_valid(level.level_data, false):
			is_valid = false
		obj.visible = is_valid
		
		if (
		not is_instance_valid(level.hovering_over)
		and not obj.visible
		# TODO: This is just a double-check, but looks weird since tiles can't be hovered on yet
	#	and not level.is_space_occupied(Rect2i(get_mouse_coord(1), Vector2.ONE))
		):
			danger_obj = obj
		else:
			danger_obj = null

# places the danger obj only. this overrides the ghosts obvs
func _place_danger_obj() -> void:
	for i in 2:
		var grid_size: int = [32, 16][i]
		var obj: Node = [ghost_door, ghost_key][i]
		var cond: bool = [editor_data.doors, editor_data.keys][i]
		
		if not cond or editor_data.is_playing:
			continue
		if obj is Door:
			obj.door_data = door_editor.door_data
		elif obj is Key:
			obj.key_data = key_editor.key_data
		
		var maybe_pos := get_mouse_coord(grid_size)
		if is_dragging:
			maybe_pos -= round_coord(drag_offset, grid_size)
		obj.position = maybe_pos
		danger_obj = obj


func _on_selected_highlight_adapted_to(_obj: Node) -> void:
	if (Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_LEFT):
		if not is_dragging:
			is_dragging = true
			drag_offset = get_mouse_coord(1) - Vector2i(_obj.position)
