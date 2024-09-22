const std = @import("std");
const testing = std.testing;
const ray = @import("raylib.zig");
const Point = @import("math.zig").Point;
const consts = @import("constants.zig");
const P = @import("constants.zig").P;

pub fn play_sirtet() !void {
    ray.SetConfigFlags(ray.FLAG_MSAA_4X_HINT | ray.FLAG_VSYNC_HINT);
    ray.InitWindow(consts.WIDTH, consts.HEIGTH, "zig raylib example");
    defer ray.CloseWindow();

    ray.InitAudioDevice();
    defer ray.CloseAudioDevice();
    const music: ray.Music = ray.LoadMusicStream("music/tetris_music.mp3");
    defer ray.UnloadMusicStream(music);
    ray.SetMusicVolume(music, 0.2);
    while (!ray.IsMusicReady(music)) {}
    ray.PlayMusicStream(music);

    const pause_sound: ray.Sound = ray.LoadSound("music/pause.wav");

    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 8 }){};
    const allocator = gpa.allocator();
    defer {
        switch (gpa.deinit()) {
            .leak => @panic("leaked memory"),
            else => {},
        }
    }

    var grid = Grid.init();
    var tetrominos = std.ArrayList(Tetromino).init(allocator);
    var active_tetromino = Tetromino.init(&grid);
    defer tetrominos.deinit();

    var now = std.time.milliTimestamp();
    var prev: i64 = now;
    var game_clock: i64 = 0;
    var action: ?Action = null;
    var pause: bool = false;

    while (!ray.WindowShouldClose()) {
        if (!pause) {
            ray.UpdateMusicStream(music);
        }

        now = std.time.milliTimestamp();
        const delta_time = now - prev;
        prev = now;
        game_clock += delta_time;

        action = null;
        if (ray.IsKeyPressed(ray.KEY_A)) {
            action = Action.move_left;
            active_tetromino.takeAction(action.?);
        } else if (ray.IsKeyPressed(ray.KEY_D)) {
            action = Action.move_right;
            active_tetromino.takeAction(action.?);
        } else if (ray.IsKeyPressed(ray.KEY_S)) {
            action = Action.speed_up;
        } else if (ray.IsKeyPressed(ray.KEY_R)) {
            action = Action.rotate;
            active_tetromino.takeAction(action.?);
        } else if (ray.IsKeyPressed(ray.KEY_P)) {
            if (!pause) {
                ray.PlaySound(pause_sound);
            }
            pause = !pause;
        }

        // Draw
        {
            ray.BeginDrawing();
            defer ray.EndDrawing();
            ray.ClearBackground(ray.BLACK);

            if (!pause and (game_clock > 1000 or action == Action.speed_up)) {
                active_tetromino.update(null);
                if (!active_tetromino.isActive()) {
                    try tetrominos.append(active_tetromino);
                    const completed_rows: [Grid.ROWS]bool = grid.checkForCompletedRows();
                    for (0..completed_rows.len) |i| {
                        if (completed_rows[i]) {
                            for (tetrominos.items) |*tetromino| {
                                tetromino.*.clear(i);
                            }
                        }
                    }
                    active_tetromino = Tetromino.init(&grid);
                }
                game_clock = 0;
            }

            grid.draw();
            active_tetromino.draw();
            for (tetrominos.items) |*tetromino| {
                tetromino.draw();
            }

            const seconds: u32 = @intFromFloat(ray.GetTime());
            const dynamic = try std.fmt.allocPrintZ(allocator, "running since {d} seconds", .{seconds});
            defer allocator.free(dynamic);
            ray.DrawText(dynamic, @divTrunc(consts.WIDTH, 2) - 50, 50, 20, ray.WHITE);
            ray.DrawText("Zero", 0, 0, 20, ray.RED);
            ray.DrawText("Max", consts.WIDTH - 25, consts.HEIGTH - 25, 20, ray.RED);
            ray.DrawFPS(consts.WIDTH - 100, 10);
        }
    }
}

const Action = enum {
    move_left,
    move_right,
    speed_up,
    rotate,
};

const Shape = enum {
    I,
    O,
    T,
};

const colors = [_]ray.Color{ ray.RED, ray.GREEN, ray.BLUE };
pub fn randomColor() ray.Color {
    return colors[@as(u64, @intCast(std.time.milliTimestamp())) % colors.len];
}

const Status = enum {
    active,
    hit_floor,
    hit_cube,

    pub fn isActive(self: Status) bool {
        return self == Status.active;
    }
};

