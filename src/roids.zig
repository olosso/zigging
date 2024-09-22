const std = @import("std");
const testing = std.testing;
const ray = @import("raylib.zig");
const math = @import("math.zig");
const consts = @import("constants.zig");
const P = @import("constants.zig").P;

const c = @cImport(@cInclude("stdio.h"));

pub fn play_roids() !void {
    // const monitor = ray.GetCurrentMonitor();
    // const width = ray.GetMonitorWidth(monitor);
    // const height = ray.GetMonitorHeight(monitor);

    ray.SetConfigFlags(ray.FLAG_MSAA_4X_HINT | ray.FLAG_VSYNC_HINT);
    ray.InitWindow(consts.WIDTH, consts.HEIGTH, "zig raylib example");
    defer ray.CloseWindow();
    _ = c.printf("Hello from C\n");

    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 8 }){};
    const gpa_allocator = gpa.allocator();
    defer {
        switch (gpa.deinit()) {
            .leak => @panic("leaked memory"),
            else => {},
        }
    }
    // var gpa2 = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 8 }){};
    // const allocator2 = gpa2.allocator();
    // defer {
    //     switch (gpa2.deinit()) {
    //         .leak => @panic("leaked memory"),
    //         else => {},
    //     }
    // }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    _ = arena_allocator;

    var ship = Ship(P).init();

    //var bullets = try std.ArrayList(Bullet).initCapacity(arena_allocator, 1000);
    //defer bullets.deinit();
    var bullets = try gpa_allocator.alloc(Bullet, 400);
    defer gpa_allocator.free(bullets);
    for (0..bullets.len) |i| {
        bullets[i] = Bullet.create();
    }

    var asteroids = std.ArrayList(Asteroid(P)).init(gpa_allocator);
    defer asteroids.deinit();

    try asteroids.append(Asteroid(P).init(1));
    try asteroids.append(Asteroid(P).init(2));
    try asteroids.append(Asteroid(P).init(3));
    try asteroids.append(Asteroid(P).init(4));

    var now = std.time.milliTimestamp();
    var prev: i64 = now;
    var asteroid_timer: i64 = 0;
    var bullet_timer: i64 = 0;
    var bullet_counter: usize = 0;

    var rotation: f32 = 0.00;
    var acceleration: f32 = 0.00;
    var shoot: bool = false;
    var rotation_pressed = false;

    while (!ray.WindowShouldClose()) {
        // input
        // var delta: i2 = 0;

        rotation = 0.00;
        acceleration = 0.00;
        shoot = false;
        rotation_pressed = false;

        // if (ray.IsKeyPressed(ray.KEY_UP)) rotation += 0.01;
        if (ray.IsKeyDown(ray.KEY_W)) acceleration = 0.030;
        if (ray.IsKeyDown(ray.KEY_S)) acceleration = -0.0175;
        if (ray.IsKeyDown(ray.KEY_D)) {
            rotation = 0.001;
            rotation_pressed = true;
        }
        if (ray.IsKeyDown(ray.KEY_A)) {
            rotation = -0.001;
            rotation_pressed = true;
        }
        if (ray.IsKeyDown(ray.KEY_J)) {
            if (!bullets[bullet_counter].is_initialized) {
                bullets[bullet_counter].init(ship.position, ship.direction);
            } else {
                bullets[bullet_counter].reset();
                bullets[bullet_counter].setTransform(ship.position, ship.direction);
            }
            bullet_counter = (bullet_counter + 1) % bullets.len;
            shoot = true;
        }
        // if (delta != 0) {
        //     current_color = @mod(current_color + delta, colors_len);
        //     hint = false;
        // }

        now = std.time.milliTimestamp();
        const delta_time = now - prev;
        prev = now;
        asteroid_timer += delta_time;
        bullet_timer += delta_time;

        // if (bullets.items.len > 0 and bullet_timer > 3000) {

        //     // Check which bullets are out of bounds.
        //     var i: usize = 0;
        //     while (i < bullets.items.len and bullets.items[i].oob) : (i += 1) {}

        //     // All bullets are out of bounds.
        //     if (i == bullets.items.len) {
        //         bullets.shrinkRetainingCapacity(0);
        //         std.debug.print("Clearing all bullets: {}", .{bullets.items.len});
        //     }
        // }

        // draw
        {
            ray.BeginDrawing();
            defer ray.EndDrawing();

            ray.ClearBackground(ray.BLACK);

            for (bullets) |*bullet| {
                if (!bullet.*.is_initialized or bullet.*.isOutOfBounds()) continue;
                for (asteroids.items) |*asteroid| {
                    if (asteroid.isOutOfBounds()) continue;
                    if (bullet.*.hit(asteroid)) {
                        asteroid.onHit(bullet.*.damage);
                    }
                }
            }

            ship.update(delta_time, acceleration, rotation, shoot);
            ship.draw();

            for (bullets) |*bullet| {
                if (!bullet.*.is_initialized) continue;
                bullet.*.update(delta_time);
                if (!bullet.*.isOutOfBounds()) bullet.*.draw();
            }
            for (0..asteroids.items.len) |i| {
                asteroids.items[i].update(delta_time);
                asteroids.items[i].draw();
            }
            if (asteroid_timer > 2000) {
                try asteroids.append(Asteroid(P).init(@as(u64, @intCast(std.time.milliTimestamp()))));
                asteroid_timer = 0;
            }

            // now lets use an allocator to create some dynamic text
            // pay attention to the Z in `allocPrintZ` that is a convention
            // for functions that return zero terminated strings
            const seconds: u32 = @intFromFloat(ray.GetTime());
            const dynamic = try std.fmt.allocPrintZ(gpa_allocator, "running since {d} seconds", .{seconds});
            defer gpa_allocator.free(dynamic);
            ray.DrawText(dynamic, 300, 250, 20, ray.WHITE);
            ray.DrawText("Zero", 0, 0, 20, ray.RED);
            ray.DrawText("Max", consts.WIDTH - 25, consts.HEIGTH - 25, 20, ray.RED);

            const rot_speed = try std.fmt.allocPrintZ(gpa_allocator, "RotationSpeed {d}", .{ship.angular_momentum});
            defer gpa_allocator.free(rot_speed);
            ray.DrawText(rot_speed, consts.WIDTH - 300, consts.HEIGTH - 50, 20, ray.RED);
            const velocity = try std.fmt.allocPrintZ(gpa_allocator, "Speed {d}", .{ship.velocity.norm()});
            defer gpa_allocator.free(velocity);
            ray.DrawText(velocity, consts.WIDTH - 300, consts.HEIGTH - 100, 20, ray.RED);
            const fired = try std.fmt.allocPrintZ(gpa_allocator, "Bullets {d}", .{bullet_counter});
            defer gpa_allocator.free(fired);
            ray.DrawText(fired, consts.WIDTH - 150, consts.HEIGTH - 100, 20, ray.RED);

            ray.DrawFPS(consts.WIDTH - 100, 10);
        }
    }
}

