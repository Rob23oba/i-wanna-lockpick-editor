@tool
extends Control
class_name LockTypeEditor
# I feel bad for copy-pasting all the code from the base class. I'll have to modify this if I change how that one works...

signal changed_type()

const LOCK := preload("res://level_elements/doors_locks/lock.tscn")

## the length in pixels of the locks' square sides
@export var lock_size := 14

## the separation in pixels between locks
var lock_sep := 10
## the minimum amount of rows to force
var min_rows := 1
## the full length in pixels that a lock will "occupy"
## taking into account [member lock_size] and [member lock_sep]
var lock_occupied_size: int:
	get:
		return lock_size + lock_sep

## the locks that the editor has as children
var locks: Array[Lock] = []

## Lock by Enums.LockTypes
var lock_by_type: Dictionary

## how many locks there'll be per row
var locks_per_row: int
## free space in the row with the most locks, after placing the locks
var free_space: float
## amount of rows we're actually using
var row_count: int

var _is_clicking_inside := false

@onready var color_rect: ColorRect = $SelectedOutline
var selected_lock: Lock = null:
	set(val):
		if selected_lock == val: return
		selected_lock = val
		if selected_lock != null:
			changed_type.emit()
var color: Enums.Colors = Enums.Colors.None:
	set(val):
		color = val
		for lock in locks:
			lock.lock_data.color = color
			lock.update_visuals()
var type: Enums.LockTypes:
	set = set_to_type,
	get = get_current_type

var is_ready := false
func _ready():
	is_ready = true
	for lock_type in Enums.LockTypes.values():
		var l := LOCK.instantiate()
		var ld := LockData.new()
		ld.color = color
		ld.lock_type = lock_type
		# Lock will draw it 4px smaller to account for frame
		ld.size = Vector2i.ONE * (lock_size + 4)
		l.ignore_position = true
		l.lock_data = ld
		locks.push_back(l)
		lock_by_type[lock_type] = l
		add_child(l)
	resized.connect(_redistribute_locks)
	_redistribute_locks()
	custom_minimum_size.x = lock_size
	custom_minimum_size.y = lock_size

func _redistribute_locks() -> void:
	var max_locks_per_row := floori(size.x / lock_occupied_size)
	if max_locks_per_row <= 0: max_locks_per_row = 1
	# Round up so there's always at least 1 row
	row_count = ((locks.size() + max_locks_per_row - 1) / max_locks_per_row)
	row_count = maxi(row_count, min_rows)
	# Also round up to get the amount of locks in the longest row
	locks_per_row = (locks.size() + row_count - 1) / row_count
	
	free_space = size.x - (locks_per_row * lock_size + (locks_per_row - 1) * lock_sep)
	custom_minimum_size.y = row_count * lock_occupied_size
	for i in locks.size():
		# -2 because locks are drawn taking frame into account
		var x := free_space / 2.0 + (i % locks_per_row) * lock_occupied_size - 2 
		var y := (i / locks_per_row) * lock_occupied_size + lock_sep / 2.0 - 2
		var lock := locks[i]
		lock.position = Vector2(x, y)
	_reposition_color_rect()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos := get_local_mouse_position()
				if _is_point_inside(mouse_pos):
					_detect_selected_lock(mouse_pos)
					accept_event()
					_is_clicking_inside = true
			else:
				_is_clicking_inside = false
	elif (event is InputEventMouseMotion) and _is_clicking_inside:
		var mouse_pos := get_local_mouse_position()
		_detect_selected_lock(mouse_pos)
		accept_event()

func _detect_selected_lock(mouse_pos: Vector2) -> void:
	var virtual_rect := Rect2(
		Vector2(free_space / 2.0, 0), 
			Vector2(
				size.x - free_space,
				row_count * lock_occupied_size
			)
		)
	var grid_pos := Vector2i((mouse_pos - virtual_rect.position) / lock_occupied_size)
	grid_pos.x = clampi(grid_pos.x, 0, locks_per_row - 1)
	grid_pos.y = clampi(grid_pos.y, 0, row_count - 1)
	var i := grid_pos.x + grid_pos.y * locks_per_row
	i = clampi(i, 0, locks.size() - 1)
	selected_lock = locks[i]
	_reposition_color_rect()

func _is_point_inside(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)

func _reposition_color_rect() -> void:
	color_rect.size = Vector2.ONE * (lock_size + 4 + 4)
	if not is_instance_valid(selected_lock):
		color_rect.hide()
	else:
		color_rect.show()
		color_rect.position = selected_lock.position - Vector2.ONE * 2

func set_to_type(new_type: Enums.LockTypes) -> void:
	selected_lock = lock_by_type[new_type]

func get_current_type() -> Enums.LockTypes:
	return selected_lock.lock_data.lock_type
