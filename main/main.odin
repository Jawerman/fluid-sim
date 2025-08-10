package main
import "core:fmt"
import "core:log"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

Vec2f :: [2]f32
Vec2i :: [2]int

CircularQueue :: struct {
	stopwatch: time.Stopwatch,
	buffer:    [50]f32,
	head:      int,
}

queue_add :: proc(queue: ^CircularQueue, value: f32) {
	queue.buffer[queue.head] = value
	queue.head = (queue.head + 1) % len(queue.buffer)
}

queue_average :: proc(queue: ^CircularQueue) -> f32 {
	sum: f32 = 0
	for value in queue.buffer {
		sum += value
	}
	return sum / f32(len(queue.buffer))
}

main :: proc() {
	console_logger := log.create_console_logger()
	context.logger = console_logger

	rl.SetTraceLogLevel(.ERROR)
	// rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.SetConfigFlags({.WINDOW_RESIZABLE})

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hello")
	defer rl.CloseWindow()

	rl.SetTargetFPS(FPS)
	log.log(.Info, "Init")

	initial_screen_size := Vec2f{f32(SCREEN_WIDTH), f32(SCREEN_HEIGHT)}

	particles := [PARTICLES_SQUARE_SIDE * PARTICLES_SQUARE_SIDE]Particle{}

	// TODO: hay que liberar la memoria reservada, se puede usar una arena
	sim := sim_init(NUM_PARTICLES, CELL_SIZE, NUM_CELLS)

	particles_square_size: f32 = (PARTICLES_SQUARE_SIDE - 1) * PARTICLE_PADDING

	log.log(.Info, "Instantiating particles", particles_square_size)

	instantiation_position := Vec2f {
		(initial_screen_size.x / 2) - (particles_square_size / 2),
		(initial_screen_size.y / 2) - (particles_square_size / 2),
	}
	log.log(.Info, "instantiation_position", instantiation_position)
	sim_instantiate_particles(particles = sim.particles, position = instantiation_position)
	// sim_instantiate_particles(particles = sim.particles, position = Vec2f{0, 0})

	render_buffer := rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
	defer rl.UnloadRenderTexture(render_buffer)

	stop_watch := time.Stopwatch{}

	update_queue := CircularQueue{}
	draw_queue := CircularQueue{}

	udpate_times := [10]f32{}
	draw_times := [10]f32{}


	particle_texture: rl.RenderTexture2D = rl.LoadRenderTexture(
		PARTICLE_RADIUS * 2,
		PARTICLE_RADIUS * 2,
	)
	{
		rl.BeginTextureMode(particle_texture)
		rl.ClearBackground(rl.BLANK)
		rl.DrawCircleV(Vec2f{PARTICLE_RADIUS, PARTICLE_RADIUS}, PARTICLE_RADIUS, rl.WHITE)
		rl.EndTextureMode()
	}

	for !rl.WindowShouldClose() { 	// Detect window close button or ESC key
		dt := rl.GetFrameTime()
		screen_size := Vec2f{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

		// HANDLE INPUT
		mouse_pos := rl.GetMousePosition() * initial_screen_size / screen_size
		if rl.IsMouseButtonPressed(.LEFT) {
			log.log(.Info, "Mouse button pressed", mouse_pos)
		}


		// UPDATE
		{
			time.stopwatch_reset(&stop_watch)
			time.stopwatch_start(&stop_watch)
			defer {
				time.stopwatch_stop(&stop_watch)
				queue_add(
					&update_queue,
					f32(time.duration_milliseconds(time.stopwatch_duration(stop_watch))),
				)
			}

			if dt > 0 {
				// TODO: Lo mismo hay que mover el WORLD_SIZE dentro de la simulación
				sim_update(&sim, dt, WORLD_SIZE)
			}
		}

		// DRAWING
		{
			time.stopwatch_reset(&stop_watch)
			time.stopwatch_start(&stop_watch)
			defer {
				time.stopwatch_stop(&stop_watch)
				queue_add(
					&draw_queue,
					f32(time.duration_milliseconds(time.stopwatch_duration(stop_watch))),
				)
			}

			rl.BeginTextureMode(render_buffer)
			defer rl.EndTextureMode()

			rl.ClearBackground(rl.DARKGRAY)

			sim_colorize_neighbours(&sim, mouse_pos, rl.RED)
			sim_draw(sim.particles, particle_texture.texture)
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

			{

				update_time := queue_average(&update_queue)
				draw_time := queue_average(&draw_queue)
				total_time := update_time + draw_time

				update_percentage := 100 * (update_time / (update_time + draw_time))
				draw_percentage := 100 * (draw_time / (update_time + draw_time))

				cadena := fmt.tprintf(
					"update: %.2f ms (%5.2f%%)\ndraw: %.2f ms (%5.2f%%)",
					queue_average(&update_queue),
					update_percentage,
					queue_average(&draw_queue),
					draw_percentage,
				)
				cstr := strings.clone_to_cstring(cadena)
				defer delete(cstr)

				color := total_time > 1000.0 / f32(FPS) ? rl.RED : rl.GREEN

				rl.DrawText(cstr, 10, 10, 20, color)
			}
		}

	}
}
