
static func save(level: LevelData, file: FileAccess) -> void:
	file.store_16(level.num_version)
	file.store_pascal_string(level.editor_version)
	file.store_pascal_string(level.name)
	file.store_pascal_string(level.author)
	file.store_32(level.size.x)
	file.store_32(level.size.y)
	file.store_var(level.custom_lock_arrangements)
	file.store_32(level.goal_position.x)
	file.store_32(level.goal_position.y)
	file.store_32(level.player_spawn_position.x)
	file.store_32(level.player_spawn_position.y)
	# Tiles
	# Make sure there aren't *checks notes* 2^32 - 1, or, 4294967295 tiles. Meaning the level size is constrained to about, uh, 2097120x2097120
	file.store_32(level.tiles.size())
	for key in level.tiles:
		file.store_32(key.x)
		file.store_32(key.y)
	# Keys
	file.store_32(level.keys.size())
	for key in level.keys:
		_save_key(file, key)
	# Doors
	file.store_32(level.doors.size())
	for door in level.doors:
		_save_door(file, door)

static func _save_key(file: FileAccess, key: KeyData) -> void:
	_save_complex(file, key.amount)
	file.store_32(key.position.x)
	file.store_32(key.position.y)
	# color is 4 bytes, type is 3. 7 bytes total
	# bits are: 01112222, 1 = type, 2 = color
	file.store_8((key.type << 4) + key.color)

static func _save_door(file: FileAccess, door: DoorData) -> void:
	# In the current version:
	# Glitch color should always start as glitch
	# Doors can never start browned
	_save_complex(file, door.amount)
	file.store_32(door.position.x)
	file.store_32(door.position.y)
	file.store_32(door.size.x)
	file.store_32(door.size.y)
	# Curses take 3 bits. color takes 4 bits. 7 bits total
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	var curses := 0
	curses += 4 if door.get_curse(Enums.curse.ice) else 0
	curses += 2 if door.get_curse(Enums.curse.erosion) else 0
	curses += 1 if door.get_curse(Enums.curse.paint) else 0
	file.store_8((curses << 4) + door.outer_color)
	file.store_16(door.locks.size())
	for lock in door.locks:
		_save_lock(file, lock)

static func _save_lock(file: FileAccess, lock:LockData) -> void:
	file.store_32(lock.position.x)
	file.store_32(lock.position.y)
	file.store_32(lock.size.x)
	file.store_32(lock.size.y)
	file.store_16(lock.lock_arrangement)
	file.store_64(lock.magnitude)
	# Sign takes 1 bit, value type takes 1, dont_show_lock takes 1. color takes 4. lock type is 2. 9 bits total :(
	# bits are, 0000000112222345, 1 = lock type, 2 = color, 3 = dont show lock, 4 = value type, 5 = sign
	var bit_data := 0
	bit_data += lock.sign << 0
	bit_data += lock.value_type << 1
	bit_data += lock.dont_show_lock as int << 2
	bit_data += lock.color << 3
	bit_data += lock.lock_type << 7
	file.store_16(bit_data)

static func _save_complex(file: FileAccess, n: ComplexNumber) -> void:
	file.store_64(n.real_part)
	file.store_64(n.imaginary_part)

static func load(file: FileAccess) -> LevelData:
	assert(PerfManager.start("SaveLoadV1::load"))
	var level := LevelData.new()
	level.name = file.get_pascal_string()
	level.author = file.get_pascal_string()
	level.size = Vector2i(file.get_32(), file.get_32())
	level.custom_lock_arrangements = file.get_var()
	level.goal_position = Vector2i(file.get_32(), file.get_32())
	level.player_spawn_position = Vector2i(file.get_32(), file.get_32())
	if SaveLoad.PRINT_LOAD: print("loaded player pos: %s" % str(level.player_spawn_position))
	
	var tile_amount := file.get_32()
	if SaveLoad.PRINT_LOAD: print("tile count is %d" % tile_amount)
	for _i in tile_amount:
		level.tiles[Vector2i(file.get_32(), file.get_32())] = true
	
	var key_amount := file.get_32()
	if SaveLoad.PRINT_LOAD: print("key count is %d" % key_amount)
	level.keys.resize(key_amount)
	for i in key_amount:
		level.keys[i] = _load_key(file)
	
	var door_amount := file.get_32()
	if SaveLoad.PRINT_LOAD: print("door count is %d" % door_amount)
	level.doors.resize(door_amount)
	assert(PerfManager.start("SaveLoadV1::load (loading doors)"))
	for i in door_amount:
		level.doors[i] = _load_door(file)
	assert(PerfManager.end("SaveLoadV1::load (loading doors)"))
	
	assert(PerfManager.end("SaveLoadV1::load"))
	return level

static func _load_key(file: FileAccess) -> KeyData:
	var key := KeyData.new()
	key.amount = _load_complex(file)
	key.position = Vector2i(file.get_32(), file.get_32())
	var type_and_color := file.get_8()
	key.color = type_and_color & 0b1111
	key.type = type_and_color >> 4
	
	return key

static func _load_door(file: FileAccess) -> DoorData:
	var door := DoorData.new()
	
	door.amount = _load_complex(file)
	door.position = Vector2i(file.get_32(), file.get_32())
	door.size = Vector2i(file.get_32(), file.get_32())
	
	var curses_color := file.get_8()
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	door.set_curse(Enums.curse.ice, curses_color & (1<<6) != 0)
	door.set_curse(Enums.curse.erosion, curses_color & (1<<5) != 0)
	door.set_curse(Enums.curse.paint, curses_color & (1<<4) != 0)
	door.outer_color = curses_color & 0b1111
	
	var lock_amount := file.get_16()
	door.locks.resize(lock_amount)
	for i in lock_amount:
		door.locks[i] = _load_lock(file)
	
	return door

static func _load_lock(file: FileAccess) -> LockData:
	var lock := LockData.new()
	lock.position = Vector2i(file.get_32(), file.get_32())
	lock.size = Vector2i(file.get_32(), file.get_32())
	lock.lock_arrangement = file.get_16()
	lock.magnitude = file.get_64()
	var bit_data := file.get_16()
	lock.sign = bit_data & 0b1
	bit_data >>= 1
	lock.value_type = bit_data & 0b1
	bit_data >>= 1
	lock.dont_show_lock = bit_data & 0b1
	bit_data >>= 1
	lock.color = bit_data & 0b1111
	bit_data >>= 4
	lock.lock_type = bit_data
	
	return lock

static func _load_complex(file: FileAccess) -> ComplexNumber:
	return ComplexNumber.new_with(file.get_64(), file.get_64())

