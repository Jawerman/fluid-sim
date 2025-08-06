package main
import rl "vendor:raylib"

Particle :: struct {
	position:      Vec2f,
	prev_position: Vec2f,
	color:         rl.Color,
	velocity:      Vec2f,
}

new_particle :: proc(
	position: Vec2f = Vec2f{0, 0},
	velocity: Vec2f = Vec2f{0, 0},
	color: rl.Color = rl.WHITE,
) -> Particle {
	return Particle {
		position = position,
		prev_position = position,
		color = color,
		velocity = velocity,
	}
}
