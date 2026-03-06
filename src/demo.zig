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
    defer window.deinit();

    timer.reset();

    const fonts = try getFonts(allocator);
    defer freeFonts(allocator, fonts);
    log.debug("Time to load fonts: {d}ms", .{timer.lap() / std.time.ns_per_ms});

    var images: std.ArrayList(*anywin.Image) = .empty;
    defer {
        for (images.items) |img| {
            img.deinit();
            allocator.destroy(img);
        }
        images.deinit(allocator);
    }

    // let's draw Welcomes
    for (welcome, 0..) |txt, i| {
        var text = try textz.render(allocator, fonts, txt);
        defer text.deinit();

        const img = try allocator.create(anywin.Image);
        errdefer allocator.destroy(img);
        img.* = try anywin.Image.init(
            allocator,
            &window,
            .{
                .height = text.height,
                .width = text.width,
                .x = 100,
                .y = 100 + (@as(i16, @intCast(i)) * 20),
            },
        );
        errdefer img.deinit();

        const rgba = try text.toRgba(allocator, &[_]u8{ 255, 150, 0, 255 });
        defer allocator.free(rgba);
        try img.setPixels(rgba);
        try wm.flush();

        try images.append(allocator, img);
    }

    // render PBM image
    {
        var z_reader = std.Io.Reader.fixed(z);
        var bitmap = try make_it_render.image.parse(allocator, &z_reader);
        defer bitmap.deinit();

        const img = try allocator.create(anywin.Image);
        errdefer allocator.destroy(img);
        img.* = try anywin.Image.init(allocator, &window, .{
            .width = bitmap.width,
            .height = bitmap.height,
            .x = 50,
            .y = 120,
        });
        errdefer img.deinit();

        const rgba = try bitmap.toRgba(allocator, &[_]u8{ 255, 150, 0, 255 });
        defer allocator.free(rgba);
        try img.setPixels(rgba);
        try wm.flush();

        try images.append(allocator, img);
    }

    // mouse position overlay
    const mouse_img = try allocator.create(anywin.Image);
    defer {
        mouse_img.deinit();
        allocator.destroy(mouse_img);
    }
    {
        var sample = try textz.render(allocator, fonts, "    0x    0");
        defer sample.deinit();
        mouse_img.* = try anywin.Image.init(allocator, &window, .{
            .x = 0,
            .y = 0,
            .height = sample.height,
            .width = sample.width,
        });
    }

    // set window icon from PBM z image
    {
        var z_reader = std.Io.Reader.fixed(z);
        var icon_bitmap = try make_it_render.image.parse(allocator, &z_reader);
        defer icon_bitmap.deinit();

        const icon_pixels = try icon_bitmap.toRgba(allocator, &[_]u8{ 255, 150, 0, 255 });
        defer allocator.free(icon_pixels);

        try window.setIcon(.{
            .width = icon_bitmap.width,
            .height = icon_bitmap.height,
            .pixels = icon_pixels,
        });
    }

    // sync any pending operation
    try wm.flush();

    log.debug("Time to initial render: {d}ms", .{timer.lap() / std.time.ns_per_ms});

    // show the window now that we have all ready
    try window.show();

    var window_source: anywin.EventSource = .{ .wm = &wm };
    var ev_loop = eventLoop(.{ .window = &window_source });
    defer ev_loop.deinit();
    try ev_loop.start();

    while (ev_loop.receive()) |wrapped| {
        switch (wrapped) {
            .window => |event| switch (event) {
                .close => {
                    window.close();
                    ev_loop.stop();
                },
                .draw => {
                    timer.reset();

                    try window.beginDraw();
                    try window.clear(.{});
                    for (images.items) |img| try img.draw();
                    try mouse_img.draw();
                    try window.endDraw();

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
                    const mouse_pos_txt = try std.fmt.allocPrint(allocator, "{d:5}x{d:5}", .{ move.x, move.y });
                    defer allocator.free(mouse_pos_txt);

                    var bmp = try textz.render(allocator, fonts, mouse_pos_txt);
                    defer bmp.deinit();

                    const rgba = try bmp.toRgba(allocator, &[_]u8{ 255, 150, 0, 255 });
                    defer allocator.free(rgba);
                    try mouse_img.setPixels(rgba);
                    try wm.flush();

                    mouse_img.setX(move.x);
                    mouse_img.setY(move.y);

                    try window.redraw(.{});
                },
                else => {},
            },
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
const eventLoop = make_it_render.loop.eventLoop;

const log = std.log.scoped(.demo);

pub const std_options: std.Options = .{
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .x11, .level = .warn },
        .{ .scope = .demo, .level = .debug },
    },
};
