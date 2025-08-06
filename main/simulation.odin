package main
import "core:log"
import "core:math"
import "core:math/rand"

import rl "vendor:raylib"

MAX_VELOCITY_MODULUS :: 100

sim_instantiate_particles :: proc(
	particles: []Particle,
	position: Vec2f = Vec2f{0, 0},
	padding: f32 = 15.0,
) {
	num_particles_side := math.sqrt(f32(len(particles)))
	// we are gonna draw a rectangle of particles so the number of particles has to be a square
	assert(num_particles_side == math.floor(num_particles_side))

	num_particles_side_int: int = int(num_particles_side)

	for y in 0 ..< num_particles_side_int {
		for x in 0 ..< num_particles_side_int {

			particles[y * num_particles_side_int + x] = new_particle(
				position = position + Vec2f{f32(x) * padding, f32(y) * padding},
				color = rl.BLUE,
				velocity = (Vec2f{(rand.float32() * 2 - 1), rand.float32() * 2 - 1} *
					MAX_VELOCITY_MODULUS),
				// velocity = Vec2f{0, 0},
			)

		}
	}

}

sim_predict_positions :: proc(particles: []Particle, dt: f32, velocity_damping: f32 = 1.0) {
	for &particle in particles {
		particle.prev_position = particle.position
		position_delta := particle.velocity * dt * velocity_damping

		particle.position += position_delta
	}
}

sim_compute_next_velocity :: proc(particles: []Particle, dt: f32) {
	for &particle in particles {
		particle.velocity = (particle.position - particle.prev_position) / dt
	}
}

sim_world_bound_collisions_resolve :: proc(particles: []Particle, world_size: Vec2f) {
	for &particle in particles {
		if particle.position.x < 0 || particle.position.x > world_size.x {
			particle.velocity.x = -particle.velocity.x
		}
		if particle.position.y < 0 || particle.position.y > world_size.y {
			particle.velocity.y = -particle.velocity.y
		}
		particle.position = Vec2f {
			math.clamp(particle.position.x, 0, world_size.x),
			math.clamp(particle.position.y, 0, world_size.y),
		}
	}

}

sim_update :: proc(particles: []Particle, dt: f32, world_size: Vec2f) {
	sim_predict_positions(particles, dt)
	sim_compute_next_velocity(particles, dt)
	sim_world_bound_collisions_resolve(particles, world_size)
}


sim_draw :: proc(particles: []Particle) {
	for &particle in particles {
		rl.DrawCircleV(particle.position, 5, particle.color)
	}
}
