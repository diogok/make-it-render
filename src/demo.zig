pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    var wm = try anywin.WindowManager.init(allocator);
    defer wm.deinit();

    var window = try wm.createWindow(
        .{
            .title = "hello, world.",
        },
    );

    const unifont = try textz.unifont.unifont(allocator);
    defer unifont.deinit();

    const text = try textz.text.render(allocator, &[_]textz.common.Font{unifont}, "Hello, world!");
    defer text.deinit();

    const text_pixels = try bitsToColor(
        allocator,
        .{ 255, 128, 0 },
        text.bitmap,
    );
    defer allocator.free(text_pixels);
    std.debug.print("pixels: {any}\n", .{text_pixels});

    const text_image = anywin.Image{
        .width = text.width,
        .height = text.height,
        .pixels = text_pixels,
    };

    const image_id = try window.createImage(text_image);

    while (window.status == .open) {
        const event = try wm.receive();
        switch (event) {
            .close => {
                try window.destroy();
            },
            .draw => {
                const target = anywin.BBox{
                    .x = 100,
                    .y = 100,
                    .height = text_image.height,
                    .width = text_image.width,
                };
                try window.draw(image_id, target);
            },
            .mouse_pressed, .mouse_released, .key_pressed, .key_released => {
                log.debug("{any}", .{event});
            },
            else => {},
        }
    }
}

fn bitsToColor(
    allocator: std.mem.Allocator,
    color: [3]u8,
    bits: []const u1,
) ![]u8 {
    const pixels = try allocator.alloc(u8, bits.len * 4);
    var pos: usize = 0;
    for (bits) |bit| {
        if (bit == 1) {
            pixels[pos] = color[0];
            pixels[pos + 1] = color[1];
            pixels[pos + 2] = color[2];
            pixels[pos + 3] = 1;
        } else {
            pixels[pos] = 0;
            pixels[pos + 1] = 0;
            pixels[pos + 2] = 0;
            pixels[pos + 3] = 0;
        }
        pos += 4;
    }
    return pixels;
}

const std = @import("std");
const make_it_render = @import("make_it_render");

const anywin = make_it_render.anywindow;
const textz = make_it_render.textz;

const log = std.log.scoped(.demo);

pub const std_options: std.Options = .{
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .x11, .level = .warn },
    },
};
