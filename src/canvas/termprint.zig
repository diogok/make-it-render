const std = @import("std");

pub fn print(buffer: [][4]u8, width: usize, height: usize) !void {
    const out = std.io.getStdOut();
    const writer = out.writer();

    enable(out) catch return; // silently fail if not supported

    var x: usize = 0;
    var y: usize = 0;
    while (y < height) : (y += 1) {
        while (x < width) : (x += 1) {
            const p = y * width + x;
            const c = buffer[p];
            if (c[3] == 1) {
                try setBackground(writer, c[0], c[1], c[2]);
                try setForeground(writer, c[0], c[1], c[2]);
            }
            try writer.print("\x2002", .{});
            try reset(writer);
        }
        x = 0;
        try newLine(writer);
    }
}

fn setForeground(writer: anytype, r: u8, g: u8, b: u8) !void {
    try writer.print("\x1b[38;2;{d};{d};{d}m", .{ r, g, b });
}

fn setBackground(writer: anytype, r: u8, g: u8, b: u8) !void {
    try writer.print("\x1b[48;2;{d};{d};{d}m", .{ r, g, b });
}

fn reset(writer: anytype) !void {
    try writer.print("\x1b[m", .{});
}

fn newLine(writer: anytype) !void {
    try writer.print("\r\n", .{}); // TODO: CRLF is OK?
}

fn enable(out: anytype) !void {
    if (!out.supportsAnsiEscapeCodes()) {
        return error.AnsiEscapeCodesNotSupported;
    }
    if (!out.isTty()) {
        return error.NotTTY;
    }
    // TODO: check env vars if available for color support
    // TODO: https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences#example-of-enabling-virtual-terminal-processing
    if (@import("builtin").os.tag == .windows) {}
    return;
}

test {
    const w = [4]u8{ 0, 0, 0, 1 };
    const b = [4]u8{ 255, 255, 255, 1 };
    const r = [4]u8{ 255, 0, 0, 1 };
    //const g = [4]u8{0,255,0,1};
    //const b = [4]u8{0,0,255,1};

    var buffer = [_][4]u8{
        b, b, b, b, b,
        b, r, r, r, b,
        b, r, w, r, b,
        b, r, r, r, b,
        b, b, b, b, b,
    };

    std.debug.print("\n", .{}); //to clear output before
    try print(&buffer, 5, 5);
}
