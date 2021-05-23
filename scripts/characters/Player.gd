extends KinematicBody2D

signal moved(global_position)
signal noise_level_changed(noise_level)

const ACCELERATION = 500
const FRICTION = 500

const DRAG_MAX_SPEED = 20
const WALK_MAX_SPEED = 45
const SPRINT_MAX_SPEED = 90

const DRAG_DETECTION_MULT = 0.5
const WALK_DETECTION_MULT = 1
const SPRINT_DETECTION_MULT = 2.2
const LIGHT_DETECTION_MULT = 1.2

enum {
    DRAG,
    WALK,
    SPRINT
}

enum {
    MOVE,
    ATTACK
}

enum NOISE_LEVEL {
    NONE,
    LOW,
    MEDIUM,
    HIGH,
    EXTREME
}

var state = MOVE
var move_state = WALK
var noise_level = NOISE_LEVEL.NONE
var velocity = Vector2.ZERO

onready var animationPlayer = $AnimationPlayer
onready var animationTree = $AnimationTree
onready var animationState = animationTree.get("parameters/playback")
onready var detection_radius_shape := $DetectionRadius/CollisionShape2D as CollisionShape2D
onready var detection_radius_scale := detection_radius_shape.get_scale()
onready var lantern_light := $LanternLight as Light2D
onready var default_light := $DefaultLight as Light2D

# Node we currently have selected for interaction
var selected_interaction = null

func _ready():
    Scene.set_player(self)
    animationTree.active = true
    _handle_transportation()
    _set_up_camera()

func _physics_process(delta):
    match state:
        MOVE:
            move_state(delta)
        ATTACK:
            attack_state()

func apply_damage(damage : float) -> void:
    var health = Player.health
    var remaining_health = health - damage
    if remaining_health <= 0:
        Player.health = 0
        _die()
    else:
        Player.health = remaining_health

func _die() -> void:
    self.set_physics_process(false)
    _display_you_died_text()
    yield(get_tree().create_timer(3.0), "timeout")
    var title_screen_path = "res://scenes/rooms/TitleScreen.tscn"
    SceneChanger.change_scene(Vector2.ZERO, "", title_screen_path)
    Player.health = 100

func move_state(delta):
    var last_pos = get_global_position()

    var input_vector = Vector2.ZERO
    input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
    input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
    input_vector = input_vector.normalized()

    if Input.is_action_pressed("sprint"):
        move_state = SPRINT
        detection_radius_shape.set_scale(detection_radius_scale * SPRINT_DETECTION_MULT)
    elif Input.is_action_pressed("drag"):
        move_state = DRAG
        detection_radius_shape.set_scale(detection_radius_scale * DRAG_DETECTION_MULT)
    else:
        move_state = WALK
        detection_radius_shape.set_scale(detection_radius_scale * WALK_DETECTION_MULT)

    if input_vector != Vector2.ZERO:
        animationTree.set("parameters/Idle/blend_position", input_vector)
        animationTree.set("parameters/Run/blend_position", input_vector)
        animationTree.set("parameters/Attack/blend_position", input_vector)
        # TODO: different animation for different move states
        animationState.travel("Run")
        var max_speed := 0
        match move_state:
            DRAG:
                max_speed = DRAG_MAX_SPEED
            WALK:
                max_speed = WALK_MAX_SPEED
            SPRINT:
                max_speed = SPRINT_MAX_SPEED
        velocity = velocity.move_toward(input_vector * max_speed, ACCELERATION * delta)
    else:
        animationState.travel("Idle")
        velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
        if lantern_light.is_visible():
            detection_radius_shape.set_scale(detection_radius_scale * LIGHT_DETECTION_MULT)
        else:
            detection_radius_shape.set_scale(detection_radius_scale * DRAG_DETECTION_MULT)

    velocity = move_and_slide(velocity)

    if Input.is_action_just_pressed("attack"):
        velocity = Vector2.ZERO
        state = ATTACK

    if lantern_light.is_visible():
        if move_state != DRAG && input_vector != Vector2.ZERO:
            detection_radius_shape.set_scale(detection_radius_shape.get_scale() * LIGHT_DETECTION_MULT)
        else:
            detection_radius_shape.set_scale(detection_radius_scale * LIGHT_DETECTION_MULT)


    var new_pos = get_global_position()
    if last_pos != new_pos:
        emit_signal("moved", new_pos)

    var new_noise_level = noise_level
    if lantern_light.is_visible():
        if move_state == SPRINT:
            new_noise_level = NOISE_LEVEL.EXTREME
        else:
            new_noise_level = NOISE_LEVEL.MEDIUM
    else:
        if input_vector == Vector2.ZERO || move_state == DRAG:
            new_noise_level = NOISE_LEVEL.NONE
        elif move_state == WALK:
            new_noise_level = NOISE_LEVEL.LOW
        elif move_state == SPRINT:
            new_noise_level = NOISE_LEVEL.HIGH

    if noise_level != new_noise_level:
        emit_signal("noise_level_changed", new_noise_level)
        noise_level = new_noise_level



func attack_state():
    animationState.travel("Attack")

func attack_animation_finish():
    state = MOVE

func _on_InteractionRadius_area_entered(body) -> void:
    if body.has_method("select"):
        if selected_interaction != null && selected_interaction.has_method("unselect"):
            selected_interaction.unselect()
        selected_interaction = body
        body.select()

func _on_InteractionRadius_area_exited(body) -> void:
    if body == selected_interaction && selected_interaction.has_method("unselect"):
        selected_interaction.unselect()
        selected_interaction = null

func _unhandled_input(event):
    if ( selected_interaction != null
      && selected_interaction.has_method("interact")
      && event.is_action_pressed("interact")):
        selected_interaction.interact()
    elif event.is_action_pressed("lantern"):
        if lantern_light.is_visible():
            lantern_light.hide()
            default_light.show()
        else:
            lantern_light.show()
            default_light.hide()

func _handle_transportation() -> void:
    if SceneChanger.next_scene_position:
        set_global_position(SceneChanger.next_scene_position)
    if SceneChanger.next_scene_direction:
        var input_vector = Vector2.ZERO
        match SceneChanger.next_scene_direction:
            "left": input_vector = Vector2.LEFT
            "right": input_vector = Vector2.RIGHT
            "up": input_vector = Vector2.UP
            "down": input_vector = Vector2.DOWN
        animationTree.set("parameters/Idle/blend_position", input_vector)

func _set_up_camera() -> void:
    var scene_dimensions = get_tree().current_scene.get_node("Background").get_rect().size
    var camera = get_node("Camera2D")
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = scene_dimensions.x
    camera.limit_bottom = scene_dimensions.y

func _display_you_died_text() -> void:
    var you_died_text = RichTextLabel.new()
    you_died_text.bbcode_enabled = true
    you_died_text.set_name("YouDiedText")
    you_died_text.set_bbcode("[center]You died... F[/center]")
    you_died_text.set_size(Vector2(100, 30))
    you_died_text.set_global_position(self.global_position)

    get_tree().current_scene.add_child(you_died_text)
