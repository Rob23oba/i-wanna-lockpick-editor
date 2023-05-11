@tool
extends Resource
class_name LockData

signal changed_color
@export var color := Enums.colors.none:
	set(val):
		if color == val: return
		color = val
		changed_color.emit()
		changed.emit()

signal changed_magnitude
@export var magnitude := 1:
	set(val):
		if magnitude == val: return
		magnitude = val
		changed_magnitude.emit()
		changed.emit()

signal changed_sign
@export var sign := Enums.sign.positive:
	set(val):
		if sign == val: return
		sign = val
		changed_sign.emit()
		changed.emit()

signal changed_value_type
@export var value_type := Enums.value.real:
	set(val):
		if value_type == val: return
		value_type = val
		changed_value_type.emit()
		changed.emit()

signal changed_lock_type
@export var lock_type := Enums.lock_types.normal:
	set(val):
		if lock_type == val: return
		lock_type = val
		changed_lock_type.emit()
		changed.emit()

# visual settings
## displayed size
signal changed_size
@export var size := Vector2i(18, 18):
	set(val):
		if size == val: return
		size = val
		changed_size.emit()
		changed.emit()

## minimum size (editor info. the editor itself should enforce this to be the actual minimum size)
signal changed_minimum_size
var minimum_size := Vector2i(0, 0):
	set(val):
		if minimum_size == val: return
		minimum_size = val
		changed_minimum_size.emit()
		changed.emit()

## position in door
signal changed_position
@export var position := Vector2i(7, 7):
	set(val):
		if position == val: return
		position = val
		changed_position.emit()
		changed.emit()

signal changed_lock_arrangement
## the lock pattern to use, or -1 for numbers
## (nonexistent arrangements will default to numbers too)
@export var lock_arrangement := 0:
	set(val):
		if lock_arrangement == val: return
		lock_arrangement = val
		changed_lock_arrangement.emit()
		changed.emit()

signal changed_dont_show_lock
## if rendering as number, don't show the lock symbol
@export var dont_show_lock := false:
	set(val):
		if dont_show_lock == val: return
		dont_show_lock = val
		changed_dont_show_lock.emit()
		changed.emit()

## Variables modified by the door data for easier rendering. Not meant to be stored, but I guess they can be used for logic?
signal changed_glitch
var glitch_color := Enums.colors.glitch:
	set(val):
		if glitch_color == val: return
		glitch_color = val
		changed_glitch.emit()
		changed.emit()

signal changed_is_cursed
## When cursed, this is true to force the lock to be rendered brown.
var is_cursed := false:
	set(val):
		if is_cursed == val: return
		is_cursed = val
		changed_is_cursed.emit()
		changed.emit()

signal changed_dont_show_frame
## used if the door's count doesn't align with the i-view status, also hides locks (couldn't think of a good name that includes that)
var dont_show_frame := false:
	set(val):
		if dont_show_frame == val: return
		dont_show_frame = val
		changed_dont_show_frame.emit()
		changed.emit()

signal changed_rotation
## rotation for rendering i-view and negative doors without destructively affecting the lock data
var rotation := ComplexNumber.new_with(1, 0):
	set(val):
		if is_instance_valid(rotation):
			if rotation.changed.is_connected(_emit_changed_rotation):
				rotation.changed.disconnect(_emit_changed_rotation)
		if rotation.is_equal_to(val): return
		rotation = val
		if is_instance_valid(rotation):
			rotation.changed.connect(_emit_changed_rotation)
		_emit_changed_rotation()

func _emit_changed_rotation() -> void:
	changed_rotation.emit()
	changed.emit()

func _init() -> void:
	rotation = rotation.duplicate()

func duplicated() -> LockData:
	return duplicate()

func get_used_color() -> Enums.colors:
	var used_color := color
	if is_cursed:
		used_color = Enums.colors.brown
	elif used_color == Enums.colors.glitch:
		used_color = glitch_color
	return used_color

# I can't believe I made this lmao??? fine tho
const value_type_to_ComplexNumber_var: Dictionary = {
	Enums.value.real: &"real_part",
	Enums.value.imaginary: &"imaginary_part",
}
# returns the key count difference after opening, or null if it can't be opened
func open_with(key_count: ComplexNumber, flipped: bool, is_rotor: bool) -> ComplexNumber:
	# listen... it works lmao
	if flipped or is_rotor:
		var temp_lock: LockData = duplicate(true)
		if flipped:
			temp_lock.flip_sign()
		if is_rotor:
			temp_lock.rotor()
		return temp_lock.open_with(key_count, false, false)
	
	if lock_type == Enums.lock_types.all:
		if key_count.real_part == 0 and key_count.imaginary_part == 0:
			return null
		else:
			return key_count.duplicate().flip()
	if lock_type == Enums.lock_types.blank:
		if key_count.real_part != 0 or key_count.imaginary_part != 0:
			return null
		else:
			return ComplexNumber.new()
	
	var new_key_count := ComplexNumber.new()
	var signed_magnitude := magnitude if sign == Enums.sign.positive else -magnitude
	var relevant_value_sn: StringName = value_type_to_ComplexNumber_var[value_type]
	var relevant_value = key_count.get(relevant_value_sn)
	
	if abs(relevant_value) < magnitude or signi(relevant_value) != signi(signed_magnitude):
		return null
	
	match lock_type:
		Enums.lock_types.normal:
			new_key_count.set(relevant_value_sn, -signed_magnitude)
		Enums.lock_types.blast:
			new_key_count.set(relevant_value_sn, -relevant_value)
	
	return new_key_count

## no-nonsense returns the lockdata's amount as a complex number
func get_complex_amount() -> ComplexNumber:
	var val := magnitude
	if sign == Enums.sign.negative: val *= -1
	var num := ComplexNumber.new()
	if value_type == Enums.value.real:
		num.real_part = val
	else:
		num.imaginary_part = val
	return num

const flip_sign_dict := {
	Enums.sign.positive: Enums.sign.negative,
	Enums.sign.negative: Enums.sign.positive,
}
## should be useful for the editor
func flip_sign() -> LockData:
	sign = flip_sign_dict[sign]
	return self

const rotor_dict_value = {
	Enums.value.real: Enums.value.imaginary,
	Enums.value.imaginary: Enums.value.real,
}
## should be useful for the editor
func rotor() -> LockData:
	value_type = rotor_dict_value[value_type]
	if value_type == Enums.value.real:
		flip_sign()
	return self
