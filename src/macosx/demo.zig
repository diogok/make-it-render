const std = @import("std");
const mac = @import("mac.zig");

const log = std.log.scoped(.main);

pub fn main() !void {
    log.info("Hello, Mac!", .{});

    var lib = try mac.load();

    const app = lib.msgSend_ID(lib.getClass("NSApplication"), lib.registerName("sharedApplication")) orelse return error.FailedToLoadApplication;
    const policySet = lib.msgSend_Int_Bool(app, lib.registerName("setActivationPolicy:"), @intFromEnum(mac.ApplicationActivationPolicy.Regular));
    if (!policySet) {
        return error.FailToSetActivationPolicy;
    }

    const windowAlloc = lib.msgSend_ID(lib.getClass("NSWindow"), lib.registerName("alloc")) orelse return error.FailedToAllocateWindow;
    const window = lib.msgSend_WindowInit_ID(
        windowAlloc,
        lib.registerName("initWithContentRect:styleMask:backing:defer:"),
        .{ .x = 0.0, .y = 0.0, .w = 200, .h = 200 },
        @intFromEnum(mac.WindowStyleMask.Default),
        @intFromEnum(mac.BackingStoreType.Buffered),
        false,
    ) orelse return error.FailedToInitWindow;

    const title = lib.msgSend_String_ID(lib.getClass("NSString"), lib.registerName("stringWithUTF8String:"), "Hello world") orelse return error.FailedToCreateTitle;
    lib.msgSend_ID_Void(window, lib.registerName("setTitle:"), title);
    lib.msgSend_ID_Void(window, lib.registerName("makeKeyAndOrderFront:"), null);

    lib.msgSend_Bool_Void(app, lib.registerName("activateIgnoringOtherApps:"), true);

    lib.msgSend_Void(app, lib.registerName("run"));
}
