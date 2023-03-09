@tool
extends Node

const RENDERED_PATH := "res://rendering/doors_locks/rendered_textures/"
const SPECIAL_ANIM_SPEED := 0.3

# these are basically const, but they have to be vars because of get_image()
var DOOR_FRAME := preload("res://rendering/doors_locks/door_frame.png").get_image()
var DOOR_COLOR := preload("res://rendering/doors_locks/door_color.png").get_image()
var LOCK_FRAME := preload("res://rendering/doors_locks/lock_frame.png").get_image()
# Order: main, clear, dark
var frame_colors := generate_colors({
	Enums.sign.positive: ["584027", "84603C", "2C2014"],
	Enums.sign.negative: ["D8BFA7", "EBDFD3", "C49F7B"],
})

var lock_colors := {
	Enums.sign.positive: Color("2C2014"),
	Enums.sign.negative: Color("EBDFD3"),
}

var color_colors := generate_colors({
#	Enums.color.none: [],
#	Enums.color.glitch: [],
	Enums.color.black: ["363029", "554B40", "181512"],
	Enums.color.white: ["D6CFC9", "EDEAE7", "BBAEA4"],
	Enums.color.pink: ["CF709F", "E4AFCA", "AF3A75"],
	Enums.color.orange: ["D68F49", "E7BF98", "9C6023"],
	Enums.color.purple: ["8F5FC0", "BFA4DB", "603689"],
	Enums.color.cyan: ["50AFAF", "8ACACA", "357575"],
	Enums.color.red: ["8F1B1B", "C83737", "480D0D"],
	Enums.color.green: ["359F50", "70CF88", "1B5028"],
	Enums.color.blue: ["5F71A0", "8795B8", "3A4665"],
	Enums.color.brown: ["704010", "AA6015", "382007"],
#	Enums.color.pure: [],
#	Enums.color.master: [],
#	Enums.color.stone: [],
})

var key_colors := generate_colors({
#	Enums.color.none: ,
#	Enums.color.glitch: ,
	Enums.color.black: "363029",
	Enums.color.white: "D6CFC9",
	Enums.color.pink: "CF709F",
	Enums.color.orange: "D68F49",
	Enums.color.purple: "8D5BBF",
	Enums.color.cyan: "50AFAF",
	Enums.color.red: "C83737",
	Enums.color.green: "359F50",
	Enums.color.blue: "5F71A0",
	Enums.color.brown: "704010",
#	Enums.color.pure: ,
#	Enums.color.master: ,
#	Enums.color.stone: ,
})
#var key_number_colors: Array[Color] = [Color("c9dbcc"), Color("363029")]
var key_number_colors: Array[Color] = [Color("EBE3DD"), Color("363029")]

func generate_colors(from: Dictionary) -> Dictionary:
	var dict := {}
	for key in from.keys():
		if from[key] is Array:
			dict[key] = from[key].map(
				func(s: String):
					return Color(s)
			)
		else:
			dict[key] = Color(from[key])
	return dict

var _door_frame_textures := {}
var _door_color_textures := {}
var _lock_frame_textures := {}

func _ready() -> void:
	load_rendered_textures()

func load_rendered_textures() -> void:
	for children in get_children():
		
		if children.name.begins_with("DoorColorTexture"):
			_door_color_textures[children.name.to_int()] = children.texture
		elif children.name.begins_with("DoorFrameTexture"):
			_door_frame_textures[children.name.to_int()] = children.texture
		elif children.name.begins_with("LockFrameTexture"):
			_lock_frame_textures[children.name.to_int()] = children.texture
#	var loaded_count := 0
#	for file_name in DirAccess.get_files_at(RENDERED_PATH):
#		var full_path := RENDERED_PATH.path_join(file_name)
#		if file_name.ends_with(".png.import"):
#			loaded_count += 1
#			if file_name.begins_with("door_color_texture_"):
#				_door_color_textures[file_name.to_int()] = load(full_path)
#				assert(_door_color_textures[file_name.to_int()] != null)
#			elif file_name.begins_with("door_frame_texture_"):
#				_door_frame_textures[file_name.to_int()] = load(full_path)
#				assert(_door_frame_textures[file_name.to_int()] != null)
#			elif file_name.begins_with("lock_frame_texture_"):
#				_lock_frame_textures[file_name.to_int()] = load(full_path)
#				assert(_lock_frame_textures[file_name.to_int()] != null)
#			else:
#				print(file_name)
#				breakpoint
#	print("loaded %d pre-rendered textures" % loaded_count)
	

func get_door_frame_texture(sign: Enums.sign) -> Texture2D:
	var tex: Texture2D = _door_frame_textures.get(sign)
	if tex == null:
		tex  = color_texture(DOOR_FRAME, frame_colors[sign])
		_door_frame_textures[sign] = tex
		tex.resource_path = RENDERED_PATH.path_join("door_frame_texture_" + str(sign) + ".png.import")
		ResourceSaver.save(tex)
		print("rendered " + tex.resource_path)
	return tex

func get_door_color_texture(color: Enums.color) -> Texture2D:
	var tex: Texture2D = _door_color_textures.get(color)
	if tex == null:
		tex = color_texture(DOOR_COLOR, color_colors[color])
		_door_color_textures[color] = tex
		tex.resource_path = RENDERED_PATH.path_join("door_color_texture_" + str(color) + ".png.import")
		ResourceSaver.save(tex)
		print("rendered " + tex.resource_path)
	return tex

func get_lock_frame_texture(sign: Enums.sign) -> Texture2D:
	var tex: Texture2D = _lock_frame_textures.get(sign)
	if tex == null:
		tex = color_texture(LOCK_FRAME, frame_colors[sign])
		_lock_frame_textures[sign] = tex
		tex.resource_path = RENDERED_PATH.path_join("lock_frame_texture_" + str(sign) + ".png.import")
		ResourceSaver.save(tex)
		print("rendered " + tex.resource_path)
	return tex

func color_texture(base: Image, palette: Array[Color]) -> Texture2D:
	assert(false, "color_texture is deprecated")
	return null
	var image := Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8)
	for y in base.get_height():
		for x in base.get_width():
			var pixel := base.get_pixel(x, y)
			if pixel.a == 0:
				image.set_pixel(x, y, pixel)
			else:
				image.set_pixel(x, y, palette[pixel.r8])
	return ImageTexture.create_from_image(image)