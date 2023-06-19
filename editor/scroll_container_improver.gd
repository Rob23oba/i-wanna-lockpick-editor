extends Container
@onready var child: ScrollContainer = get_child(0)

func _ready() -> void:
	assert(child is ScrollContainer and is_instance_valid(child) and get_child_count() == 1)
	_sort_children()

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_children()

func _get_minimum_size() -> Vector2:
	if not is_node_ready(): return Vector2.ZERO
	return Vector2(0, child.get_minimum_size().y)

func _sort_children() -> void:
	# Holy crap this caused problems...
	if child.size == size: return
	if child.get_minimum_size().x >= size.x:
		child.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	else:
		child.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size = size