pub fn Ship(comptime T: type) type {
    return struct {
        const Self = @This();

        position: math.Point(T),
        direction: math.Vec2(T),
        velocity: math.Vec2(T),
        color: u32 = 0x00_00_ff_ff,

        inertia: T = 0.995,
        angular_momentum: T = 0,

        color_timer: i64 = 0,

        pub fn init() Self {
            const position = math.CENTER;
            const direction = math.Vec2(T).new(0, -1);

            return Self{
                .position = position,
                .direction = direction,
                .velocity = math.Vec2(T).new(0, 0),
            };
        }

        pub fn update(self: *Self, delta_time: i64, acceleration: T, rotation: T, shoot: bool) void {
            self.color_timer += delta_time;
            self.accelerate(acceleration);
            self.rotate(rotation);

            if (shoot) {
                const res = @addWithOverflow(self.color, 0x01_00_00_00 - 0x00_00_01_00);
                self.color = if (res[1] == 1) 0xff_00_00_ff else res[0];
            } else if (self.color_timer > 10 and self.color > 0x00_00_ff_ff) {
                self.color = @max(self.color - 0x01_00_00_00 + 0x00_00_01_00, 0x00_00_ff_ff);
                self.color_timer = 0;
            }

            self.position = self.position.addVector(&self.velocity);
            if (self.position.isOutOfBoundsMargin(30)) |bounds| {
                const displacement = switch (bounds) {
                    consts.OutOfBounds.up => math.Vec2(T).new(0, consts.HEIGTH),
                    consts.OutOfBounds.down => math.Vec2(T).new(0, -consts.HEIGTH),
                    consts.OutOfBounds.left => math.Vec2(T).new(consts.WIDTH, 0),
                    consts.OutOfBounds.right => math.Vec2(T).new(-consts.WIDTH, 0),
                };
                self.position = self.position.addVector(&displacement);
            }
        }

        pub fn accelerate(self: *Self, acceleration: T) void {
            const acceleration_vec = self.direction.scale(acceleration);
            self.velocity = self.velocity.add(&acceleration_vec);

            const max_speed = 30;
            if (self.velocity.norm() > max_speed) {
                self.velocity = self.velocity.normalize().scale(max_speed);
            }

            if (self.velocity.norm() > 0.0005) {
                self.velocity = self.velocity.scale(self.inertia);
            }
        }

        pub fn rotate(self: *Self, radians: T) void {
            self.angular_momentum = @max(@min(self.angular_momentum + radians, std.math.pi * 0.01), -std.math.pi * 0.01);

            if (@abs(self.angular_momentum) > 0.0005) {
                self.angular_momentum *= self.inertia;
            }

            self.direction = self.direction.rotate(self.angular_momentum);
        }

        pub fn draw(self: *const Self) void {
            const center_x = @as(i32, @intFromFloat(self.position.x));
            const center_y = @as(i32, @intFromFloat(self.position.y));
            //ray.DrawCircle(center_x, center_y, 5, ray.WHITE);

            const back = self.position.addVector(&self.direction.scale(-20));
            const bx_int = @as(i32, @intFromFloat(back.x));
            const by_int = @as(i32, @intFromFloat(back.y));
            //ray.DrawCircle(bx_int, by_int, 5, ray.BLUE);
            ray.DrawLine(center_x, center_y, bx_int, by_int, ray.RED);

            const front = self.position.addVector(&self.direction.scale(50));
            const fx_int = @as(i32, @intFromFloat(front.x));
            const fy_int = @as(i32, @intFromFloat(front.y));
            //ray.DrawCircle(fx_int, fy_int, 5, ray.RED);
            ray.DrawLine(center_x, center_y, fx_int, fy_int, ray.GetColor(self.color));

            const backLeft = self.position.addVector(&(self.direction.scale(50)).rotate(0.75 * std.math.pi));
            const backRight = self.position.addVector(&(self.direction.scale(50)).rotate(-0.75 * std.math.pi));

            const blx_int = @as(i32, @intFromFloat(backLeft.x));
            const bly_int = @as(i32, @intFromFloat(backLeft.y));
            //ray.DrawCircle(blx_int, bly_int, 5, ray.RED);
            ray.DrawLine(center_x, center_y, blx_int, bly_int, ray.RED);

            const brx_int = @as(i32, @intFromFloat(backRight.x));
            const bry_int = @as(i32, @intFromFloat(backRight.y));
            //ray.DrawCircle(brx_int, bry_int, 5, ray.GREEN);
            ray.DrawLine(center_x, center_y, brx_int, bry_int, ray.RED);

            ray.DrawLine(fx_int, fy_int, blx_int, bly_int, ray.WHITE);
            ray.DrawLine(blx_int, bly_int, bx_int, by_int, ray.WHITE);
            ray.DrawLine(bx_int, by_int, brx_int, bry_int, ray.WHITE);
            ray.DrawLine(brx_int, bry_int, fx_int, fy_int, ray.WHITE);
        }
    };
}

