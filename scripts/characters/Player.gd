extends KinematicBody2D

signal moved(global_position)

const ACCELERATION = 500
const FRICTION = 500

const DRAG_MAX_SPEED = 30
const WALK_MAX_SPEED = 65
const SPRINT_MAX_SPEED = 120

const WALK_DETECTION_MULT = 3
const SPRINT_DETECTION_MULT = 8
const LIGHT_DETECTION_MULT = 12

enum {
    DRAG,
    WALK,
    SPRINT
}

enum {
    MOVE,
    ATTACK
}

var state = MOVE
var move_state = WALK
var velocity = Vector2.ZERO

onready var animationPlayer = $AnimationPlayer
onready var animationTree = $AnimationTree
onready var animationState = animationTree.get("parameters/playback")
onready var detection_radius_shape := $DetectionRadius/CollisionShape2D as CollisionShape2D
onready var lantern_light := $LanternLight as Light2D
onready var default_light := $DefaultLight as Light2D

# Node we currently have selected for interaction
var selected_interaction = null

func _ready():
    Scene.set_player(self)
    animationTree.active = true
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

    var scene_dimensions = get_tree().current_scene.get_node("Background").get_rect().size
    var camera = get_node("Camera2D")
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = scene_dimensions.x
    camera.limit_bottom = scene_dimensions.y

func _process(delta):
    match state:
        MOVE:
            move_state(delta)
        ATTACK:
            attack_state()

func apply_damage(dmg : float) -> void:
    pass

func move_state(delta):
    var last_pos = get_global_position()

    var input_vector = Vector2.ZERO
    input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
    input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
    input_vector = input_vector.normalized()

    if Input.is_action_pressed("sprint"):
        move_state = SPRINT
        detection_radius_shape.set_scale(Vector2(SPRINT_DETECTION_MULT, SPRINT_DETECTION_MULT))
    elif Input.is_action_pressed("drag"):
        move_state = DRAG
        detection_radius_shape.set_scale(Vector2(WALK_DETECTION_MULT, WALK_DETECTION_MULT))
    else:
        move_state = WALK
        detection_radius_shape.set_scale(Vector2(WALK_DETECTION_MULT, WALK_DETECTION_MULT))

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
        detection_radius_shape.set_scale(Vector2(1,1))

    velocity = move_and_slide(velocity)

    if Input.is_action_just_pressed("attack"):
        velocity = Vector2.ZERO
        state = ATTACK

    if lantern_light.is_visible():
        detection_radius_shape.set_scale(Vector2(LIGHT_DETECTION_MULT, LIGHT_DETECTION_MULT))

    var new_pos = get_global_position()
    if last_pos != new_pos:
        emit_signal("moved", new_pos)

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
