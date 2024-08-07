@tool
extends Control
class_name Lock

signal changed_lock_data
@export var lock_data: LockData:
	set(val):
		if lock_data == val: return
		_disconnect_lock_data()
		lock_data = val
		_connect_lock_data()

@export var ignore_position := false
var level: Level

func _connect_lock_data() -> void:
	if not is_instance_valid(lock_data): return
	if not is_node_ready(): return
	lock_data.changed.connect(update_visuals)
	lock_data.update_minimum_size()
	update_visuals()

func _disconnect_lock_data() -> void:
	if not is_instance_valid(lock_data): return
	if not is_node_ready(): return
	lock_data.changed.disconnect(update_visuals)

func update_visuals() -> void:
	update_position()
	
	update_size()
	
	update_frame_visible()
	draw_base()
	draw_locks()

func _ready() -> void:
	_connect_lock_data()

func _init() -> void:
	_create_canvas_items()

func _exit_tree() -> void:
	custom_minimum_size = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_destroy_canvas_items()

func update_position() -> void:
	if not ignore_position:
		position = lock_data.position

func update_size() -> void:
	custom_minimum_size = lock_data.size
	size = lock_data.size


func update_frame_visible() -> void:
	return
#	if lock_data.dont_show_frame:
#		RenderingServer.canvas_item_set_visible(locks, false)
#	else:
#		RenderingServer.canvas_item_set_visible(locks, true)

# Base is frame + color
func draw_base() -> void:
	assert(GLITCH_BASE_SHARED.get_size() == GLITCH_2_RECT.size)
	if not is_instance_valid(lock_data): return
	assert(PerfManager.start("Lock:draw_base"))
	
	RenderingServer.canvas_item_clear(base)
	RenderingServer.canvas_item_clear(glitch_rid)
	
	# Draw the frame
	var rect := Rect2(Vector2.ZERO, size)
	if not lock_data.dont_show_frame:
		var sign := lock_data.get_sign_rot()
		var frame_texture := FRAME_POS if sign == Enums.Sign.Positive else FRAME_NEG
		RenderingServer.canvas_item_add_nine_patch(base, rect, FRAME_RECT, frame_texture, FRAME_COORD, FRAME_COORD, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, false)
	
	# Draw the base
	rect = Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var used_color := lock_data.color
	if lock_data.is_cursed:
		used_color = Enums.Colors.Brown
	if used_color == Enums.Colors.Glitch:
		if lock_data.glitch_color == Enums.Colors.Glitch:
			RenderingServer.canvas_item_add_texture_rect(glitch_rid, rect, GLITCH_BASE)
			assert(PerfManager.end("Lock:draw_base"))
			return
		else:
			used_color = lock_data.glitch_color
			RenderingServer.canvas_item_add_nine_patch(glitch_rid, rect, GLITCH_2_RECT, GLITCH_BASE_SHARED.get_rid(), GLITCH_2_DIST, GLITCH_2_DIST, RenderingServer.NINE_PATCH_TILE, RenderingServer.NINE_PATCH_TILE)
	match used_color:
		Enums.Colors.Master, Enums.Colors.Pure:
			if lock_data.color == Enums.Colors.Glitch:
				var tex := GLITCH_MASTER if used_color == Enums.Colors.Master else GLITCH_PURE
				RenderingServer.canvas_item_add_texture_rect(base, rect, tex)
			else:
				var tex := BASE_MASTER if used_color == Enums.Colors.Master else BASE_PURE
				for i in 4:
					RenderingServer.canvas_item_add_animation_slice(base, Rendering.SPECIAL_ANIM_LENGTH, i * Rendering.SPECIAL_ANIM_DURATION, (i+1) * Rendering.SPECIAL_ANIM_DURATION)
					RenderingServer.canvas_item_add_texture_rect_region(base, rect, tex, Rect2(Vector2(i, 0) * BASE_ANIM_TILE_SIZE, BASE_ANIM_TILE_SIZE))
				RenderingServer.canvas_item_add_animation_slice(base, 1, 0, 1)
		Enums.Colors.Stone:
			RenderingServer.canvas_item_add_texture_rect(base, rect, BASE_STONE, true)
		Enums.Colors.None:
			pass
		Enums.Colors.Gate:
			var rect2 = rect
			rect2.size /= 2
			RenderingServer.canvas_item_add_rect(base, rect2, Color8(32, 32, 32))
			rect2.position.x += rect2.size.x
			RenderingServer.canvas_item_add_rect(base, rect2, Color8(255, 255, 255))
			rect2.position.y += rect2.size.x
			RenderingServer.canvas_item_add_rect(base, rect2, Color8(32, 32, 32))
			rect2.position.x -= rect2.size.x
			RenderingServer.canvas_item_add_rect(base, rect2, Color8(255, 255, 255))
		_: # normal colors
			RenderingServer.canvas_item_add_rect(base, rect, Rendering.color_colors[used_color][0])
		
	assert(PerfManager.end("Lock:draw_base"))