pub fn Asteroid(comptime T: type) type {
    return struct {
        const Self = @This();
        const Size = enum { small, medium, big };

        position: math.Point(T),
        velocity: math.Vec2(T),
        vertices: [8]math.Vec2(T),
        angular_momentum: T,
        radius: T,

        hp: i16,
        destroyed: bool = false,
        oob: bool = false,
        color: u32 = 0xff_ff_ff_ff,

        total_time: i64 = 0,

        pub fn init(seed: u64) Self {
            var prng = std.Random.DefaultPrng.init(seed);
            const rng = prng.random();

            const size: Size = switch (rng.uintLessThan(u8, 100)) {
                0...32 => Size.small,
                33...65 => Size.medium,
                else => Size.big,
            };

            const scale: T = switch (size) {
                Size.small => 40,
                Size.medium => 80,
                Size.big => 120,
            };

            var vertices = [8]math.Vec2(T){
                math.Vec2(T){ .x = rng.float(T), .y = rng.float(T) },
                math.Vec2(T){ .x = 0, .y = rng.float(T) },
                math.Vec2(T){ .x = -rng.float(T), .y = rng.float(T) },
                math.Vec2(T){ .x = -rng.float(T), .y = 0 },
                math.Vec2(T){ .x = -rng.float(T), .y = -rng.float(T) },
                math.Vec2(T){ .x = 0, .y = -rng.float(T) },
                math.Vec2(T){ .x = rng.float(T), .y = -rng.float(T) },
                math.Vec2(T){ .x = rng.float(T), .y = 0 },
            };

            var norms: [8]T = undefined;
            for (0..vertices.len) |i| {
                vertices[i] = vertices[i].scale(scale);
                norms[i] = vertices[i].norm();
            }

            const radius = 0.8 * std.sort.max(T, &norms, {}, std.sort.asc(T)).?;

            const position: math.Point(T) = switch (rng.enumValue(consts.OutOfBounds)) {
                consts.OutOfBounds.up => math.Point(T){ .x = rng.float(T) * consts.WIDTH, .y = -100 },
                consts.OutOfBounds.down => math.Point(T){ .x = rng.float(T) * consts.WIDTH, .y = consts.HEIGTH + 100 },
                consts.OutOfBounds.left => math.Point(T){ .x = -100, .y = rng.float(T) * consts.HEIGTH },
                consts.OutOfBounds.right => math.Point(T){ .x = consts.WIDTH + 100, .y = rng.float(T) * consts.HEIGTH },
            };

            var speed: T = undefined;
            var angular_momentum: T = undefined;
            var hp: u8 = undefined;
            switch (size) {
                Size.small => {
                    hp = 2;
                    speed = rng.float(T);
                    angular_momentum = rng.float(T) * 0.01;
                },
                Size.medium => {
                    hp = 3;
                    speed = rng.float(T) * 0.5;
                    angular_momentum = rng.float(T) * 0.005;
                },
                Size.big => {
                    hp = 4;
                    speed = rng.float(T) * 0.2;
                    angular_momentum = rng.float(T) * 0.001;
                },
            }

            const velocity = position.diff(&math.CENTER)
                .rotate(std.math.pi * 0.4 * (rng.float(T) - 1))
                .to_length(speed);

            return Self{ .position = position, .velocity = velocity, .vertices = vertices, .angular_momentum = angular_momentum, .radius = radius, .hp = hp };
        }

        pub fn update(self: *Self, delta_time: i64) void {
            if (!self.isActive()) return;
            self.oob = self.position.isOutOfBoundsMargin(150) != null;

            self.total_time += delta_time;

            self.position = self.position.addVector(&self.velocity);
            for (0..self.vertices.len) |i| {
                self.vertices[i] = self.vertices[i].rotate(self.angular_momentum);
            }

            if (self.total_time > 100) {
                if (self.color < 0xff_ff_ff_ff) {
                    self.color += 0x00_11_11_00;
                }
                self.total_time = 0;
            }
        }

        pub fn onHit(self: *Self, damage: u8) void {
            if (self.destroyed) return;

            self.hp -= damage;
            if (self.hp < 0) {
                self.destroyed = true;
                return;
            }

            self.color -= 0x00_77_77_00;
        }

        pub fn isActive(self: *const Self) bool {
            return !self.destroyed and !self.oob;
        }

        pub fn isOutOfBounds(self: *const Self) bool {
            return self.oob;
        }

        pub fn draw(self: *const Self) void {
            if (!self.isActive()) return;

            if (self.destroyed) return;

            var vertices: [8]math.Vec2(i32) = undefined;

            for (0..self.vertices.len) |i| {
                const shifted = self.vertices[i].add(&self.position.asVec());
                vertices[i] = math.Vec2(i32).new(@as(i32, @intFromFloat(shifted.x)), @as(i32, @intFromFloat(shifted.y)));
            }

            //const center_x = @as(i32, @intFromFloat(self.position.x));
            //const center_y = @as(i32, @intFromFloat(self.position.y));
            //ray.DrawCircle(center_x, center_y, 5, ray.WHITE);

            const color = ray.GetColor(self.color);
            ray.DrawLine(vertices[0].x, vertices[0].y, vertices[1].x, vertices[1].y, color);
            ray.DrawLine(vertices[1].x, vertices[1].y, vertices[2].x, vertices[2].y, color);
            ray.DrawLine(vertices[2].x, vertices[2].y, vertices[3].x, vertices[3].y, color);
            ray.DrawLine(vertices[3].x, vertices[3].y, vertices[4].x, vertices[4].y, color);
            ray.DrawLine(vertices[4].x, vertices[4].y, vertices[5].x, vertices[5].y, color);
            ray.DrawLine(vertices[5].x, vertices[5].y, vertices[6].x, vertices[6].y, color);
            ray.DrawLine(vertices[6].x, vertices[6].y, vertices[7].x, vertices[7].y, color);
            ray.DrawLine(vertices[7].x, vertices[7].y, vertices[0].x, vertices[0].y, color);
        }
    };
}

