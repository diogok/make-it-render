pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    var timer = try std.time.Timer.start();

    var wm = try anywin.WindowManager.init(allocator);
    defer wm.deinit();

    var window = try wm.createWindow(
        .{
            .title = "hello, world.",
        },
    );

    log.debug("Time to window: {d}ms", .{timer.lap() / std.time.ns_per_ms});

    const terminus = try textz.terminus.terminus(allocator, .@"16", .n);
    defer terminus.deinit();
    const unifont = try textz.unifont.unifont(allocator);
    defer unifont.deinit();
    const unifont_jp = try textz.unifont.unifont_jp(allocator);
    defer unifont_jp.deinit();

    const text = try textz.text.render(allocator, &[_]textz.common.Font{ terminus, unifont, unifont_jp }, "Hello, world!");
    defer text.deinit();

    log.debug("Time to font: {d}ms", .{timer.lap() / std.time.ns_per_ms});

    const text_pixels = try anywin.fns.bitsToColor(
        allocator,
        .{ 255, 128, 0 },
        text.bitmap,
    );
    defer allocator.free(text_pixels);

    const text_image = anywin.Image{
        .width = text.width,
        .height = text.height,
        .pixels = text_pixels,
    };

    const image_id = try window.createImage(text_image);

    log.debug("Time to image: {d}ms", .{timer.lap() / std.time.us_per_ms});

    try window.show();
    while (window.status == .open) {
        const event = try wm.receive();
        switch (event) {
            .close => {
                try window.destroy();
            },
            .draw => {
                timer.reset();
                const target = anywin.BBox{
                    .x = 100,
                    .y = 100,
                    .height = text_image.height,
                    .width = text_image.width,
                };
                try window.draw(image_id, target);
                log.debug("Time to draw: {d}ms", .{timer.lap() / std.time.us_per_ms});
            },
            .mouse_pressed, .mouse_released, .key_pressed, .key_released => {
                log.debug("{any}", .{event});
            },
            else => {},
        }
    }
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