func draw_locks() -> void:
	assert(LOCKS_TEXTURE.get_size() == (LOCKS_SIZE * Vector2(16, 2)))
	assert(PerfManager.start(&"Lock::draw_locks"))
	RenderingServer.canvas_item_clear(locks)
	if lock_data.dont_show_locks:
		assert(PerfManager.end(&"Lock::draw_locks"))
		return
	
	var sign := lock_data.get_sign_rot()
	var value_type := lock_data.get_value_rot()
	var magnitude := lock_data.magnitude
	
	match lock_data.lock_type:
		Enums.LockTypes.Blast:
			RenderingServer.canvas_item_set_modulate(locks, Rendering.lock_colors[sign])
			var s := "x" if value_type == Enums.Value.Real else "+"
			LockCountDraw.draw_text(locks, s, 2)
			
			var si := LockCountDraw.get_min_size(s, 2)
			RenderingServer.canvas_item_set_transform(locks, Transform2D(0, (lock_data.size - (si)) / 2))
			
		Enums.LockTypes.All:
			RenderingServer.canvas_item_set_modulate(locks, Rendering.lock_colors[sign])
			LockCountDraw.draw_text(locks, "=", 2)
			
			var si := LockCountDraw.get_min_size("=", 2)
			RenderingServer.canvas_item_set_transform(locks, Transform2D(0, (lock_data.size - (si)) / 2))
			
		Enums.LockTypes.Normal:
			var arrangement = Rendering.get_lock_arrangement(level.level_data if level else null, magnitude, lock_data.lock_arrangement)
			if arrangement != null:
				RenderingServer.canvas_item_set_modulate(locks, Rendering.lock_colors[sign])
				
				RenderingServer.canvas_item_set_transform(locks, Transform2D(0, (lock_data.size - (lock_data.minimum_size)) / 2))
				
				for lock_position in arrangement[1]:
					var frame: int = lock_position[1] + (16 if value_type == Enums.Value.Imaginary else 0)
					var pos: Vector2i = lock_position[0] + Vector2i(-4, -4) # -6 for the centered, +2 for the frame
					var tex_offset = Vector2(frame, 0) if frame < 16 else Vector2(frame-16, 1)
					RenderingServer.canvas_item_add_texture_rect_region(locks, Rect2(pos, LOCKS_SIZE), LOCKS_TEXTURE, Rect2(tex_offset * LOCKS_SIZE, LOCKS_SIZE))
			else:
				
				RenderingServer.canvas_item_set_modulate(locks, Rendering.lock_colors[sign])
				var s := str(magnitude)
				var type := 2 if lock_data.dont_show_lock else 0 if value_type == Enums.Value.Real else 1 if value_type == Enums.Value.Imaginary else 2
				LockCountDraw.draw_text(locks, s, type)
				
				var si := LockCountDraw.get_min_size(s, type)
				RenderingServer.canvas_item_set_transform(locks, Transform2D(0, (lock_data.size - (si)) / 2))
				
	assert(PerfManager.end(&"Lock::draw_locks"))

var locks: RID
const LOCKS_TEXTURE := preload("res://level_elements/doors_locks/textures/locks.png")
const LOCKS_SIZE := Vector2(12, 12)

var base: RID
var glitch_rid: RID
const BASE_STONE := preload("res://level_elements/doors_locks/textures/stone_texture.png")
const BASE_MASTER := preload("res://level_elements/doors_locks/textures/gold_gradient.png")
const BASE_PURE := preload("res://level_elements/doors_locks/textures/pure_gradient.png")
const GLITCH_MASTER := preload("res://level_elements/doors_locks/textures/gold_glitch.png")
const GLITCH_PURE := preload("res://level_elements/doors_locks/textures/pure_glitch.png")
const BASE_ANIM_TILE_SIZE := Vector2(1, 64)
const GLITCH_MATERIAL := preload("res://rendering/glitch.material")
const GLITCH_BASE := preload("res://level_elements/doors_locks/textures/glitch_lock_1.png")
const GLITCH_BASE_SHARED := preload("res://level_elements/doors_locks/textures/glitch_lock_2.png")
const GLITCH_2_RECT := Rect2(0, 0, 45, 44)
const GLITCH_2_DIST := Vector2(3, 3)

const FRAME_POS := preload("res://level_elements/doors_locks/textures/lock_frame_texture_pos.png")
const FRAME_NEG := preload("res://level_elements/doors_locks/textures/lock_frame_texture_neg.png")
const FRAME_RECT := Rect2(0, 0, 5, 5)
const FRAME_COORD := Vector2(2, 2)

func _create_canvas_items() -> void:
	base = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(base, get_canvas_item())
	glitch_rid = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(glitch_rid, get_canvas_item())
	locks = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(locks, get_canvas_item())
	RenderingServer.canvas_item_set_material(glitch_rid, GLITCH_MATERIAL.get_rid())
	await ready

func _destroy_canvas_items() -> void:
	RenderingServer.free_rid(locks)
	RenderingServer.free_rid(base)
	RenderingServer.free_rid(glitch_rid)
