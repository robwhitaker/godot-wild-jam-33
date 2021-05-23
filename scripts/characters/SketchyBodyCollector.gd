extends StaticBody2D

onready var text_container := $RichTextLabel as RichTextLabel

func _ready():
    text_container.set_bbcode("")

func interact():
    if Scene.player.has_body:
        _run_conversation([
            "wow"
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
    # TODO: change this to title transition
    visible = false
