@tool
extends MarginContainer
class_name Door

const LOCK := preload("res://rendering/doors_locks/lock_visual.tscn")
const DEBRIS := preload("res://rendering/doors_locks/debris/door_debris.tscn")
const FRAME_POS := preload("res://rendering/doors_locks/door_frame_texture_pos.png")
const FRAME_NEG := preload("res://rendering/doors_locks/door_frame_texture_neg.png")

@export var door_data: DoorData

@onready var color_light: NinePatchRect = %ColorLight
@onready var color_mid: NinePatchRect = %ColorMid
@onready var color_dark: NinePatchRect = %ColorDark
@onready var special_anim: Sprite2D = %SpecialAnim # master and pure
@onready var stone_texture: TextureRect = %StoneTexture
@onready var glitch: Control = %Glitch

@onready var frame := %Frame as NinePatchRect

@onready var static_body := %StaticBody2D as StaticBody2D
@onready var lock_holder := %LockHolder as Control

@onready var ice: MarginContainer = %Ice
@onready var paint: TextureRect = %Paint
@onready var erosion: MarginContainer = %Erosion
@onready var brown_curse: Control = %BrownCurse

@onready var snd_open: AudioStreamPlayer = %Open

func _ready() -> void:
	static_body.disable_mode = CollisionObject2D.DISABLE_MODE_REMOVE
	if not Global.in_editor:
		door_data = door_data.duplicated()
	door_data.changed.connect(update_everything)
	update_everything()
	var timer := Timer.new()
	timer.timeout.connect(create_debris)
	add_child(timer)
	timer.start(0.1)


func _physics_process(_delta: float) -> void:
	special_anim.frame = floori(Global.time / Rendering.SPECIAL_ANIM_SPEED) % special_anim.hframes * special_anim.vframes

func update_everything() -> void:
	update_textures()
	update_locks()
	update_curses()

func update_textures() -> void:
	size = door_data.size
	static_body.scale = size
	frame.texture = FRAME_POS if door_data.amount[0].real_part >= 0 else FRAME_NEG
	
	color_light.hide()
	color_mid.hide()
	color_dark.hide()
	special_anim.hide()
	stone_texture.hide()
	glitch.hide()
	
	var used_color := door_data.outer_color
	
	if used_color == Enums.color.glitch:
		glitch.show()
		if door_data.glitch_color == Enums.color.glitch:
			glitch.texture = preload("res://rendering/doors_locks/glitch_door.png")
			return
		else:
			used_color = door_data.glitch_color
			glitch.texture = preload("res://rendering/doors_locks/glitch_door_2.png")
			if used_color in [Enums.color.master, Enums.color.pure]:
				special_anim.show()
				special_anim.hframes = 1
				special_anim.scale = size / Vector2(1,58)
				special_anim.texture = {
					Enums.color.master: preload("res://rendering/doors_locks/gold_glitch_door.png"),
					Enums.color.pure: preload("res://rendering/doors_locks/pure_glitch_door.png")
				}[used_color]
				return
	
	if used_color in [Enums.color.master, Enums.color.pure]:
		special_anim.show()
		special_anim.scale = size / Vector2(1,64)
		special_anim.hframes = 4
		special_anim.texture = {
			Enums.color.master: preload("res://rendering/doors_locks/gold_gradient.png"),
			Enums.color.pure: preload("res://rendering/doors_locks/pure_gradient.png")
		}[used_color]
	elif used_color == Enums.color.stone:
		stone_texture.show()
	else: # most colors
		color_light.show()
		color_mid.show()
		color_dark.show()
		color_light.modulate = Rendering.color_colors[used_color][1]
		color_mid.modulate = Rendering.color_colors[used_color][0]
		color_dark.modulate = Rendering.color_colors[used_color][2]

func update_locks() -> void:
	for lock in lock_holder.get_children():
		lock.queue_free()
	for lock in door_data.locks:
		var new_lock := LOCK.instantiate()
		new_lock.lock_data = lock
		lock_holder.add_child(new_lock)

func update_curses() -> void:
	ice.visible = door_data.get_curse(Enums.curses.ice)
	erosion.visible = door_data.get_curse(Enums.curses.eroded)
	paint.visible = door_data.get_curse(Enums.curses.painted)
	brown_curse.visible = door_data.get_curse(Enums.curses.brown)

func try_open() -> void:
	if door_data.try_open():
		snd_open.play()
		create_debris()
	if door_data.amount[0].is_zero():
		hide()
		static_body.process_mode = Node.PROCESS_MODE_DISABLED

# do the effects for the curses
func break_curse_ice() -> void:
	if not door_data.get_curse(Enums.curses.ice): return
	door_data.set_curse(Enums.curses.ice, false)

func break_curse_eroded() -> void:
	if not door_data.get_curse(Enums.curses.eroded): return
	door_data.set_curse(Enums.curses.eroded, false)

func break_curse_painted() -> void:
	if not door_data.get_curse(Enums.curses.painted): return
	door_data.set_curse(Enums.curses.painted, false)

func curse_brown() -> void:
	if door_data.get_curse(Enums.curses.brown): return
	door_data.set_curse(Enums.curses.brown, true)

func break_curse_brown() -> void:
	if not door_data.get_curse(Enums.curses.brown): return
	door_data.set_curse(Enums.curses.brown, false)

func create_debris() -> void:
	for x in floori(size.x / 16):
		for y in floori(size.y / 16):
			var debris := DEBRIS.instantiate()
			debris.can_move = true
			var timer := Timer.new()
			timer.timeout.connect(debris.queue_free)
			debris.add_child(timer)
			debris.color = door_data.outer_color
			if door_data.get_curse(Enums.curses.brown):
				debris.color = Enums.color.brown
			elif door_data.outer_color == Enums.color.glitch:
				debris.color = door_data.glitch_color
				debris.is_glitched_color = true
			debris.global_position = global_position
			debris.position.x += randf_range(-4, 4) + 16 * x
			debris.position.y += randf_range(0, 8) + 16 * y
			if Global.in_editor:
				add_child(debris)
			else:
				# TODO: don't put it on the root that's dum
				get_tree().root.add_child(debris)
			timer.start(20)
