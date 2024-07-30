class_name NewLevelElementInfo
extends RefCounted
## basically a "struct" used only to pass around the data required to add a new element to a level

signal changed_position

var type: Enums.LevelElementTypes = -1
# will be preferred over the data's position
var position: Vector2i:
	set(val):
		position = val
		changed_position.emit()
# data, if any (one of the Data classes)
var data

@warning_ignore("shadowed_variable")
static func new_from_data(data) -> NewLevelElementInfo:
	var e = NewLevelElementInfo.new()
	e.type = data.level_element_type
	e.data = data
	e.position = data.position
	return e

func get_rect() -> Rect2i:
	match type:
		Enums.LevelElementTypes.Tile, Enums.LevelElementTypes.Goal, Enums.LevelElementTypes.PlayerSpawn:
			return Rect2i(position, Vector2i(32, 32))
		_:
			data.position = position
			return data.get_rect()
