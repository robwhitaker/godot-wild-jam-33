extends Area2D

export(String, FILE, "*.tscn") var next_scene_path
export(float) var next_scene_position_x
export(float) var next_scene_position_y
export(String, "left", "right", "up", "down") var next_scene_direction

func _ready():
# warning-ignore:return_value_discarded
    connect("body_entered", self, "_on_Transporter_body_entered")

func _on_Transporter_body_entered(body):
    if body.name == "Player":
        var next_scene_position = Vector2(next_scene_position_x, next_scene_position_y)
        SceneChanger.change_scene(body, next_scene_position, next_scene_direction, next_scene_path)
