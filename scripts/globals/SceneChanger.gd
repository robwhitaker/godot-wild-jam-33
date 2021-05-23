extends CanvasLayer

signal scene_changed()

onready var animationPlayer = $AnimationPlayer
onready var black =  $Control/Black

var next_scene_position = Vector2.ZERO
var next_scene_direction = ""

func change_scene(position : Vector2, direction : String, scene_path : String, delay : float = 0) -> void:
    next_scene_position = position
    next_scene_direction = direction

    yield(get_tree().create_timer(delay), "timeout")
    animationPlayer.play("fade")
    yield(animationPlayer, "animation_finished")
    assert(get_tree().change_scene(scene_path) == OK)
    animationPlayer.play_backwards("fade")
    yield(animationPlayer, "animation_finished")
    emit_signal("scene_changed")

    animationPlayer.play_backwards("fade")
    yield(animationPlayer, "animation_finished")
    emit_signal("scene_changed")
