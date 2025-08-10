package main
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"

import rl "vendor:raylib"

Simulation :: struct {
	// PERF: Podría ser un SOA
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
	padding: f32 = PARTICLE_PADDING,
) {
	num_particles_side := math.sqrt(f32(len(particles)))
	// we are gonna draw a rectangle of particles so the number of particles has to be a square
	assert(num_particles_side == math.floor(num_particles_side))

	num_particles_side_int: int = int(num_particles_side)

	for y in 0 ..< num_particles_side_int {
		for x in 0 ..< num_particles_side_int {

			particles[y * num_particles_side_int + x] = new_particle(
				position = position + Vec2f{f32(x) * padding, f32(y) * padding},
				// velocity = (Vec2f{(rand.float32() * 2 - 1), rand.float32() * 2 - 1} * MAX_VELOCITY_MODULUS),
			)
		}
	}
}

sim_apply_gravity :: proc(particles: []Particle, gravity: Vec2f, dt: f32) {
	for &particle in particles {
		particle.velocity += gravity * dt
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
		pos := particle.position

		if pos.x < 0 {
			particle.position.x = 0
			particle.prev_position.x = 0
		}
		if pos.y < 0 {
			particle.position.y = 0
			particle.prev_position.y = 0
		}
		if pos.x > world_size.x {
			particle.position.x = world_size.x - 1
			particle.prev_position.x = world_size.x - 1
		}
		if pos.y > world_size.y {
			particle.position.y = world_size.y - 1
			particle.prev_position.y = world_size.y - 1
		}
	}
}

sim_update :: proc(simulation: ^Simulation, dt: f32, world_size: Vec2f) {
	sim_apply_gravity(simulation.particles, GRAVITY, dt)

	sim_predict_positions(simulation.particles, dt)

	// sim_world_bound_collisions_resolve(simulation.particles, world_size)

	grid_add_particles(&simulation.hash_grid, simulation.particles)

	double_density_relaxation(simulation, dt)

	sim_world_bound_collisions_resolve(simulation.particles, world_size)

	sim_compute_next_velocity(simulation.particles, dt)
}

double_density_relaxation :: proc(simulation: ^Simulation, dt: f32) {

	for &particle, i in simulation.particles {
		density, density_near: f32 = 0, 0


		iter := HashGridIterator {
			hash_grid = &simulation.hash_grid,
		}
		grid_init_neighbours_iterator(&iter, particle.position)

		// Density calculation
		for has_more, neighbour_i := grid_iterator_next(&iter);
		    has_more;
		    has_more, neighbour_i = grid_iterator_next(&iter) {

			neighbour := &simulation.particles[neighbour_i]


			if neighbour_i == i || !can_positions_interact(particle.position, neighbour.position) do continue


			diff_vector := neighbour.position - particle.position
			distance := linalg.vector_length(diff_vector)
			ratio := distance / INTERACTION_RADIUS


			if ratio >= 1.0 do continue

			density += math.pow(1 - ratio, 2)
			density_near += math.pow(1 - ratio, 3)
		}

		pressure := K * (density - REST_DENSITY)
		pressure_near := K_NEAR * density_near
		particle_displacement := Vec2f{}

		grid_reset_neighbours_iterator(&iter)

		// Displacemente calculation
		for has_more, neighbour_i := grid_iterator_next(&iter);
		    has_more;
		    has_more, neighbour_i = grid_iterator_next(&iter) {

			neighbour := &simulation.particles[neighbour_i]


			if neighbour_i == i || !can_positions_interact(particle.position, neighbour.position) do continue


			diff_vector := neighbour.position - particle.position
			distance := linalg.vector_length(diff_vector)
			ratio := distance / INTERACTION_RADIUS


			if ratio >= 1.0 do continue

			direction := linalg.normalize(diff_vector)
			displacement_term :=
				math.pow(dt, 2) * (pressure * (1 - ratio) + pressure_near * math.pow(1 - ratio, 2))

			displacement := direction * displacement_term

			neighbour.position += displacement * 0.5
			particle_displacement -= displacement * 0.5
		}
		particle.position += particle_displacement
	}
}

can_positions_interact :: proc(pos1, pos2: Vec2f) -> bool {
	distance_squared := math.abs(linalg.vector_length2(pos1 - pos2))
	return distance_squared < INTERACTION_RADIUS_SQUARED
}

sim_particle_out_of_bounds :: proc(particle: Particle, world_size: Vec2f = WORLD_SIZE) -> bool {
	return(
		particle.position.x < 0 ||
		particle.position.y < 0 ||
		particle.position.x > world_size.x ||
		particle.position.y > world_size.y \
	)
}

sim_draw :: proc(particles: []Particle, texture: rl.Texture2D) {
	for &particle in particles {
		if (sim_particle_out_of_bounds(particle)) {
			log.error("Particle out of bounds", particle)
		}
		rl.DrawTextureV(texture, particle.position - PARTICLE_CENTER_OFFSET, particle.color)
	}
}
