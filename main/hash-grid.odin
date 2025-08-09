package main
import "core:log"
import "core:math"
import "core:mem"
import "core:slice"

// PRIME_1 :: 6614058611
// PRIME_2 :: 7528850467

PRIME_1 :: 73856093
PRIME_2 :: 19349663

HashGrid :: struct {
	cellsize:                     int,
	size:                         int,
	cell_indices:                 []int,
	// IDEA: El array de partículas podría ser directamente el que está en el hash grid
	// y no tener un array auxiliar de indices. Haría falta un array auxiliar para ordenar
	// las partículas dentro de cada celda.
	// Ademas, tendría como ventaja que podría crear slices directamente del array de partículas para
	// cada celda.
	particle_indices:             []int,
	// IDEA: lo mismo puedo usar un allocator temporal para no tener que tener aquí el _last_available_cell_indices
	// ya que es para operaciones internas de grid_add_particles.
	// Por ahora, lo dejo así para no tener que reservar memoria dentro de la función
	_last_available_cell_indices: []int,
}

HashGridIterator :: struct {
	hash_grid:                ^HashGrid,
	current_cell:             int,
	current_particle_in_cell: int,
	particles_indices:        [][]int,
	_particles_indices:       [9][]int,
}

grid_init_neighbours_iterator :: proc(iter: ^HashGridIterator, position: Vec2f) {
	coords := grid_coords_from_position(position, iter.hash_grid.cellsize)
	index := 0

	for i in -1 ..= 1 {
		for j in -1 ..= 1 {
			neighbour_hash := grid_coords_to_hash(coords + Vec2i{i, j}, iter.hash_grid.size)
			if neighbour_hash < 0 || neighbour_hash >= len(iter.hash_grid.cell_indices) do continue
			iter._particles_indices[index] = grid_get_cell_indices_slice(
				iter.hash_grid,
				neighbour_hash,
			)
			index += 1
		}
	}
	iter.particles_indices = iter._particles_indices[:index]
}

grid_iterator_next :: proc(iter: ^HashGridIterator) -> (has_more: bool, particle_index: int) {
	for iter.current_cell < len(iter.particles_indices) {
		particle_indices_slice := iter.particles_indices[iter.current_cell]
		particle_index := iter.current_particle_in_cell

		if particle_index >= len(particle_indices_slice) {
			iter.current_particle_in_cell = 0
			iter.current_cell += 1
			continue
		}
		iter.current_particle_in_cell += 1
		return true, particle_indices_slice[particle_index]
	}
	return false, 0
}

new_hash_grid :: proc(cellsize, size, num_particles: int) -> HashGrid {
	return HashGrid {
		cellsize = cellsize,
		size = size,
		cell_indices = make([]int, size),
		particle_indices = make([]int, num_particles),
		_last_available_cell_indices = make([]int, size),
	}
}

// Rellena 'indices' con la posición donde terminará cada celda en el array de particulas agrupadas por celda
grid_fill_cell_indices :: proc(grid_hash: ^HashGrid, particles: #soa[]Particle) {
	slice.zero(grid_hash.cell_indices)

	// indices tiene inicialmente la cuenta de elementos que hay en la celda
	for &particle in particles {
		hash := grid_hash_from_position(particle.position, grid_hash.cellsize, grid_hash.size)
		grid_hash.cell_indices[hash] += 1
	}

	// indices ahora tiene el indice donde acaba cada celda
	for i in 1 ..< len(grid_hash.cell_indices) {
		grid_hash.cell_indices[i] += grid_hash.cell_indices[i - 1]
	}
}

grid_add_particles :: proc(grid_hash: ^HashGrid, particles: #soa[]Particle) {
	grid_fill_cell_indices(grid_hash, particles)

	// OPTIM: Quizá pueda usar el propio cell_indices para ir restando la cantidad de elementos en cada celda.
	// Al final cada posición tendría el comienzo de la celda en lugar del final. Eso implica que tiene que tener
	// un tamaño de size + 1 (si no, pierdo donde termina la última celda). No me parece muy elegante en principio.
	mem.copy_non_overlapping(
		&grid_hash._last_available_cell_indices[0],
		&grid_hash.cell_indices[0],
		len(grid_hash.cell_indices) * size_of(type_of(grid_hash.cell_indices[0])),
	)

	slice.zero(grid_hash.particle_indices)


	for &particle, index in particles {
		hash := grid_hash_from_position(particle.position, grid_hash.cellsize, grid_hash.size)
		grid_hash._last_available_cell_indices[hash] -= 1

		grid_hash.particle_indices[grid_hash._last_available_cell_indices[hash]] = index
	}
}

grid_get_cell_indices_slice :: proc(grid_hash: ^HashGrid, cell_index: int) -> []int {
	initial_index := cell_index > 0 ? grid_hash.cell_indices[cell_index - 1] : 0
	return grid_hash.particle_indices[initial_index:grid_hash.cell_indices[cell_index]]
}

grid_hash_from_position :: proc(position: Vec2f, cellsize: int, size: int) -> int {
	coords := grid_coords_from_position(position, cellsize)
	return grid_coords_to_hash(coords, size)
}

grid_coords_from_position :: proc(position: Vec2f, cellsize: int) -> Vec2i {
	return Vec2i {
		int(math.floor(position.x / f32(cellsize))),
		int(math.floor(position.y / f32(cellsize))),
	}
}

grid_coords_to_hash :: proc(
	position: Vec2i,
	size: int,
	prime1: int = PRIME_1,
	prime2: int = PRIME_2,
) -> int {
	return (position.x * prime1 ~ position.y * prime2) % size
}
