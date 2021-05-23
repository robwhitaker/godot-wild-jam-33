extends StaticBody2D

onready var text_container := $RichTextLabel as RichTextLabel

func _ready():
    text_container.set_bbcode("")

func interact():
    if Scene.player.has_body:
        _run_conversation([
            "That is a prime hero corpse right there.",
            "What do I need it for? None of your concern.",
            "Now, take this gold and be gone.",
            "I'm sure we'll do business again... ahahaha."
        ], "_go_to_title")
    else:
        _run_conversation([
            "Hey. Hey, buddy.",
            "You're a body collector, yeah?",
            "Listen, a hero died out in those woods.",
            "I need that body... for reasons.",
            "For his family, I mean.",
            "Be a pal and collect it for me.",
            "I'll pay ya real nice."
        ])

func _run_conversation(text, cb=null):
    for line in text:
        text_container.set_bbcode("[center]" + line + "[/center]")
        yield(get_tree().create_timer(2.5), "timeout")
    text_container.set_bbcode("")
    if cb:
        call(cb)

func _go_to_title():
    var title_screen_path = "res://scenes/rooms/TitleScreen.tscn"
    SceneChanger.change_scene(Vector2.ZERO, "", title_screen_path)
    Player.health = 100
