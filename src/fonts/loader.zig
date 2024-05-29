const std = @import("std");
const format_common = @import("fomarts/common.zig");

pub const FontPattern = struct{
	family: []const u8,
	weight: []const u8='medium',
	size: usize,
	slant: u8='r',
	style: []const u8="",
	codes: []const u16=&[_]u16{},
}

pub const Loader = struct{
	fonts: ArrayList(*Font),

	pub fn init(allocator: std.mem.Allocator) !@This() {
		const fonts = try ArrayList(*Font).init(allocator);
		return Loader{
			.fonts=fonts,
		};
	}

	pub fn loadSystemFonts(self: *@This()) !void {

	}

	pub fn addFont(self: *@This(), font: *Font) !void {
		try self.fonts.append(font);
	}

	// TODO: load from file
	// TODO: load from bytes

	pub fn deinit(self: *@This()) void {
		self.fonts.deinit();
	}

	pub fn findFont(self: *@This(), pattern: FontPattern) ![]*Font{

	}
}
