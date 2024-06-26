@tool
extends Container
class_name ObjectGridChooser
## Children will be distributed as horizontally as possible on a grid.
## They'll also have their mouse filter set to MOUSE_FILTER_IGNORE

signal object_selected(obj: Node)

@export var object_size := 32:
	set = set_object_size
@export var selected_color := Color(1, 1, 1, 0.3):
	set = set_selected_color
## the separation in pixels between objects
@export var object_sep := 10:
	set = set_object_sep
## the minimum amount of rows to force
@export var min_rows := 1:
	set = set_min_rows
@export var color_rect_extend := 0:
	set = set_color_rect_extend
@export var color_rect_offset := Vector2.ZERO:
	set = set_color_rect_offset

## the currently selected child
var selected_object: Control:
	set(val):
		var pos := _visible_children.find(val)
		# Isn't a visible child. ok. try to adapt.
		if pos == -1:
			selected_object_i = maxi(selected_object_i, 0)
		else:
			selected_object_i = pos
	get:
		if selected_object_i == -1:
			return null
		return _visible_children[selected_object_i]

var selected_object_i := -1:
	set(val):
		val = clampi(val, -1, _visible_children.size() - 1)
		if selected_object_i == val: return
		selected_object_i = val
		_reposition_color_rect()
		if selected_object_i != -1:
			object_selected.emit(_visible_children[selected_object_i])

# the full length in pixels that a object will "occupy"
# taking into account [member object_size] and [member object_sep]
var _object_occupied_size: int:
	get:
		return object_size + object_sep
# how many objects there'll be per row (except the smallest row)
var _objects_per_row: int
# free space in the row with the most objects, after placing the objects
var _free_space: float
# amount of rows we're actually using
var _row_count: int = -1

var _is_clicking_inside := false

var _color_rect: ColorRect

func _ready() -> void:
	_color_rect = ColorRect.new()
	add_child(_color_rect, 0, Node.INTERNAL_MODE_FRONT)
	_color_rect.color = selected_color
	_color_rect.size = Vector2(object_size, object_size)
	set_object_size(object_size)
	set_selected_color(selected_color)
	selected_object_i = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_redistribute_children()

func set_object_size(new_size: int) -> void:
	object_size = new_size
	queue_sort()

func set_selected_color(new_color: Color) -> void:
	selected_color = new_color
	if _color_rect:
		_color_rect.color = selected_color

func set_object_sep(new_sep: int) -> void:
	object_sep = new_sep
	queue_sort()

func set_min_rows(new_min_rows: int) -> void:
	min_rows = new_min_rows
	if min_rows > _row_count:
		queue_sort()

func set_color_rect_extend(val: int) -> void:
	color_rect_extend = val
	_reposition_color_rect()

func set_color_rect_offset(val: Vector2) -> void:
	color_rect_offset = val
	_reposition_color_rect()

func clear() -> void:
	while get_child_count() != 0:
		var child := get_child(-1)
		remove_child(child)
		child.queue_free()
	_visible_children.clear()

var _visible_children: Array[Node] = []
func update_visible_children() -> void:
	var previously_selected := selected_object
	# If something was hidden or things were reordered, try to keep the same thing selected
	# (This also makes sure it always selects something as long as there's children)
	_visible_children = get_children().filter(func(child: Node): return child.visible)
	selected_object = previously_selected

func _redistribute_children() -> void:
	update_visible_children()
	var max_objects_per_row := floori(size.x / _object_occupied_size)
	if max_objects_per_row <= 0: max_objects_per_row = 1
	# Round up so there's always at least 1 row
	_row_count = ((get_child_count() + max_objects_per_row - 1) / max_objects_per_row)
	_row_count = maxi(_row_count, min_rows)
	# Also round up to get the amount of objects in the longest row
	_objects_per_row = (get_child_count() + _row_count - 1) / _row_count
	
	_free_space = size.x - (_objects_per_row * object_size + (_objects_per_row - 1) * object_sep)
	custom_minimum_size.y = _row_count * _object_occupied_size
	custom_minimum_size.x = _object_occupied_size
	for i in _visible_children.size():
		var x := _free_space / 2.0 + (i % _objects_per_row) * _object_occupied_size
		var y := (i / _objects_per_row) * _object_occupied_size + object_sep / 2.0
		var child := _visible_children[i]
		child.position = Vector2(x, y)
		if child is Control:
			child.size = Vector2(object_size, object_size)
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		i += 1
	_reposition_color_rect()

func _get_configuration_warnings() -> PackedStringArray:
	for child in get_children():
		if not child is Control:
			return ["All children should be Control nodes"]
	return []

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos := get_local_mouse_position()
				if _is_point_inside(mouse_pos):
					_detect_selected_object(mouse_pos)
					accept_event()
					_is_clicking_inside = true
			else:
				_is_clicking_inside = false
	elif (event is InputEventMouseMotion) and _is_clicking_inside:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_is_clicking_inside = false
			return
		var mouse_pos := get_local_mouse_position()
		_detect_selected_object(mouse_pos)
		accept_event()

func _detect_selected_object(mouse_pos: Vector2) -> void:
	var virtual_rect := Rect2(
		Vector2(_free_space / 2.0, 0), 
			Vector2(
				size.x - _free_space,
				_row_count * _object_occupied_size
			)
		)
	var grid_pos := Vector2i((mouse_pos - virtual_rect.position) / _object_occupied_size)
	grid_pos.x = clampi(grid_pos.x, 0, _objects_per_row - 1)
	grid_pos.y = clampi(grid_pos.y, 0, _row_count - 1)
	var i := grid_pos.x + grid_pos.y * _objects_per_row
	i = clampi(i, 0, _visible_children.size() - 1)
	selected_object = _visible_children[i]
	_reposition_color_rect()

func _is_point_inside(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)

func _reposition_color_rect() -> void:
	if not _color_rect: return
	_color_rect.size = Vector2.ONE * (object_size + color_rect_extend * 2)
	# In case it's invalid somehow, this should call the setter and fix it
	selected_object_i = selected_object_i
	if not is_instance_valid(selected_object):
		_color_rect.hide()
	else:
		_color_rect.show()
		_color_rect.position = selected_object.position - Vector2.ONE * color_rect_extend + color_rect_offset
