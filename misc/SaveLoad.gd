class_name SaveLoad

const PRINT_LOAD := false
const LATEST_FORMAT := 4
const V1 := preload("res://misc/saving_versions/save_load_v1.gd")
const V2 := preload("res://misc/saving_versions/save_load_v2.gd")
const V3 := preload("res://misc/saving_versions/save_load_v3.gd")
const V4 := preload("res://misc/saving_versions/save_load_v4.gd")
const VERSIONS: Dictionary = {
	1: V1,
	2: V2,
	3: V3,
	4: V4
}
## A reference to the current save/load version
const VC := V4
const LEVEL_EXTENSIONS := ["res", "tres", "lvl", "png"]
static var LEVELS_PATH := ProjectSettings.globalize_path("user://levels/")
static var SAVES_PATH := ProjectSettings.globalize_path("user://level_saves/")

## Given a LevelPack, gets the byte data to save it as the current format version.
static func get_data(level_pack: LevelPackData) -> PackedByteArray:
	var header := make_header(LATEST_FORMAT, Global.game_version)
	var byte_access := VC.make_byte_access(header, header.size())
	VC.save(level_pack, byte_access)
	return byte_access.data

## Given a LevelPack, gets the Image to save it as the current format version.
static func get_image(level_pack: LevelPackData) -> Image:
	var data := get_data(level_pack)
	var img := Image.new()
	
	# full color. alternatively, call image_to_b_w here (for some visual variety)
	var pixel_count := (data.size() + 2) / 3
	var image_size := (ceili(sqrt(pixel_count as float)))
	
	data.resize(image_size * image_size * 3)
	img.set_data(image_size, image_size, false, Image.FORMAT_RGB8, data)
	return img

static func is_path_valid(path: String) -> bool:
	if path == "": return false
	var globalized_path := ProjectSettings.globalize_path(path)
	return Global.danger_override or globalized_path.begins_with(LEVELS_PATH)

## Saves a LevelPackData to its file_path
static func save_level(level_pack: LevelPackData) -> void:
	var path := level_pack.file_path
	assert(is_path_valid(path))
	
	if path.get_extension() == "lvl":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(get_data(level_pack))
		print("saving to " + path)
		file.close()
	elif path.get_extension() == "png":
		var image := get_image(level_pack)
		print("saving to " + path)
		var err := image.save_png(path)
		if err != OK:
			print("error saving image: " + str(err))
	else:
		assert(false)
	level_pack.state_data.save()

static func load_pack_state_from_path(path: String) -> LevelPackStateData:
	var data := FileAccess.get_file_as_bytes(path)
	if FileAccess.get_open_error() == OK:
		return load_pack_state_from_buffer(data)
	else:
		return null

static func load_pack_state_from_buffer(data: PackedByteArray) -> LevelPackStateData:
	# All versions must respect this initial structure
	var version := data.decode_u16(0)
	var len := data.decode_u32(2)
	var bytes := data.slice(6, 6 + len)
	var original_editor_version := bytes.get_string_from_utf8()
	
	if not VERSIONS.has(version):
		printerr("Invalid level pack state version: %d (%s)" % [version, original_editor_version])
		return null
	if version <= 3:
		printerr("Version doesn't support pack states: %d (%s)" % [version, original_editor_version])
		return null
	var load_script: Script = VERSIONS[version]
	var byte_access = load_script.make_byte_access(data, 6 + len)
	var state_data: LevelPackStateData = load_script.load_pack_state(byte_access)
	return state_data

static func get_pack_state_data(state: LevelPackStateData) -> PackedByteArray:
	var byte_access = VC.make_byte_access([])
	VC.save_pack_state(byte_access, state)
	return byte_access.data