const Bullet = struct {
    const Self = @This();
    is_initialized: bool = false,

    position: math.Point(P),
    direction: math.Vec2(P),
    velocity: P = 2.5,
    oob: bool = false,

    color: u32 = 0xff_ff_ff_ff,
    total_time: i64 = 0,
    counter: u8 = 0,

    old: ?*Asteroid(P) = null,

    damage: u8 = 1,

    pub fn create() Self {
        return Self{
            .position = undefined,
            .direction = undefined,
        };
    }

    pub fn init(self: *Self, position: math.Point(P), direction: math.Vec2(P)) void {
        if (self.is_initialized) return;
        self.setTransform(position, direction);
        self.is_initialized = true;
    }

    pub fn setTransform(self: *Self, position: math.Point(P), direction: math.Vec2(P)) void {
        self.position = position.addVector(&direction.scale(50));
        self.direction = direction;
    }

    pub fn reset(self: *Self) void {
        self.velocity = 2.5;
        self.oob = false;
        self.color = 0xff_ff_ff_ff;
        self.total_time = 0;
        self.counter = 0;
        self.old = null;
        self.damage = 1;
    }

    pub fn update(self: *Self, delta_time: i64) void {
        self.oob = self.position.isOutOfBoundsMargin(50) != null;
        self.position = self.position.addVector(&self.direction.scale(self.velocity));
        self.total_time += delta_time;
        if (self.total_time > 200) {
            self.counter += 1;
            self.color = @max(self.color - 0x00_11_11_00, 0xff_00_00_ff);
            self.total_time = 0;
        }
        if (self.counter > 0 and self.counter % 4 == 1) {
            self.damage = @min(self.damage + 1, 3);
        }
        if (self.counter > 100) {
            self.counter = 0;
        }
    }

    pub fn draw(self: *const Self) void {
        if (self.oob) return;
        const x_int = @as(i32, @intFromFloat(self.position.x));
        const y_int = @as(i32, @intFromFloat(self.position.y));
        ray.DrawCircle(x_int, y_int, 5, ray.GetColor(self.color));
    }

    pub fn hit(self: *Self, new: *Asteroid(P)) bool {
        const distance = self.position.diff(&new.position).norm();
        const did_hit = distance < new.radius;

        if (did_hit) {
            if (self.old) |old| {
                if (old == new) {
                    return false;
                } else {
                    self.old = new;
                    return true;
                }
            } else {
                self.old = new;
                return true;
            }
        } else {
            return false;
        }
    }

    pub fn isOutOfBounds(self: *const Self) bool {
        return self.oob;
    }
};

