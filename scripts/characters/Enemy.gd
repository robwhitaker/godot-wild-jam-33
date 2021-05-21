extends KinematicBody2D

export var movement_speed := 60.0
export var show_debug_info := false

onready var path_refresh_timer := $PathRefreshTimer as Timer
onready var attack_radius := $AttackRadius as Area2D
onready var _debug_path_line := $Debug/PathLine as Line2D

var path := [] as PoolVector2Array
var velocity := Vector2.ZERO
var last_normal := Vector2.ZERO
var current_dir := Vector2.ZERO

var _debug := false
var _debug_move_direction := Vector2.ZERO

### Lifecycle functions ###

func _ready() -> void:
    # Enable / disable debug info
    _debug = OS.is_debug_build() && show_debug_info

    # Wait until the Scene singleton is ready so we can access the player and
    # the nav mesh
    if !Scene.is_ready:
        yield(Scene, "is_ready")

    # Rig up signal connections
    var _e # Placeholder used to quietly throw away connect results
    _e = path_refresh_timer.connect("timeout", self, "_update_path")
    _e = attack_radius.connect("body_entered", self, "_on_player_entered")
    _e = attack_radius.connect("body_exited", self, "_on_player_exited")

    # Generate an initial path to the player
    _update_path()


func _physics_process(delta : float) -> void:
    if path.size() == 0: return

    # Try to move towards the next point in the path
    var target := path[0]
    var new_dir := get_global_position().direction_to(target)
    velocity = (velocity + new_dir * movement_speed).clamped(movement_speed)
    var collision := move_and_collide(velocity * delta)

    if collision:
        # If we collided with something, if we've already picked a direction to try
        # to get around the object, stick with it. Otherwise, pick a direction.
        if current_dir == Vector2.ZERO || collision.normal != last_normal:
            last_normal = collision.normal

            var dir1 := global_position.slide(collision.normal)
            var dir2 := global_position.slide(collision.normal).tangent().tangent()

            if dir1.normalized().distance_to(new_dir) < dir2.normalized().distance_to(new_dir):
                new_dir = dir1
            else:
                new_dir = dir2

            current_dir = new_dir
        else:
            new_dir = current_dir

    # Apply our new direction to the velocity
    velocity += new_dir * movement_speed

    # If we've gotten close to our target point, remove it from the path
    # TODO: this is a magic number and hard to visualize. Maybe check within
    #       an Area2D or something?
    if get_global_position().distance_to(target) <= 10:
        path.remove(0)

    # Update debug lines
    if _debug:
        _debug_move_direction = new_dir
        update()
        _debug_path_line.set_points(path)
        _debug_path_line.set_global_position(Vector2.ZERO)

### Helper functions ###

func _update_path() -> void:
    path = Scene.navigation.get_simple_path(
        get_global_position(),
        Scene.player.get_global_position()
    )
    if _debug:
        _debug_path_line.set_points(path)

### Signal handling ###

func _on_player_entered(_body):
    set_physics_process(false)

func _on_player_exited(_body):
    set_physics_process(true)

### Debug ###

func _draw() -> void:
    if _debug:
        # Draw a line in the direction the AI is trying to move
        draw_line(Vector2.ZERO, _debug_move_direction.normalized() * 50, Color.yellow, 1.1)
