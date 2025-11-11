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

    timer.reset();

    const fonts = try getFonts(allocator);
    defer freeFonts(allocator, fonts);
    log.debug("Time to font: {d}ms", .{timer.lap() / std.time.ns_per_ms});

    var tiles = canvas.tiles.TileMap.init(allocator, .{ .height = 16, .width = 16 });
    defer tiles.deinit();

    // let's draw Welcomes
    for (welcome, 0..) |txt, i| {
        // get text bitmap
        const text = try textz.render(allocator, fonts, txt);
        defer text.deinit();

        // set to pixels in color
        const pixels = try make_it_render.glue.bitsToColor(
            allocator,
            .{ 255, 150, 0 },
            text.bitmap,
        );
        defer allocator.free(pixels);

        // create the image for each
        try tiles.setPixels(
            .{
                .height = text.height,
                .width = text.width,
                .x = 100,
                .y = 100 + (@as(u8, @truncate(i)) * 20),
            },
            pixels,
        );
    }

    log.debug("Time to tiles: {d}ms", .{timer.lap() / std.time.us_per_ms});

    // let's keep track of mouse position to draw it
    var mouse_x: anywin.X = 0;
    var mouse_y: anywin.Y = 0;
    var mouse_pos_img: ?anywin.Image = null;

    // show the window now that we have all ready
    try window.show();

    while (window.status == .open) {
        const event = try wm.receive();
        switch (event) {
            .close => {
                try window.destroy();
            },
            .draw => {
                timer.reset();
                try window.clear(.{});

                // draw each welcome message
                var tile_iter = tiles.iterator(null);
                while (tile_iter.next()) |tile| {
                    const img = try window.createImage(
                        .{
                            .height = tile.bbox.height,
                            .width = tile.bbox.width,
                        },
                        tile.pixels,
                    );
                    try img.draw(.{
                        .x = tile.bbox.x,
                        .y = tile.bbox.x,
                        .height = tile.bbox.height,
                        .width = tile.bbox.width,
                    });
                    try img.deinit();
                }

                // draw mouse position
                if (mouse_pos_img) |img| {
                    const target = anywin.BBox{
                        .x = mouse_x - 20,
                        .y = mouse_y - 20,
                        .height = img.size.height,
                        .width = img.size.width,
                    };
                    try img.draw(target);
                }

                try wm.flush();

                log.debug("Time to draw: {d}ms", .{timer.lap() / std.time.us_per_ms});
            },
            .mouse_pressed, .mouse_released, .key_pressed, .key_released => {
                log.debug("{any}", .{event});
            },
            .mouse_moved => |move| {
                mouse_x = move.x;
                mouse_y = move.y;

                if (mouse_pos_img) |img| {
                    try img.deinit();
                }

                // fmt text
                const mouse_pos_txt = try std.fmt.allocPrint(allocator, "{d}x{d}", .{ mouse_x, mouse_y });
                defer allocator.free(mouse_pos_txt);

                // render text
                const mouse_pos_bitmap = try textz.render(allocator, fonts, mouse_pos_txt);
                defer mouse_pos_bitmap.deinit();

                // create pixels in color
                const mouse_pos_pixels = try make_it_render.glue.bitsToColor(
                    allocator,
                    .{ 255, 150, 0 },
                    mouse_pos_bitmap.bitmap,
                );
                defer allocator.free(mouse_pos_pixels);

                // update the image
                mouse_pos_img = try window.createImage(
                    .{
                        .height = mouse_pos_bitmap.height,
                        .width = mouse_pos_bitmap.width,
                    },
                    mouse_pos_pixels,
                );

                // ask to redraw everything
                try window.redraw(.{});
                try wm.flush();
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

const std = @import("std");
const make_it_render = @import("make_it_render");

const anywin = make_it_render.anywindow;
const textz = make_it_render.textz;
const canvas = make_it_render.canvas;

const log = std.log.scoped(.demo);

pub const std_options: std.Options = .{
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .x11, .level = .warn },
        .{ .scope = .demo, .level = .debug },
    },
};