const Tetromino = struct {
    const Self = @This();

    shape: Shape,
    rotation: u4,
    cubes: [4]Cube,
    status: Status = Status.active,
    cubes_active: u8 = 4,

    pub fn init(grid: *Grid) Self {
        const seed = @as(u64, @intCast(std.time.milliTimestamp()));
        var prng = std.Random.DefaultPrng.init(seed);
        const rng = prng.random();
        const shape = rng.enumValue(Shape);
        const color = randomColor();

        var cubes: [4]Cube = undefined;
        switch (shape) {
            Shape.I => {
                cubes[0] = Cube.init(grid, 0, 5, color);
                cubes[1] = Cube.init(grid, 1, 5, color);
                cubes[2] = Cube.init(grid, 2, 5, color);
                cubes[3] = Cube.init(grid, 3, 5, color);
            },
            Shape.T => {
                cubes[0] = Cube.init(grid, 1, 4, color);
                cubes[1] = Cube.init(grid, 0, 5, color);
                cubes[2] = Cube.init(grid, 1, 5, color);
                cubes[3] = Cube.init(grid, 1, 6, color);
            },
            Shape.O => {
                cubes[0] = Cube.init(grid, 0, 4, color);
                cubes[1] = Cube.init(grid, 1, 4, color);
                cubes[2] = Cube.init(grid, 0, 5, color);
                cubes[3] = Cube.init(grid, 1, 5, color);
            },
        }

        return Self{
            .shape = shape,
            .cubes = cubes,
            .rotation = 0,
        };
    }

    pub fn update(self: *Self, action: ?Action) void {
        if (!self.status.isActive()) return;

        var hit_floor: bool = false;
        for (&self.cubes) |*cube| {
            hit_floor = cube.hitFloor();
            if (hit_floor) {
                self.status = Status.hit_floor;
                for (&self.cubes) |*c| {
                    c.updateGrid();
                }
                return;
            }
        }

        var hit_cube: bool = false;
        for (&self.cubes) |*cube| {
            hit_cube = cube.hitCube();
            if (hit_cube) {
                self.status = Status.hit_cube;
                for (&self.cubes) |*c| {
                    c.updateGrid();
                }
                return;
            }
        }

        for (&self.cubes) |*cube| {
            cube.*.update(action);
        }
    }

    pub fn draw(self: *Self) void {
        for (&self.cubes) |*cube| {
            cube.*.draw();
        }
    }

    // All of this should happen only with an active piece.
    pub fn takeAction(self: *Self, action: Action) void {
        switch (action) {
            Action.move_left, Action.move_right => {
                var action_ok = true;
                for (&self.cubes) |*cube| {
                    action_ok = cube.*.isActionOk(action);
                    if (!action_ok) break;
                }

                if (action_ok) {
                    for (&self.cubes) |*cube| {
                        cube.*.update(action);
                    }
                }
            },
            Action.speed_up => unreachable,
            Action.rotate => {
                const rotated = self.rotatedPiece();
                if (rotated == null) {
                    return;
                } else {
                    for (0..rotated.?.len) |i| {
                        self.cubes[i].setPosition(rotated.?[i]);
                    }
                }
                self.rotation = self.nextRotation();
            },
        }
    }

    pub fn isActive(self: *Self) bool {
        return self.status.isActive();
    }

    pub fn nextRotation(self: *const Self) u4 {
        return switch (self.shape) {
            Shape.I => (self.rotation + 1) % 2,
            Shape.T => (self.rotation + 1) % 4,
            Shape.O => (self.rotation + 1) % 1,
        };
    }

    pub fn clear(self: *Self, row: usize) void {
        if (self.cubes_active == 0) {
            return;
        }
        for (&self.cubes) |*cube| {
            cube.clear(row, &self.cubes_active);
            cube.postClearUpdate(row);
        }
    }

    pub fn rotatedPiece(self: *const Self) ?[4][2]usize {
        var copy: [4][2]i32 = undefined;
        for (0..4) |cube| {
            copy[cube] = [2]i32{ @as(i32, @intCast(self.cubes[cube].position[0])), @as(i32, @intCast(self.cubes[cube].position[1])) };
        }
        const proposed: [4][2]i32 = switch (self.shape) {
            Shape.T => switch (self.rotation) {
                0 => [4][2]i32{ [_]i32{ copy[0][0] - 2, copy[0][1] }, [_]i32{ copy[1][0], copy[1][1] }, [_]i32{ copy[2][0] - 1, copy[2][1] - 1 }, [_]i32{ copy[3][0], copy[3][1] - 2 } },

                1 => [4][2]i32{ [_]i32{ copy[0][0], copy[0][1] + 2 }, [_]i32{ copy[1][0], copy[1][1] }, [_]i32{ copy[2][0] - 1, copy[2][1] + 1 }, [_]i32{ copy[3][0] - 2, copy[3][1] } },

                2 => [4][2]i32{ [_]i32{ copy[0][0] + 2, copy[0][1] }, [_]i32{ copy[1][0], copy[1][1] }, [_]i32{ copy[2][0] + 1, copy[2][1] + 1 }, [_]i32{ copy[3][0], copy[3][1] + 2 } },

                3 => [4][2]i32{ [_]i32{ copy[0][0], copy[0][1] - 2 }, [_]i32{ copy[1][0], copy[1][1] }, [_]i32{ copy[2][0] + 1, copy[2][1] - 1 }, [_]i32{ copy[3][0] + 2, copy[3][1] } },
                else => unreachable,
            },
            Shape.O => return null,
            Shape.I => switch (self.rotation) {
                0 => [4][2]i32{ [_]i32{ copy[0][0] + 1, copy[0][1] + 1 }, [_]i32{ copy[1][0], copy[1][1] }, [_]i32{ copy[2][0] - 1, copy[2][1] - 1 }, [_]i32{ copy[3][0] - 2, copy[3][1] - 2 } },

                1 => [4][2]i32{ [_]i32{ copy[0][0] - 1, copy[0][1] - 1 }, [_]i32{ copy[1][0], copy[1][1] }, [_]i32{ copy[2][0] + 1, copy[2][1] + 1 }, [_]i32{ copy[3][0] + 2, copy[3][1] + 2 } },
                else => unreachable,
            },
        };

        var in_bounds: bool = true;
        var has_cube: bool = false;
        for (0..4) |cube| {
            in_bounds = Grid.withinBounds(proposed[cube][0], proposed[cube][1]);
            if (!in_bounds) break;
            has_cube = self.cubes[0].grid.positionContainsCube(@as(usize, @intCast(proposed[cube][0])), @as(usize, @intCast(proposed[cube][1])));
            if (has_cube) break;
        }

        if (!in_bounds or has_cube) return null;
        // for (0..4) |cube| {
        //     std.debug.print("Current position ({}, {})\n", .{ self.cubes[cube].position[0], self.cubes[cube].position[1] });
        // }

        var result: ?[4][2]usize = undefined;
        for (0..4) |cube| {
            result.?[cube] = [2]usize{ @as(usize, @intCast(proposed[cube][0])), @as(usize, @intCast(proposed[cube][1])) };
            //  std.debug.print("Setting position to ({}, {})\n", .{ result.?[cube][0], result.?[cube][1] });
        }

        return result;
    }
};

