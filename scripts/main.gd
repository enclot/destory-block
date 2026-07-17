extends Node2D



func _get_all_blocks() -> Array[DistructibleBlock]:
	var nodes = get_tree().get_nodes_in_group(&"block")
	var blocks:Array[DistructibleBlock] = []
	for node in nodes:
		blocks.append(node as DistructibleBlock)
	return blocks

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var blocks = _get_all_blocks()
			if blocks:
				for block in blocks:
					if block.is_point_inside(get_global_mouse_position()):
						block.take_damage()