// pub fn Bullet(comptime T: type) type {
//     return struct {
//         const Self = @This();
//         position: math.Point(T),
//         direction: math.Vec2(T),
//         velocity: T,

//         color: u32,
//         total_time: i64 = 0,
//         counter: u8 = 0,

//         old: ?*Asteroid(T) = null,

//         damage: u8 = 1,

//         pub fn init(position: math.Point(T), direction: math.Vec2(T)) Self {
//             return Self {
//                 .position = position.addVector(&direction.scale(50)),
//                 .direction = direction,
//                 .velocity = 2.5,
//                 .color = 0xff_ff_ff_ff,
//             };
//         }

//         pub fn update(self: *Self, delta_time: i64) void {
//             self.position = self.position.addVector(&self.direction.scale(self.velocity));
//             self.total_time += delta_time;
//             if(self.total_time > 200) {
//                 self.counter += 1;
//                 self.color = @max(self.color - 0x00_11_11_00, 0xff_00_00_ff);
//                 self.total_time = 0;
//             }
//             if(self.counter > 0 and self.counter % 4 == 1) {
//                 self.damage = @min(self.damage + 1, 3);
//             }
//             if(self.counter > 100) {
//                 self.counter = 0;
//             }
//         }

//         pub fn draw(self: *const Self) void {
//             const x_int = @as(i32, @intFromFloat(self.position.x));
//             const y_int = @as(i32, @intFromFloat(self.position.y));
//             ray.DrawCircle(x_int, y_int, 5, ray.GetColor(self.color));
//         }

//         pub fn hit(self: *Self, new: *Asteroid(T)) bool {
//             const distance = self.position.diff(&new.position).norm();
//             const did_hit = distance < new.radius;

//             if(did_hit) {
//                 if(self.old) |old| {
//                     if(old == new) {
//                         return false;
//                     } else {
//                         self.old = new;
//                         return true;
//                     }
//                 } else {
//                     self.old = new;
//                     return true;
//                 }
//             } else {
//                 return false;
//             }
//         }
//     };
// }
