const std = @import("std");
const mac = @import("mac.zig");

const log = std.log.scoped(.main);

pub fn should_close(_: ?*mac.ID, _: ?*mac.Selector, _: ?*mac.ID) bool {
    log.debug("Should close!", .{});
    return false;
}

pub fn will_close(_: ?*mac.ID, _: ?*mac.Selector, _: ?*mac.ID) bool {
    log.debug("will close!", .{});
    return false;
}

pub fn should_terminate(_: ?*mac.ID, _: ?*mac.Selector, _: ?*mac.ID) bool {
    log.debug("Should terminate!", .{});
    return false;
}

pub fn finish_launch(_: ?*mac.ID, _: ?*mac.Selector, _: ?*mac.ID) bool {
    log.debug("Should finish_launch!", .{});
    return false;
}
pub fn main() !void {
    log.info("Hello, Mac!", .{});

    var lib = try mac.load();

    const app = lib.msgSend(lib.getClass("NSApplication"), lib.registerName("sharedApplication"));
    log.debug("sharedApplication", .{});
    if (app == null) {
        return error.FailedToLoadSharedApp;
    }

    const result = lib.msgSend_Int_Bool(app, lib.registerName("setActivationPolicy:"), @intFromEnum(mac.ApplicationActivationPolicy.Regular));
    log.debug("setActivationPolicy", .{});
    if (!result) {
        return error.FailToSetActivationPolicy;
    }

    //const AppDelegateClass = lib.allocateClassPair(lib.getClass("NSObject"), "AppDelegate", 0);
    //if (AppDelegateClass == null) {
    //    return error.FailedToAllocAppDelegateClass;
    //}
    //const AppDelegateProtocol = lib.getProtocol("NSApplicationDelegate");
    //if (AppDelegateProtocol == null) {
    //    return error.FailedToGetNSApplicationDelegateProtocol;
    //}
    //result = lib.addProtocol(AppDelegateClass, AppDelegateProtocol);
    //if (!result) {
    //    return error.FailToAddDelegateProtocol;
    //}
    //_ = lib.addMethod(AppDelegateClass, lib.registerName("applicationShouldTerminate:"), should_terminate, "c@:@");
    //_ = lib.addMethod(AppDelegateClass, lib.registerName("applicationDidFinishLaunching:"), finish_launch, "c@:@");
    //lib.registerClassPair(AppDelegateClass);

    //const AppDelegateAlloc = lib.msgSend(AppDelegateClass, lib.registerName("alloc"));
    //const appDelegate = lib.msgSend(AppDelegateAlloc, lib.registerName("init"));
    //_ = lib.msgSend_ID(app, lib.registerName("setDelegate:"), appDelegate);

    //_ = lib.msgSend(app, lib.registerName("finishLaunching"));

    const windowAlloc = lib.msgSend(lib.getClass("NSWindow"), lib.registerName("alloc"));
    if (windowAlloc == null) {
        return error.FailedToAllocWindow;
    }
    const window = lib.msgSend_Window(
        windowAlloc,
        lib.registerName("initWithContentRect:styleMask:backing:defer:"),
        .{ .x = 0.0, .y = 0.0, .w = 200, .h = 200 }, //lib.makeRect(10, 10, 480, 320),
        (1 << 0),
        2,
        false,
    );
    if (window == null) {
        return error.FailedToInitWindow;
    }
    log.debug("window", .{});
    lib.msgSend_UInt_Void(window.?, lib.registerName("setStyleMask:"), 1);
    //log.debug("style", .{});

    //const WindowDelegateClass = lib.allocateClassPair(lib.getClass("NSObject"), "WindowDelegate", 0);
    //log.debug("x", .{});
    //const WindowDelegateProtocol = lib.getProtocol("NSWindowDelegate");
    //_ = lib.addProtocol(WindowDelegateClass, WindowDelegateProtocol);
    //_ = lib.addMethod(WindowDelegateClass, lib.registerName("windowShouldClose:"), should_close, "c@:@");
    //_ = lib.addMethod(WindowDelegateClass, lib.registerName("windowWillClose:"), will_close, "c@:@");
    //lib.registerClassPair(WindowDelegateClass);

    //    const windowDelegateAlloc = lib.msgSend(WindowDelegateClass, lib.registerName("alloc"));
    //const windowDelegate = lib.msgSend(windowDelegateAlloc, lib.registerName("init"));

    //_ = lib.msgSend_ID(window, lib.registerName("setDelegate:"), windowDelegate);
    //log.debug("setDelegate", .{});

    //const ViewClass = lib.allocateClassPair(lib.getClass("NSView"), "AppView", 0);
    //lib.registerClassPair(ViewClass);
    //const viewAlloc = lib.msgSend(ViewClass, lib.registerName("alloc"));
    //const view = lib.msgSend(viewAlloc, lib.registerName("init"));
    //_ = lib.msgSend_ID(window, lib.registerName("setContentView:"), view);

    const title = lib.msgSend_String(lib.getClass("NSString"), lib.registerName("stringWithUTF8String:"), "Hello world");
    if (title == null) {
        return error.FailedToCreateTitle;
    }
    log.debug("title", .{});
    lib.msgSend_ID_Void(window.?, lib.registerName("setTitle:"), title.?);
    log.debug("setTitle", .{});

    lib.msgSend_Void(window.?, lib.registerName("makeKeyAndOrderFront:"), null);
    log.debug("makeKeyAndOrderFront", .{});
    //_ = lib.msgSend(window.?, lib.registerName("center"));
    //log.debug("center", .{});
    lib.msgSend_Bool_Void(app, lib.registerName("activateIgnoringOtherApps:"), true);
    log.debug("activateIgnoringOtherApps", .{});

    _ = lib.msgSend(app, lib.registerName("run"));
    log.debug("run", .{});

    //while (true) {
    //    const distantPast = lib.msgSend(lib.getClass("NSDateClass"), lib.registerName("distantPast"));
    //    log.debug("x", .{});
    //    const event = lib.msgSend_NextEvent(
    //        app,
    //        lib.registerName("nextEventMatchingMask:untilDate:inMode:dequeue:"),
    //        std.math.maxInt(c_uint),
    //        distantPast,
    //        lib.defaultRunLoopMode,
    //        true,
    //    );
    //    log.debug("x", .{});

    //    if (event) |evt| {
    //        log.debug("Event!", .{});
    //        _ = lib.msgSend_ID(app, lib.registerName("sendEvent"), evt);
    //        _ = lib.msgSend(app, lib.registerName("updateWindow"));
    //    } else {
    //        log.debug("No event...", .{});
    //    }

    //    std.time.sleep(100 * 1000 * 1000);
    //}
}
