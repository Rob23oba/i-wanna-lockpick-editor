@tool
extends Control
# Shouldn't call it Key because there's a global enum called Key!
class_name KeyElement
## Key lol

signal picked_up
static var level_element_type := Enums.LevelElementTypes.Key

@export var data: KeyData:
	set(val):
		if data == val: return
		_disconnect_data()
		data = val
		_connect_data()
@export var hide_shadow := false
@export var ignore_position := false

@onready var shadow: Sprite2D = %Shadow
@onready var fill: Sprite2D = %Fill
@onready var outline: Sprite2D = %Outline
@onready var special: Sprite2D = %Special
@onready var glitch: Sprite2D = %SprGlitch

@onready var snd_pickup: AudioStreamPlayer = %Pickup
@onready var number: Label = %Number
@onready var symbol: Sprite2D = %Symbol
@onready var symbol_inf: Sprite2D = %SymbolInf
@onready var collision: Area2D = %Collision

var level: Level = null:
	set(val):
		if level == val: return
		disconnect_level()
		level = val
		connect_level()

func _ready() -> void:
	collision.disable_mode = CollisionObject2D.DISABLE_MODE_REMOVE
	_resolve_collision_mode()
	if hide_shadow:
		shadow.hide()
	collision.area_entered.connect(on_collide)
	update_visual()

func disconnect_level() -> void:
	if not is_instance_valid(level): return

func connect_level() -> void:
	if not is_instance_valid(level): return
	update_glitch_color()

func update_glitch_color() -> void:
	if not is_instance_valid(data): return
	data.update_glitch_color(level.logic.glitch_color)
	update_visual()

func _connect_data() -> void:
	if not is_instance_valid(data): return
	data.changed.connect(update_visual)
	update_visual()
	# look... ok?
	show()
	if not is_node_ready(): return
	_resolve_collision_mode()

func _disconnect_data() -> void:
	if is_instance_valid(data):
		data.changed.disconnect(update_visual)

func _process(_delta: float) -> void:
	if !data: return
	if data.color in [Enums.Colors.Master, Enums.Colors.Pure]:
		var frame := floori(Global.time / Rendering.SPECIAL_ANIM_DURATION) % 4
		if frame == 3:
			frame = 1
		special.frame = (special.frame % 4) + frame * 4

func _resolve_collision_mode() -> void:
	if not is_instance_valid(level) or data.is_spent:
		collision.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		collision.process_mode = Node.PROCESS_MODE_INHERIT

func set_special_texture(color: Enums.Colors) -> void:
	match color:
		Enums.Colors.Stone:
			special.texture = preload("res://level_elements/keys/spr_key_stone.png")
			special.vframes = 2
		Enums.Colors.Master:
			special.texture = preload("res://level_elements/keys/spr_key_master.png")
			special.vframes = 4
		Enums.Colors.Pure:
			special.texture = preload("res://level_elements/keys/spr_key_pure.png")
			special.vframes = 4

func update_visual() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(data): return
	if not ignore_position: position = data.position
	fill.hide()
	outline.hide()
	special.hide()
	glitch.hide()
	number.hide()
	symbol.hide()
	symbol_inf.hide()
	# get the outline / shadow / fill
	var spr_frame = {
		Enums.KeyTypes.Exact: 1,
		Enums.KeyTypes.Star: 2,
		Enums.KeyTypes.Unstar: 3,
	}.get(data.type)
	if spr_frame == null: spr_frame = 0
	shadow.frame = spr_frame
	fill.frame = spr_frame
	outline.frame = spr_frame
	special.frame = spr_frame
	glitch.frame = spr_frame
	symbol_inf.visible = data.is_infinite
	if data.color == Enums.Colors.Master and data.type == Enums.KeyTypes.Add:
		shadow.frame = 4
	if data.color in [Enums.Colors.Master, Enums.Colors.Pure, Enums.Colors.Stone]:
		special.show()
		set_special_texture(data.color)
	elif data.color == Enums.Colors.Glitch:
		glitch.show()
		if is_instance_valid(level) and level.logic.glitch_color != Enums.Colors.Glitch:
			if level.logic.glitch_color in [Enums.Colors.Master, Enums.Colors.Pure, Enums.Colors.Stone]:
				special.show()
				set_special_texture(level.logic.glitch_color)
				special.frame = special.frame % 4 + 4 * (special.vframes - 1)
			else:
				fill.show()
				fill.frame = fill.frame % 4 + 4
				fill.modulate = Rendering.key_colors[level.logic.glitch_color]
	else:
		fill.show()
		outline.show()
		fill.modulate = Rendering.key_colors[data.color]
	
	
	# draw the number
	if data.type == Enums.KeyTypes.Add or data.type == Enums.KeyTypes.Exact:
		number.show()
		number.text = str(data.amount)
		if number.text == "1":
			number.text = ""
		# sign color
		var i := 1 if data.amount.is_negative() else 0
		number.add_theme_color_override(&"font_color", Rendering.key_number_colors[i])
		number.add_theme_color_override(&"font_outline_color", Rendering.key_number_colors[i])
		number.add_theme_color_override(&"font_shadow_color", Rendering.key_number_colors[1-i])
	# or the symbol
	else:
		var frame = {
			Enums.KeyTypes.Flip: 0,
			Enums.KeyTypes.Rotor: 1,
			Enums.KeyTypes.RotorFlip: 2,
		}.get(data.type)
		if frame != null:
			symbol.frame = frame
			symbol.show()

func on_collide(_who: Node2D) -> void:
	if data.is_spent:
		print("is spent so nvm")
		return
	on_pickup()

func get_mouseover_text() -> String:
	return data.get_mouseover_text()

func undo() -> void:
	# HACK: fix for undoing at the same time that key is picked up making the key be picked up again after undoing
	await get_tree().physics_frame
	show()
	data.is_spent = false
	_resolve_collision_mode()
	for area in collision.get_overlapping_areas():
		on_collide(area)

func redo() -> void:
	if not data.is_infinite:
		data.is_spent = true
	_resolve_collision_mode()
	hide()

func on_pickup() -> void:
	level.logic.pick_up_key(self)
	
	
	picked_up.emit()
	
	snd_pickup.pitch_scale = 1
	if data.color == Enums.Colors.Master:
		snd_pickup.stream = preload("res://level_elements/keys/master_pickup.wav")
		if data.amount.is_negative():
			snd_pickup.pitch_scale = 0.82
	elif data.type in [Enums.KeyTypes.Flip, Enums.KeyTypes.Rotor, Enums.KeyTypes.RotorFlip]:
		snd_pickup.stream = preload("res://level_elements/keys/signflip_pickup.wav")
	elif data.type == Enums.KeyTypes.Star:
		snd_pickup.stream = preload("res://level_elements/keys/star_pickup.wav")
	elif data.type == Enums.KeyTypes.Unstar:
		snd_pickup.stream = preload("res://level_elements/keys/unstar_pickup.wav")
	elif data.amount.is_negative():
		snd_pickup.stream = preload("res://level_elements/keys/negative_pickup.wav")
	else:
		snd_pickup.stream = preload("res://level_elements/keys/key_pickup.wav")
	snd_pickup.play()
