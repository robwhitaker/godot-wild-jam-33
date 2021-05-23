extends Area2D

func select():
    pass

func unselect():
    pass

func interact():
    Scene.player.has_body = true
    owner.queue_free()
