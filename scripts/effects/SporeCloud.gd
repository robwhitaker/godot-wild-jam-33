extends Node2D

export var damage_per_tick := 5.0
export var ticks_per_second := 4.0
export var cloud_duration := 10.0

onready var tick_timer := $TickTimer as Timer
onready var cloud_duration_timer := $CloudDuration as Timer
onready var aoe_area := $AoE as Area2D
onready var animation := $AnimationPlayer as AnimationPlayer

var player_in_radius := false
var enabled := true

func _ready():
    tick_timer.set_wait_time(1 / ticks_per_second)
    cloud_duration_timer.set_wait_time(cloud_duration)
    cloud_duration_timer.start()

    var _e # for ignoring warnings
    _e = aoe_area.connect("area_entered", self, "_on_AoE_entered")
    _e = aoe_area.connect("area_exited", self, "_on_AoE_exited")
    _e = tick_timer.connect("timeout", self, "_on_tick_timer_timeout")
    _e = cloud_duration_timer.connect("timeout", self, "_on_cloud_duration_timer_timeout")

func _on_AoE_entered(body):
    if body.name == "Hurtbox":
        Scene.player.apply_damage(damage_per_tick)
        player_in_radius = true
        tick_timer.start()

func _on_AoE_exited(body):
    if body.name == "Hurtbox":
        player_in_radius = false
        tick_timer.stop()

func _on_tick_timer_timeout():
    if enabled:
        Scene.player.apply_damage(damage_per_tick)
        print(Player.health)

func _on_cloud_duration_timer_timeout():
    enabled = false
    animation.play("fade_out")
