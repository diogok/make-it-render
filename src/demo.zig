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

    const terminus = try textz.terminus.terminus(allocator, .@"16", .n);
    defer terminus.deinit();
    const unifont = try textz.unifont.unifont(allocator);
    defer unifont.deinit();
    const unifont_jp = try textz.unifont.unifont_jp(allocator);
    defer unifont_jp.deinit();

    // pick some fonts, it will fallback until it finds a matching glyph
    const fonts = &[_]textz.common.Font{ terminus, unifont, unifont_jp };

    log.debug("Time to font: {d}ms", .{timer.lap() / std.time.ns_per_ms});

    var tiles = canvas.tiles.TileMap.init(allocator, .{ .height = 256, .width = 256 });
    defer tiles.deinit();

    // let's draw Welcome in a few languages
    //var welcome_imgs: [welcome.len]anywin.Image = undefined;
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
                .size = .{
                    .height = text.height,
                    .width = text.width,
                },
                .origin = .{
                    .x = 100,
                    .y = 100 + (@as(u8, @truncate(i)) * 20),
                },
            },
            @alignCast(std.mem.bytesAsSlice(canvas.types.RGBA, pixels)),
        );
    }

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
                var tile_iter = tiles.areaIterator(canvas.bbox.BBox.empty);
                while (tile_iter.next()) |tile| {
                    const img = try window.createImage(
                        .{
                            .height = tile.area.size.height,
                            .width = tile.area.size.width,
                        },
                        &std.mem.toBytes(tile.pixels),
                    );
                    defer img.deinit() catch {};
                    const target = anywin.BBox{
                        .x = tile.area.origin.x,
                        .y = tile.area.origin.y,
                        .height = tile.area.size.height,
                        .width = tile.area.size.width,
                    };
                    try img.draw(target);
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
            },
            else => {},
        }
    }
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
