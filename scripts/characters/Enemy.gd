extends KinematicBody2D

export var chase_movement_speed := 60.0
export var search_movement_speed := 40.0
export var search_start_delay := 3.0
export var search_duration := 10.0
export var attack_cooldown := 2.0
export var show_debug_info := false

onready var path_refresh_timer := $PathRefreshTimer as Timer
onready var search_start_delay_timer := $SearchStartDelay as Timer
onready var search_timer := $SearchTimer as Timer
onready var attack_cooldown_timer := $AttackCooldown as Timer
onready var attack_radius := $AttackRadius as Area2D
onready var aggro_radius := $AggroRadius as Area2D
onready var wake_up_radius := $WakeUpRadius as Area2D
onready var animation_tree := $AnimationTree as AnimationTree
onready var animation_state = animation_tree.get("parameters/playback")
onready var aggro_light := $AggroLight as Light2D

onready var _debug_path_line := $Debug/PathLine as Line2D

var path := [] as PoolVector2Array
var velocity := Vector2.ZERO
var last_normal := Vector2.ZERO
var current_dir := Vector2.ZERO

var state := SLEEPING
var attack_on_cooldown := false

var player_is_detected := false
var player_in_attack_range := false

var _debug := false
var _debug_move_direction := Vector2.ZERO

### States ###

enum {
    SLEEPING,
    CHASING,
    ATTACKING
}

### Lifecycle functions ###

func _ready() -> void:
    # Enable / disable debug info
    _debug = OS.is_debug_build() && show_debug_info

    # Don't run physics if we're not chasing
    set_physics_process(state == CHASING)

    # Set some defaults (which sometimes change in the editor)
    animation_tree.active = true
    aggro_light.set_energy(0)

    # Set up settings from exported vars
    search_start_delay_timer.set_wait_time(search_start_delay)
    search_timer.set_wait_time(search_duration)
    attack_cooldown_timer.set_wait_time(attack_cooldown)

    # Wait until the Scene singleton is ready so we can access the player and
    # the nav mesh
    if !Scene.is_ready:
        yield(Scene, "is_ready")

    # Rig up signal connections
    var _e # Placeholder used to quietly throw away connect results

    _e = path_refresh_timer.connect("timeout", self, "_update_path")
    _e = search_start_delay_timer.connect("timeout", self, "_start_searching")
    _e = search_timer.connect("timeout", self, "_give_up_on_search")
    _e = attack_cooldown_timer.connect("timeout", self, "_attack_off_cooldown")

    _e = attack_radius.connect("body_entered", self, "_on_player_entered_attack_range")
    _e = attack_radius.connect("body_exited", self, "_on_player_exited_attack_range")
    _e = aggro_radius.connect("area_entered", self, "_on_player_found")
    _e = aggro_radius.connect("area_exited", self, "_on_player_lost")
    _e = wake_up_radius.connect("area_entered", self, "_wake_up")

    _e = Scene.player.connect("noise_level_changed", self, "_on_player_noise_level_changed")

    # Generate an initial path to the player
    _update_path()


func _physics_process(delta : float) -> void:
    if path.size() == 0:
        animation_state.travel("Searching")
        return

    var movement_speed = chase_movement_speed
    if !player_is_detected:
        movement_speed = search_movement_speed

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

    # Make the enemy face the right way for its velocity
    if velocity != Vector2.ZERO:
        var blend_positions = [
            "parameters/Attack/blend_position",
            "parameters/Idle/blend_position",
            "parameters/IdleSleep/blend_position",
            "parameters/Jitter/blend_position",
            "parameters/Run/blend_position",
            "parameters/Sleep/blend_position",
            "parameters/Wake/blend_position",
        ]
        for blend_position in blend_positions:
            animation_tree.set(blend_position, velocity.normalized())
        animation_state.travel("Run")

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

func _process(_delta):
    if player_in_attack_range && !attack_on_cooldown && state == CHASING:
        _attack()

### Helper functions ###

func _update_path() -> void:
    # Don't path to the player if we're not chasing
    if state != CHASING:
        return

    # Generate a path to the player
    path = Scene.navigation.get_simple_path(
        get_global_position(),
        Scene.player.get_global_position()
    )

    if _debug:
        _debug_path_line.set_points(path)

func _attack():
    set_physics_process(false)
    attack_on_cooldown = true
    state = ATTACKING
    animation_state.travel("Attack")

func _spawn_spores():
    var spores = preload("res://scenes/objects/SporeCloud.tscn").instance()
    spores.set_global_position(global_position)
    get_parent().add_child(spores)

func _attack_finished():
    attack_cooldown_timer.start()
    state = CHASING
    set_physics_process(true)

func _start_chase():
    state = CHASING
    set_physics_process(true)
    _update_path()

### Signal handling ###

func _on_player_entered_attack_range(_body):
    player_in_attack_range = true

func _on_player_exited_attack_range(_body):
    player_in_attack_range = false
    attack_on_cooldown = false
    attack_cooldown_timer.stop()
    state = CHASING

func _on_player_found(_body):
    player_is_detected = true
    search_timer.stop()

func _on_player_lost(_body):
    search_start_delay_timer.start()

func _start_searching():
    player_is_detected = false
    search_timer.start()

func _give_up_on_search():
    state = SLEEPING
    set_physics_process(false)
    animation_state.travel("IdleSleep")

func _attack_off_cooldown():
    attack_on_cooldown = false

func _wake_up(_body):
    if state != SLEEPING:
        return

    animation_state.travel("Wake")

func _on_player_noise_level_changed(noise_level) -> void:
    var path_update_freq = path_refresh_timer.get_wait_time()
    match noise_level:
        Scene.player.NOISE_LEVEL.NONE:
            path_update_freq = 6
        Scene.player.NOISE_LEVEL.LOW:
            path_update_freq = 3
        Scene.player.NOISE_LEVEL.MEDIUM:
            path_update_freq = 0.5
        Scene.player.NOISE_LEVEL.HIGH:
            path_update_freq = 0.25
        Scene.player.NOISE_LEVEL.EXTREME:
            path_update_freq = 0.1
    path_refresh_timer.set_wait_time(path_update_freq)
    if path_refresh_timer.get_time_left() > path_update_freq:
        path_refresh_timer.start()

### Debug ###

func _draw() -> void:
    if _debug:
        # Draw a line in the direction the AI is trying to move
        draw_line(Vector2.ZERO, _debug_move_direction.normalized() * 50, Color.yellow, 1.1)
