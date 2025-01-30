const std = @import("std");
const win = @import("anywindow");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() != .leak);
    const allocator = gpa.allocator();

    var wm = try win.WM.init(allocator);
    defer wm.deinit();

    var window = try wm.createWindow(
        .{
            .title = "hello, world.",
        },
    );

    var yellow_block: [5 * 5 * 4]u8 = undefined;
    var byte_index: usize = 0;
    while (byte_index < yellow_block.len) : (byte_index += 4) {
        yellow_block[byte_index] = 255; // red
        yellow_block[byte_index + 1] = 150; // green
        yellow_block[byte_index + 2] = 0; // blue
        yellow_block[byte_index + 3] = 0; // padding
    }
    const image = win.Image{
        .height = 5,
        .width = 5,
        .pixels = &yellow_block,
    };

    const image_id = try window.createImage(image);

    while (window.status == .open) {
        const event = try wm.receive();
        switch (event) {
            .close => {
                try window.destroy();
            },
            .draw => {
                const target = win.BBox{
                    .x = 100,
                    .y = 100,
                    .height = 5,
                    .width = 5,
                };
                try window.draw(image_id, target);
            },
            else => {},
        }
    }
}
