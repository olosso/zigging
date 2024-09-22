const std = @import("std");
const consts = @import("constants.zig");
const testing = std.testing;


pub const CENTER = Point(consts.P){ .x = consts.WIDTH / 2, .y = consts.HEIGTH / 2 };
pub fn Point(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,

        pub fn isOutOfBounds(self: *const Self) ?consts.OutOfBounds {
            if(self.x < 0) return consts.OutOfBounds.left;
            if(self.y < 0) return consts.OutOfBounds.up;
            if(self.x > consts.WIDTH) return consts.OutOfBounds.right;
            if(self.y > consts.HEIGTH) return consts.OutOfBounds.down;
            return null;
        }

        pub fn isOutOfBoundsMargin(self: *const Self, margin: u32) ?consts.OutOfBounds {
            const m = @as(f32, @floatFromInt(margin));
            if(self.x < -m) return consts.OutOfBounds.left;
            if(self.y < -m) return consts.OutOfBounds.up;
            if(self.x > consts.WIDTH + m) return consts.OutOfBounds.right;
            if(self.y > consts.HEIGTH + m) return consts.OutOfBounds.down;
            return null;
        }


        pub fn addVector(self: *const Self, vec: *const Vec2(T)) Self {
            return Self{ .x = self.x + vec.x, .y = self.y + vec.y };
        }

        pub fn diff(self: *const Self, other: *const Self) Vec2(T) {
            return Vec2(T).new(other.x - self.x, other.y - self.y);
        }

        pub fn asVec(self: *const Self) Vec2(T) {
            return Vec2(T){ .x = self.x, .y = self.y };
        }
    };
}


pub fn Vec2(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,

        pub fn new(x: T, y: T) Self {

            return Self {
                .x = x,
                .y = y,
            };
        }

        pub fn normalize(self: *const Self) Self {
            const length = self.norm();
            const x = self.x / length;
            const y = self.y / length;

            return Self {
                .x = x,
                .y = y,
            };
        }

        pub fn direction(self: *const Self) Self {
            const length = self.norm();
            return Self {
                .x = self.x / length,
                .y = self.x / length,
            };
        }

        pub fn scale(self: *const Self, factor: T) Self {
            return Vec2(T).new(
                factor * self.x,
                factor * self.y,
            );
        }

        pub fn rotate(self: *const Self, radians: T) Self {
            return Vec2(T).new(
                @cos(radians) * self.x - @sin(radians) * self.y,
                @sin(radians) * self.x + @cos(radians) * self.y,
            );
        }

        pub fn norm(self: *const Self) T {
            return std.math.sqrt(std.math.pow(T, self.x, 2) + std.math.pow(T, self.y, 2));
        }

        pub fn to_length(self: *const Self, length: T) Self {
            return self.normalize().scale(length);
        }

        pub fn add(self: *const Self, other: *const Self) Self {
            return Vec2(T).new(
                self.x + other.x,
                self.y + other.y,
            );
        }
    };
}

test "vec" {
    var v = Vec2(f32).new(3, 3);
    const T = f32;
    try testing.expect(std.math.approxEqRel(@typeInfo(@TypeOf(v)).@"struct".fields[0].type, v.length, v.norm(), std.math.floatEps(T)));

    var normalized = v.normalize();
    try testing.expect(std.math.approxEqRel(T, 1, normalized.norm(), std.math.floatEps(T)));
}
