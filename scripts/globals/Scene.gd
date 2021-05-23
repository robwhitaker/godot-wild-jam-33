extends Node

signal player_set(player)
signal navigation_set(navigation)

signal is_ready

var player : KinematicBody2D = null setget set_player
var navigation : Navigation2D = null setget set_navigation
var signals = preload("res://scripts/globals/Signals.gd").new()

var is_ready := false

func set_player(new_player : KinematicBody2D) -> void:
    player = new_player
    emit_signal("player_set", player)
    _check_ready()

func set_navigation(new_nav : Navigation2D) -> void:
    navigation = new_nav
    emit_signal("navigation_set", navigation)
    _check_ready()

func _check_ready():
    if player && navigation && !is_ready:
        is_ready = true
        emit_signal("is_ready")
