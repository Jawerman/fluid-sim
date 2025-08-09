package main
import "core:log"
import "core:math"
import "core:math/rand"

import rl "vendor:raylib"

MAX_VELOCITY_MODULUS :: 100

Simulation :: struct {
	// PERF: Podrías ser un SOA
	particles: []Particle,
	hash_grid: HashGrid,
}

sim_init :: proc(num_particles, cellsize, num_cells: int) -> Simulation {
	return Simulation {
		particles = make([]Particle, num_particles),
		hash_grid = new_hash_grid(cellsize, size = num_cells, num_particles = num_particles),
	}
}

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
				velocity = (Vec2f{(rand.float32() * 2 - 1), rand.float32() * 2 - 1} *
					MAX_VELOCITY_MODULUS),
			)

		}
	}

}

sim_colorize_neighbours :: proc(simulation: ^Simulation, position: Vec2f, color: rl.Color) {
	grid_add_particles(&simulation.hash_grid, simulation.particles)

	iter := HashGridIterator {
		hash_grid = &simulation.hash_grid,
	}

	grid_init_neighbours_iterator(&iter, position)

	for &particle in simulation.particles {
		particle.color = PARTICLE_DEFAULT_COLOR
	}

	for has_more, index := grid_iterator_next(&iter);
	    has_more;
	    has_more, index = grid_iterator_next(&iter) {
		simulation.particles[index].color = color
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
		rl.DrawCircleV(particle.position, PARTICLE_RADIUS, particle.color)
	}
}