const Cube = struct {
    const Self = @This();

    position: [2]usize,
    grid: *Grid,
    size: i32,
    color: ray.Color,
    cleared: bool = false,

    pub fn init(grid: *Grid, row: usize, col: usize, color: ray.Color) Self {
        const size = Grid.SIZE - 2 * Grid.INNER_MARGIN;
        return Self{
            .position = .{ row, col },
            .grid = grid,
            .size = size,
            .color = color,
        };
    }

    pub fn update(self: *Self, action: ?Action) void {
        if (self.cleared) return;

        if (action == null) {
            self.position[0] += 1;
        } else {
            switch (action.?) {
                Action.move_left => self.position[1] -= 1,
                Action.move_right => self.position[1] += 1,
                Action.speed_up => self.position[0] += 1,
                Action.rotate => unreachable,
            }
        }
    }

    pub fn postClearUpdate(self: *Self, row: usize) void {
        if (self.cleared or row < self.position[0]) return;

        self.grid.unsetCube(self.position[0], self.position[1]);
        self.position[0] += 1;
        self.updateGrid();
    }

    pub fn draw(self: *const Self) void {
        if (self.cleared) return;

        const xy = self.position_to_xy();

        ray.DrawRectangle(xy[0], xy[1], self.size, self.size, self.color);
        ray.DrawCircle(xy[2].x, xy[2].y, 2, ray.BLACK);
    }

    fn position_to_xy(self: *const Self) struct { i32, i32, Point(i32) } {
        const center = self.grid.centers[self.position[0]][self.position[1]];
        const x = center.x - @divTrunc(Grid.SIZE, 2) + Grid.INNER_MARGIN;
        const y = center.y - @divTrunc(Grid.SIZE, 2) + Grid.INNER_MARGIN;
        return .{ x, y, center };
    }

    pub fn updateGrid(self: *Self) void {
        if (self.cleared) return;
        self.grid.setCube(self.position[0], self.position[1]);
    }

    pub fn clear(self: *Self, row: usize, count: *u8) void {
        if (self.cleared) return;
        if (self.position[0] == row) {
            count.* -= 1;
            self.cleared = true;
        }
    }

    pub fn hitFloor(self: *const Self) bool {
        return self.position[0] == Grid.ROWS - 1;
    }

    pub fn hitCube(self: *const Self) bool {
        return self.grid.positionContainsCube(self.position[0] + 1, self.position[1]);
    }

    pub fn isActionOk(self: *const Self, action: Action) bool {
        switch (action) {
            Action.move_left => {
                return !(self.position[1] == 0) and !self.grid.positionContainsCube(self.position[0], self.position[1] - 1);
            },
            Action.move_right => {
                return !(self.position[1] == Grid.COLS - 1) and !self.grid.positionContainsCube(self.position[0], self.position[1] + 1);
            },
            Action.speed_up => unreachable,
            Action.rotate => {
                return false;
            },
        }
    }

    pub fn setPosition(self: *Self, position: [2]usize) void {
        self.position = position;
    }
};

