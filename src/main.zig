const std = @import("std");
const play_asteroids = @import("roids.zig").play_roids;
const play_tetris = @import("setris.zig").play_sitres;

pub fn main() !void {
    try play_tetris();
}
