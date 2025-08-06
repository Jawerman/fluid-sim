package main
import "core:log"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450

WORLD_SIZE :: Vec2f{SCREEN_WIDTH, SCREEN_HEIGHT}
PARTICLES_SQUARE_SIDE :: 20

Vec2f :: [2]f32

main :: proc() {
	console_logger := log.create_console_logger()
	context.logger = console_logger

	rl.SetTraceLogLevel(.ERROR)
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hello")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)
	log.log(.Info, "Init")

	particles := [PARTICLES_SQUARE_SIDE * PARTICLES_SQUARE_SIDE]Particle{}
	sim_instantiate_particles(particles = particles[:], position = Vec2f{250, 60})

	render_buffer := rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)
	defer rl.UnloadRenderTexture(render_buffer)

	for !rl.WindowShouldClose() { 	// Detect window close button or ESC key
		dt := rl.GetFrameTime()
		// HANDLE INPUT
		mouse_pos := rl.GetMousePosition()
		if rl.IsMouseButtonPressed(.LEFT) {
			log.log(.Info, "Mouse button pressed", mouse_pos)
		}

		// UPDATE
		if dt > 0 {
			sim_update(particles[:], dt, WORLD_SIZE)
		}

		// DRAWING
		{
			rl.BeginTextureMode(render_buffer)
			defer rl.EndTextureMode()

			rl.ClearBackground(rl.DARKGRAY)

			sim_draw(particles[:])
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
				rl.Rectangle{0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())},
				Vec2f{},
				0,
				rl.WHITE,
			)

		}
	}
}
