pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();
    //const allocator = std.heap.smp_allocator;

    var timer = try std.time.Timer.start();

    var wm = try anywin.WindowManager.init(allocator);
    defer wm.deinit();

    var window = try wm.createWindow(
        .{
            .title = "hello, world.",
        },
    );
    defer window.deinit();

    timer.reset();

    const fonts = try getFonts(allocator);
    defer freeFonts(allocator, fonts);
    log.debug("Time to load fonts: {d}ms", .{timer.lap() / std.time.ns_per_ms});

    var canvas = canvaz.Canvas.init(allocator, &window);
    defer canvas.deinit();

    // let's draw Welcomes
    for (welcome, 0..) |txt, i| {
        // get text bitmap
        var text = try textz.render(allocator, fonts, txt);
        defer text.deinit();

        var pixel_reader = try text.pixelReader(&[_]u8{ 255, 150, 0, 1 });
        defer pixel_reader.deinit();

        // create the image for each
        var img = try canvas.createImageScaled(
            .{
                .height = text.height,
                .width = text.width,
                .x = 100,
                .y = 100 + (@as(u8, @truncate(i)) * 20),
            },
        );
        try img.setPixels(&pixel_reader.interface);
        try wm.flush();
    }

    // render PBM image
    {
        var z_reader = std.Io.Reader.fixed(z);
        var bitmap = try make_it_render.image.parse(allocator,&z_reader );
        defer bitmap.deinit();

        var pixel_reader = try bitmap.pixelReader(&[_]u8{ 255, 150, 0, 1 });
        defer pixel_reader.deinit();

        var img = try canvas.createImageScaled(.{
            .width = bitmap.width,
            .height = bitmap.height,
            .x = 50,
            .y = 120,
        });
        try img.setPixels(&pixel_reader.interface);
        try wm.flush();
    }

    // render text to get size
    var mouse_pos_bitmap = try textz.render(allocator, fonts, "00000x00000");
    defer mouse_pos_bitmap.deinit();

    var mouse_pos_img = try canvas.createImageScaled(
        .{
            .x = 0,
            .y = 0,
            .height = mouse_pos_bitmap.height,
            .width = mouse_pos_bitmap.width,
        },
    );

    // set window icon from PBM z image
    {
        var z_reader = std.Io.Reader.fixed(z);
        var icon_bitmap = try make_it_render.image.parse(allocator,&z_reader);
        defer icon_bitmap.deinit();

        var icon_reader = try icon_bitmap.pixelReader(&[_]u8{ 255, 150, 0, 255 });
        defer icon_reader.deinit();

        try window.setIcon(.{
            .width = icon_bitmap.width,
            .height = icon_bitmap.height,
            .pixels = icon_reader.buffer,
        });
    }

    // sync any pending operation
    try wm.flush();

    log.debug("Time to initial canvas: {d}ms", .{timer.lap() / std.time.ns_per_ms});

    // show the window now that we have all ready
    try window.show();

    while (window.status == .open) {
        const event = try wm.receive();
        switch (event) {
            .close => {
                window.close();
            },
            .draw => {
                timer.reset();

                try canvas.draw();

                log.debug("Time to draw: {d}ms", .{timer.lap() / std.time.ns_per_ms});
            },
            .key_pressed => |key_event| {
                if (key_event.key == .f) {
                    window.toggleFullscreen();
                    try window.redraw(.{});
                }
                log.debug("{any}", .{event});
            },
            .mouse_pressed, .mouse_released, .key_released => {
                log.debug("{any}", .{event});
            },
            .mouse_moved => |move| {
                // fmt text
                const mouse_pos_txt2 = try std.fmt.allocPrint(allocator, "{d:5}x{d:5}", .{ move.x, move.y });
                defer allocator.free(mouse_pos_txt2);

                // render text
                var mouse_pos_bitmap2 = try textz.render(allocator, fonts, mouse_pos_txt2);
                defer mouse_pos_bitmap2.deinit();

                var pixel_reader2 = try mouse_pos_bitmap2.pixelReader(&[_]u8{ 255, 150, 0, 1 });
                defer pixel_reader2.deinit();

                try mouse_pos_img.setPixels(&pixel_reader2.interface);
                try wm.flush();

                mouse_pos_img.dst_bbox.x = move.x;
                mouse_pos_img.dst_bbox.y = move.y;

                // ask to redraw everything
                try window.redraw(.{});
            },
            else => {},
        }
    }
}

fn getFonts(allocator: std.mem.Allocator) ![]const textz.common.Font {
    const terminus = try textz.terminus.terminus(allocator, .@"16", .n);
    const unifont = try textz.unifont.unifont(allocator);
    const unifont_jp = try textz.unifont.unifont_jp(allocator);

    const fonts = try allocator.alloc(textz.common.Font, 3);
    fonts[0] = terminus;
    fonts[1] = unifont;
    fonts[2] = unifont_jp;

    return fonts;
}

fn freeFonts(allocator: std.mem.Allocator, fonts: []const textz.common.Font) void {
    for (fonts) |font| {
        font.deinit();
    }
    allocator.free(fonts);
}

const welcome = [_][]const u8{
    "Welcome",
    "Bem vinda",
    "καλως ΗΡΘΑΤΕ",
    "أهلا بك",
    "欢迎",
    "ようこそ",
    "Emojis 😀😺",
    "café",
    // TODO: LTR,
};

const z = @embedFile("image/src/demo.pbm");

const std = @import("std");
const make_it_render = @import("make_it_render");

const anywin = make_it_render.anywindow;
const textz = make_it_render.text;
const canvaz = make_it_render.canvas;

const log = std.log.scoped(.demo);

pub const std_options: std.Options = .{
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .x11, .level = .warn },
        .{ .scope = .demo, .level = .debug },
    },
};
