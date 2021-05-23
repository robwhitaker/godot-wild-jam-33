extends Light2D

export var flicker_range : Vector2
export var min_scale_multiplier : float
export var min_flicker_delay : float
export var chance_to_flicker : float

var time_until_flicker := 0.0

onready var base_scale := scale

func _process(delta):
    if time_until_flicker - delta <= 0:
        if randf() < chance_to_flicker:
            var flicker_energy = rand_range(flicker_range.x, flicker_range.y)
            set_energy(flicker_energy)

            var energy_percent = (flicker_energy - flicker_range.x) / (flicker_range.y - flicker_range.x)
            var max_scale = 1 - min_scale_multiplier
            var scale_by = (1 - energy_percent) * max_scale
            var scale_multiplier = min_scale_multiplier + scale_by
            set_scale(base_scale * scale_multiplier)

            time_until_flicker = min_flicker_delay
    else:
        time_until_flicker -= delta
