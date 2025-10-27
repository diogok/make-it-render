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

    timer.reset();

    const terminus = try textz.terminus.terminus(allocator, .@"16", .n);
    defer terminus.deinit();
    const unifont = try textz.unifont.unifont(allocator);
    defer unifont.deinit();
    const unifont_jp = try textz.unifont.unifont_jp(allocator);
    defer unifont_jp.deinit();

    log.debug("Time to font: {d}ms", .{timer.lap() / std.time.ns_per_ms});

    var text_renderer = make_it_render.TextRenderer{ .fonts = &[_]textz.common.Font{ terminus, unifont, unifont_jp }, .allocator = allocator };

    var welcome_texts: [welcome.len]make_it_render.CreatedImage = undefined;
    for (welcome, 0..) |txt, idx| {
        welcome_texts[idx] = try text_renderer.textToImage(&window, txt);
    }

    var mouse_x: anywin.X = 0;
    var mouse_y: anywin.Y = 0;

    try window.show();
    while (window.status == .open) {
        const event = try wm.receive();
        switch (event) {
            .close => {
                try window.destroy();
            },
            .draw => {
                timer.reset();

                for (welcome_texts, 0..) |txt, i| {
                    const target = anywin.BBox{
                        .x = 100,
                        .y = 100 + (@as(u8, @truncate(i)) * 20),
                        .height = txt.image.height,
                        .width = txt.image.width,
                    };
                    try window.draw(txt.image_id, target);
                }

                {
                    const mouse_pos_txt = try std.fmt.allocPrint(allocator, "{d}x{d}", .{ mouse_x, mouse_y });
                    defer allocator.free(mouse_pos_txt);
                    const mouse_pos_img = try text_renderer.textToImage(&window, mouse_pos_txt);
                    // TODO: defer destroy image?
                    const target = anywin.BBox{
                        .x = mouse_x - 20,
                        .y = mouse_y - 20,
                        .height = mouse_pos_img.image.height,
                        .width = mouse_pos_img.image.width,
                    };
                    try window.draw(mouse_pos_img.image_id, target);
                }

                log.debug("Time to draw: {d}ms", .{timer.lap() / std.time.us_per_ms});
            },
            .mouse_pressed, .mouse_released, .key_pressed, .key_released => {
                log.debug("{any}", .{event});
            },
            .mouse_moved => |move| {
                mouse_x = move.x;
                mouse_y = move.y;
                try window.redraw();
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

const log = std.log.scoped(.demo);

pub const std_options: std.Options = .{
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .x11, .level = .warn },
    },
};
