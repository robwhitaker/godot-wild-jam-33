extends Area2D

func select():
    pass

func unselect():
    pass

func interact():
    Scene.player.pickup_body()
    owner.queue_free()
