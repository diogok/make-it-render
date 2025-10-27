pub const CreatedImage = struct {
    image_id: anywin.ImageID,
    image: anywin.Image,
};

pub const TextRenderer = struct {
    allocator: std.mem.Allocator,
    fonts: []const textz.common.Font,

    pub fn textToImage(self: *@This(), window: *anywin.Window, text: []const u8) !CreatedImage {
        const text_bits = try textz.text.render(self.allocator, self.fonts, text);
        defer text_bits.deinit();

        const text_pixels = try bitsToColor(
            self.allocator,
            .{ 255, 128, 0 },
            text_bits.bitmap,
        );
        defer self.allocator.free(text_pixels);

        const text_image = anywin.Image{
            .width = text_bits.width,
            .height = text_bits.height,
            .pixels = text_pixels,
        };

        const image_id = try window.createImage(text_image);

        return CreatedImage{
            .image_id = image_id,
            .image = text_image,
        };
    }
};

pub fn bitsToColor(
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

const anywin = @import("anywindow");
const textz = @import("textz");
