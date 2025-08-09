package main
import rl "vendor:raylib"

PARTICLE_DEFAULT_COLOR :: rl.BLUE

Particle :: struct {
	position:      Vec2f,
	prev_position: Vec2f,
	color:         rl.Color,
	velocity:      Vec2f,
}

new_particle :: proc(
	position: Vec2f = Vec2f{0, 0},
	velocity: Vec2f = Vec2f{0, 0},
	color: rl.Color = PARTICLE_DEFAULT_COLOR,
) -> Particle {
	return Particle {
		position = position,
		prev_position = position,
		color = color,
		velocity = velocity,
	}
}
