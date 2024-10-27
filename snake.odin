package snake

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

WINDOW_SIZE :: 500
GRID_SIZE :: 20
MAX_SNAKE_LENGTH :: GRID_SIZE * GRID_SIZE
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_SIZE * CELL_SIZE
TICK_RATE :: 0.12


Direction :: enum {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

Coordinate :: struct {
	x, y: int,
}

to_rect :: proc(coord: Coordinate) -> rl.Rectangle {
	return rl.Rectangle{f32(coord.x) * CELL_SIZE, f32(coord.y) * CELL_SIZE, CELL_SIZE, CELL_SIZE}
}

Snake :: struct {
	direction: Direction,
	length:    int,
	// The tail is in index `0` while the head is in index `length - 1`
	body:      [MAX_SNAKE_LENGTH]Coordinate,
}

Stage :: enum {
	TITLE,
	PLAYING,
	GAME_OVER,
}

State :: struct {
	snake:      Snake,
	tick_timer: f32,
	strawberry: Coordinate,
	stage:      Stage,
}

new_snake :: proc() -> Snake {
	snake := Snake {
		direction = Direction.DOWN,
		length    = 3,
	}
	snake.body[0] = Coordinate{10, 0}
	snake.body[1] = Coordinate{10, 1}
	snake.body[2] = Coordinate{10, 2}

	return snake
}

is_coordinate_in_snake :: proc(snake: ^Snake, coordinate: ^Coordinate) -> bool {
	for i in 0 ..< snake.length {
		if snake.body[i] == coordinate^ {
			return true
		}
	}
	return false
}

is_strawberry_in_snake :: proc(snake: ^Snake, strawberry: ^Coordinate) -> bool {
	return is_coordinate_in_snake(snake, strawberry)
}

new_strawberry :: proc(snake: ^Snake) -> Coordinate {
	coordinate := Coordinate{rand.int_max(GRID_SIZE), rand.int_max(GRID_SIZE)}
	for {
		if !is_strawberry_in_snake(snake, &coordinate) {
			return coordinate
		}
		coordinate = new_strawberry(snake)
	}
}

new_state :: proc() -> State {
	snake := new_snake()
	strawberry := new_strawberry(&snake)
	return State {
		snake = snake,
		tick_timer = TICK_RATE,
		strawberry = strawberry,
		stage = Stage.TITLE,
	}
}

update_snake_direction :: proc(state: ^State) {
	keypress := rl.GetKeyPressed()
	if keypress == .UP do state.snake.direction = Direction.UP
	if keypress == .DOWN do state.snake.direction = Direction.DOWN
	if keypress == .LEFT do state.snake.direction = Direction.LEFT
	if keypress == .RIGHT do state.snake.direction = Direction.RIGHT
}

get_new_head :: proc(state: ^State) -> Coordinate {
	head := state.snake.body[state.snake.length - 1]
	switch state.snake.direction {
	case Direction.UP:
		head.y -= 1
	case Direction.DOWN:
		head.y += 1
	case Direction.LEFT:
		head.x -= 1
	case Direction.RIGHT:
		head.x += 1
	}

	return head
}

update_snake :: proc(state: ^State) {
	new_head := get_new_head(state)

	is_head_out_of_bounds :=
		new_head.x < 0 || new_head.x >= GRID_SIZE || new_head.y < 0 || new_head.y >= GRID_SIZE
	is_head_colliding := is_coordinate_in_snake(&state.snake, &new_head)
	is_game_over := is_head_out_of_bounds || is_head_colliding
	if is_game_over {
		state.stage = .GAME_OVER
		return
	}

	if new_head == state.strawberry {
		// Add new head
		state.snake.length += 1
		state.snake.body[state.snake.length - 1] = new_head

		// Create new strawberry
		state.strawberry = new_strawberry(&state.snake)
	} else {
		// Update body
		for i in 0 ..< (state.snake.length - 1) {
			body_part := state.snake.body[i]
			prev_body_part := state.snake.body[i + 1]
			assert(
				body_part.x != prev_body_part.x || body_part.y != prev_body_part.y,
				"two consecutive body parts overlap",
			)
			state.snake.body[i] = state.snake.body[i + 1]
		}

		// Update head
		state.snake.body[state.snake.length - 1] = new_head
	}
}

update_state :: proc(state: ^State) {
	switch state.stage {
	case .TITLE:
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
			state.stage = .PLAYING
		}
		return
	case .GAME_OVER:
		if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
			state.stage = .TITLE
			state.snake = new_snake()
			state.strawberry = new_strawberry(&state.snake)
		}
		return
	case .PLAYING:
	// continue below
	}

	update_snake_direction(state)

	state.tick_timer -= rl.GetFrameTime()
	if state.tick_timer > 0 do return

	state.tick_timer = TICK_RATE - state.tick_timer

	update_snake(state)

	assert(
		!is_strawberry_in_snake(&state.snake, &state.strawberry),
		"strawberry is in snake after update_state",
	)
}

draw_snake :: proc(snake: ^Snake) {
	for i in 0 ..< snake.length {
		body_part := snake.body[i]
		color := rl.Color{160, 160, 160, 255}
		if i == snake.length - 1 {
			color = rl.Color{255, 255, 255, 255}
		}
		rl.DrawRectangleRec(to_rect(body_part), color)
	}
}

draw_strawberry :: proc(strawberry: ^Coordinate) {
	rl.DrawRectangleRec(to_rect(strawberry^), rl.Color{255, 0, 0, 255})
}

draw_score :: proc(state: ^State) {
	rl.DrawText(fmt.ctprint("Score: ", state.snake.length - 3), 5, 5, 10, rl.WHITE)
}

draw_title_screen :: proc(title: cstring, subtitle: cstring) {
	title_width := rl.MeasureText(title, 20)
	rl.DrawText(title, CANVAS_SIZE / 2 - title_width / 2, CANVAS_SIZE / 2 - 35, 20, rl.WHITE)

	subtitle_width := rl.MeasureText(subtitle, 12)
	rl.DrawText(subtitle, CANVAS_SIZE / 2 - subtitle_width / 2, CANVAS_SIZE / 2 - 20, 12, rl.WHITE)
}

draw_title :: proc(state: ^State) {
	switch state.stage {
	case .TITLE:
		draw_title_screen("Snake", "Press space to start")
	case .GAME_OVER:
		draw_title_screen("Game Over", "Press space to continue")
	case .PLAYING:
	// do nothing
	}
}

draw :: proc(state: ^State) {
	rl.BeginDrawing()
	rl.ClearBackground({76, 53, 83, 255})

	camera := rl.Camera2D {
		zoom = f32(WINDOW_SIZE) / CANVAS_SIZE,
	}
	rl.BeginMode2D(camera)

	draw_strawberry(&state.strawberry)
	draw_snake(&state.snake)
	draw_score(state)
	draw_title(state)

	rl.EndMode2D()
	rl.EndDrawing()
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "Snake")
	rl.SetTargetFPS(60)

	state := new_state()

	for !rl.WindowShouldClose() {
		update_state(&state)
		draw(&state)
	}

	rl.CloseWindow()
}