static func save_pack_state_to_path(state: LevelPackStateData, path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(get_pack_state_data(state))
	file.close()

## Loads a LevelPackData from a file path.
static func load_from_path(path: String) -> LevelPackData:
	if path.get_extension() == "png":
		return load_from_image(Image.load_from_file(path), path)
	elif path.get_extension() == "lvl":
		return load_from_buffer(FileAccess.get_file_as_bytes(path), path)
	else:
		assert(false)
		return null

## Loads a LevelPackData from the binary contents of a file.
## (which could require changes as png files can't be directly read as level data)
static func load_from_file_buffer(buffer: PackedByteArray, path: String) -> LevelPackData:
	# Check png header
	if buffer.slice(0, 8).get_string_from_ascii() == "\u0089PNG\r\n\u001a\n":
		# Get the correct buffer from png file
		var img := Image.new()
		var error := img.load_png_from_buffer(buffer)
		if error == OK:
			return load_from_image(img)
	return load_from_buffer(buffer, path)

## Loads a LevelPackData from an Image
static func load_from_image(image: Image, path := "") -> LevelPackData:
	image.convert(Image.FORMAT_RGB8)
	var data := image.get_data()
	return load_from_buffer(data, path)

## Used for testing
static func get_version_from_path(path: String) -> int:
	if path.get_extension() == "lvl":
		return FileAccess.get_file_as_bytes(path).decode_u16(0)
	elif path.get_extension() == "png":
		var image := Image.load_from_file(path)
		image.convert(Image.FORMAT_RGB8)
		var data := image.get_data()
		return data.decode_u16(0)
	else:
		assert(false)
		return -1

## Loads a LevelPackData from a valid save buffer.
static func load_from_buffer(data: PackedByteArray, path: String) -> LevelPackData:
	# All versions must respect this initial structure
	var header_data := get_header(data)
	
	var version: int = header_data.version
	var original_editor_version: String = header_data.editor_version
	var offset: int = header_data.offset
	
	
	print("Loading from %s. format version is %d. editor version was %s" % [path, version, original_editor_version])
	
	if not VERSIONS.has(version):
		var error_text := \
	"""This level was made in editor version %s and uses the saving format N°%d.
	You're on version %s, which supports up to the saving format N°%d.
	Consider updating the editor to a newer version.
	Loading cancelled.""" % [original_editor_version, version, Global.game_version, LATEST_FORMAT]
		Global.safe_error(error_text, Vector2i(700, 100))
		return null
	
	var original_version := version
	var load_script: Script = VERSIONS[version]
	
	while not load_script.has_method("load"):
		var new_version: int = load_script.conversion_version
		print("Nevermind, first converting to V%d..." % new_version)
		assert(PerfManager.start("SaveLoad -> V%d::convert_to_newer_version" % version))
		var new_data: PackedByteArray = load_script.convert_to_newer_version(data, offset)
		assert(PerfManager.end("SaveLoad -> V%d::convert_to_newer_version" % version))
		version = new_version
		load_script = VERSIONS[version]
		data = new_data
		offset = 0
	
	assert(PerfManager.start("SaveLoad -> V%d::load" % version))
	var lvl_pack_data: LevelPackData = load_script.load(data, offset)
	assert(PerfManager.end("SaveLoad -> V%d::load" % version))
	# V3 and earlier didn't support pack id. Calculate a consistent one to allow save data.
	if not lvl_pack_data:
		return lvl_pack_data
	if original_version <= 3:
		var hc := HashingContext.new()
		hc.start(HashingContext.HASH_SHA1)
		hc.update(data)
		# "& ~(1<<63)" ensures it's not negative
		var h := hc.finish().decode_s64(0) & ~(1<<63)
		lvl_pack_data.pack_id = h
	
	lvl_pack_data.file_path = path
	return lvl_pack_data

## Returns {version: int, editor_version: String, offset: int}
static func get_header(data: PackedByteArray) -> Dictionary:
	var version := data.decode_u16(0)
	var len := data.decode_u32(2)
	var bytes := data.slice(6, 6 + len)
	var original_editor_version := bytes.get_string_from_utf8()
	if original_editor_version == "":
		original_editor_version = "Unknown (oops)"
	var offset := 6+len
	
	return {
		version = version,
		editor_version = original_editor_version,
		offset = offset,
	}

static func make_header(version: int, editor_version: String) -> PackedByteArray:
	var arr := PackedByteArray()
	arr.resize(6)
	arr.encode_u16(0, version)
	# String is handled similar to FileAccess.store_pascal_string
	var bytes := editor_version.to_utf8_buffer()
	arr.encode_u32(2, bytes.size())
	arr.append_array(bytes)
	
	return arr

# fun
static func image_to_b_w(img: Image, data: PackedByteArray) -> void:
	var pixel_count := data.size() * 8
	var image_size := (ceili(sqrt(pixel_count as float)))
	var width := (image_size / 8) * 8
	var height := (pixel_count + width - 1) / width
	height *= 2
	width += width / 8 + 1
	var img_data: PackedByteArray = []
	img_data.resize(width * height * 3)
	var i := 0
	for byte in data:
		if (i / 3) % width == 0:
			for x in width:
				img_data[i + 0] = 128
				img_data[i + 1] = 128
				img_data[i + 2] = 128
				i += 3
		img_data[i + 0] = 128
		img_data[i + 1] = 128
		img_data[i + 2] = 128
		i += 3
		for j in 8:
			if byte & 1 == 1:
				img_data[i + 0] = 255
				img_data[i + 1] = 255
				img_data[i + 2] = 255
			byte >>= 1
			i += 3
		if (i / 3) % width == width - 1:
			img_data[i + 0] = 128
			img_data[i + 1] = 128
			img_data[i + 2] = 128
			i += 3
		
	img.set_data(width, height, false, Image.FORMAT_RGB8, img_data)
