package main
import "core:log"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450

WORLD_SIZE :: Vec2f{SCREEN_WIDTH, SCREEN_HEIGHT}
PARTICLES_SQUARE_SIDE :: 40
NUM_PARTICLES :: PARTICLES_SQUARE_SIDE * PARTICLES_SQUARE_SIDE
PARTICLE_RADIUS :: 5


NUM_CELLS :: 1000000
CELL_SIZE :: 25
COLLISION_RADIUS_SQUARED :: CELL_SIZE * CELL_SIZE

Vec2f :: [2]f32
Vec2i :: [2]int

main :: proc() {
	console_logger := log.create_console_logger()
	context.logger = console_logger

	rl.SetTraceLogLevel(.ERROR)
	// rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.SetConfigFlags({.WINDOW_RESIZABLE})

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hello")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)
	log.log(.Info, "Init")


	particles := [PARTICLES_SQUARE_SIDE * PARTICLES_SQUARE_SIDE]Particle{}

	// TODO: hay que liberar la memoria reservada, se puede usar una arena
	sim := sim_init(NUM_PARTICLES, CELL_SIZE, NUM_CELLS)
	sim_instantiate_particles(particles = &sim.particles, position = Vec2f{250, 60})

	render_buffer := rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
	defer rl.UnloadRenderTexture(render_buffer)

	for !rl.WindowShouldClose() { 	// Detect window close button or ESC key
		dt := rl.GetFrameTime()
		screen_size := Vec2f{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
		initial_screen_size := Vec2f{f32(SCREEN_WIDTH), f32(SCREEN_HEIGHT)}

		// HANDLE INPUT
		mouse_pos := rl.GetMousePosition() * initial_screen_size / screen_size
		if rl.IsMouseButtonPressed(.LEFT) {
			log.log(.Info, "Mouse button pressed", mouse_pos)
		}

		// UPDATE
		if dt > 0 {
			// TODO: Lo mismo hay que mover el WORLD_SIZE dentro de la simulación
			sim_update(sim.particles, dt, WORLD_SIZE)
			grid_add_particles(&sim.hash_grid, sim.particles)
		}

		// DRAWING
		{
			rl.BeginTextureMode(render_buffer)
			defer rl.EndTextureMode()

			rl.ClearBackground(rl.DARKGRAY)

			sim_colorize_neighbours(&sim, mouse_pos, rl.RED)
			sim_draw(sim.particles)
		}

		{
			rl.BeginDrawing()
			defer rl.EndDrawing()

			rl.DrawTexturePro(
				render_buffer.texture,
				rl.Rectangle {
					0,
					0,
					f32(render_buffer.texture.width),
					f32(render_buffer.texture.height) * -1,
				},
				rl.Rectangle{0, 0, screen_size.x, screen_size.y},
				Vec2f{},
				0,
				rl.WHITE,
			)

		}
	}
}
