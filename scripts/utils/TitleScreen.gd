extends MarginContainer

func _unhandled_input(event):
    if event is InputEventKey && event.scancode==KEY_SPACE:
        var next_scene_position = Vector2(20, 90)
        var next_scene_direction = "right"
        var next_scene_path = "res://scenes/rooms/Start.tscn"
        SceneChanger.change_scene(next_scene_position, next_scene_direction, next_scene_path)