const Grid = struct {
    const Self = @This();

    // NOTE Everything here should be divisible by two.
    pub const COLS = 10;
    pub const ROWS = 20;
    pub const SIZE = 36;
    pub const INNER_MARGIN = 6;
    pub const OUTER_MARGIN = 10;

    left_margin: i32,
    top_margin: i32,
    centers: [ROWS][COLS]Point(i32),
    cubes: [ROWS][COLS]bool,

    pub fn init() Self {
        var center_window: i32 = consts.WIDTH / 2;
        var center_board: i32 = @divTrunc(COLS * SIZE + COLS * OUTER_MARGIN, 2);
        const left_margin: i32 = center_window - center_board;

        center_window = consts.HEIGTH / 2;
        center_board = @divTrunc(ROWS * SIZE + ROWS * OUTER_MARGIN, 2);
        const top_margin: i32 = center_window - center_board;

        var centers: [ROWS][COLS]Point(i32) = undefined;
        var cubes: [ROWS][COLS]bool = undefined;
        for (0..ROWS) |row| {
            for (0..COLS) |col| {
                centers[row][col] = Point(i32){
                    .x = left_margin + @as(i32, @intCast(col * SIZE)) + @as(i32, @intCast((col + 1) * OUTER_MARGIN + @divTrunc(SIZE, 2))),
                    .y = top_margin + @as(i32, @intCast(row * SIZE)) + @as(i32, @intCast((row + 1) * OUTER_MARGIN + @divTrunc(SIZE, 2))),
                };
                cubes[row][col] = false;
            }
        }

        return Self{
            .left_margin = left_margin,
            .top_margin = top_margin,
            .centers = centers,
            .cubes = cubes,
        };
    }

    pub fn draw(self: *const Self) void {
        for (0..ROWS) |row| {
            for (0..COLS) |col| {
                const rectangle = ray.Rectangle{ .x = @as(f32, @floatFromInt(self.left_margin + @as(i32, @intCast(col * SIZE)) + @as(i32, @intCast((col + 1) * OUTER_MARGIN)))), .y = @as(f32, @floatFromInt(self.top_margin + @as(i32, @intCast(row * SIZE)) + @as(i32, @intCast((row + 1) * OUTER_MARGIN)))), .width = SIZE, .height = SIZE };

                ray.DrawRectangleRoundedLines(rectangle, 0.2, 0, ray.WHITE);
            }
        }

        for (0..ROWS) |row| {
            for (0..COLS) |col| {
                ray.DrawCircle(self.centers[row][col].x, self.centers[row][col].y, 2, ray.WHITE);
            }
        }
    }

    pub fn positionContainsCube(self: *const Self, row: usize, col: usize) bool {
        return self.cubes[row][col];
    }

    pub fn setCube(self: *Self, row: usize, col: usize) void {
        self.cubes[row][col] = true;
    }

    pub fn unsetCube(self: *Self, row: usize, col: usize) void {
        self.cubes[row][col] = false;
    }

    pub fn withinBounds(x: i32, y: i32) bool {
        return x > 0 and x < ROWS and y > 0 and y < COLS;
    }

    pub fn checkForCompletedRows(self: *Self) [ROWS]bool {
        var full_rows: [ROWS]bool = undefined;
        for (0..ROWS) |row| {
            full_rows[row] = for (0..COLS) |col| {
                if (!self.cubes[row][col]) break false;
            } else true;
        }

        for (0..ROWS) |row| {
            if (full_rows[row]) {
                for (0..COLS) |col| {
                    self.cubes[row][col] = false;
                }
            }
        }

        return full_rows;
    }
};

test "double switch" {
    const Food = enum { good, bad };
    const Price = enum { high, low };

    const g = Food.good;
    const h = Price.high;

    const value = switch (g) {
        Food.good => switch (h) {
            Price.high => 8,
            Price.low => 10,
        },
        Food.bad => switch (h) {
            Price.high => 1,
            Price.low => 5,
        },
    };
    _ = value;

    const arr = [4][2]i32{ [_]i32{ 0, 0 }, [_]i32{ 0, 0 }, [_]i32{ 0, 0 }, [_]i32{ 0, 0 } };
    _ = arr;
}
