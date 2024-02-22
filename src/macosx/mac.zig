const std = @import("std");

pub const ID = anyopaque;
pub const Class = ID;
pub const Selector = ID;
pub const Protocol = ID;

const NSUInteger = u64;

const GetClass = *const fn (name: [*c]const u8) callconv(.C) ?*Class;
const RegisterName = *const fn (name: [*c]const u8) callconv(.C) ?*Selector;
const AllocateClassPair = *const fn (class: ?*Class, name: [*c]const u8, extra_bytes: c_int) callconv(.C) ?*Class;
const RegisterClassPair = *const fn (class: ?*Class) callconv(.C) void;
const AddMethod = *const fn (class: ?*Class, name: ?*Selector, imp: IMP, types: [*c]const u8) callconv(.C) bool;

const GetProtocol = *const fn (name: [*c]const u8) callconv(.C) ?*Protocol;
const AddProtocol = *const fn (?*Class, ?*Protocol) callconv(.C) bool;

const MakeRect = *const fn (x: f64, y: f64, w: f64, h: f64) callconv(.C) ?*anyopaque;

pub const Rect = extern struct {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
};

const MsgSend = *const fn (class: ?*Class, sel: ?*Selector) callconv(.C) ?*anyopaque;
const MsgSend_ID = *const fn (class: ?*Class, sel: ?*Selector, id: ?*anyopaque) callconv(.C) ?*anyopaque;
const MsgSend_Int = *const fn (class: ?*Class, sel: ?*Selector, arg1: u64) callconv(.C) ?*anyopaque;
const MsgSend_UInt = *const fn (class: ?*Class, sel: ?*Selector, arg1: NSUInteger) callconv(.C) ?*anyopaque;
const MsgSend_Bool = *const fn (class: ?*Class, sel: ?*Selector, arg1: bool) callconv(.C) ?*anyopaque;
const MsgSend_String = *const fn (class: ?*Class, sel: ?*Selector, string: [*c]const u8) callconv(.C) ?*anyopaque;
const MsgSend_Window = *const fn (class: ?*Class, sel: ?*Selector, rect: Rect, style_mask: NSUInteger, backing: u64, _defer: bool) callconv(.C) ?*anyopaque;
const MsgSend_NextEvent = *const fn (class: ?*Class, sel: ?*Selector, mask: u64, until_date: ?*ID, in_mode: ?*ID, dequeue: bool) callconv(.C) ?*anyopaque;

const IMP = *const fn (id: ?*ID, selector: ?*Selector, window: ?*ID) callconv(.C) bool;

pub const load = Fns.init;

const Fns = struct {
    getClass: GetClass,
    registerName: RegisterName,

    allocateClassPair: AllocateClassPair,
    registerClassPair: RegisterClassPair,
    addMethod: AddMethod,
    getProtocol: GetProtocol,
    addProtocol: AddProtocol,

    makeRect: MakeRect,

    msgSend: MsgSend,
    msgSend_ID: MsgSend_ID,
    msgSend_Int: MsgSend_Int,
    msgSend_UInt: MsgSend_UInt,
    msgSend_Bool: MsgSend_Bool,
    msgSend_String: MsgSend_String,
    msgSend_Window: MsgSend_Window,
    msgSend_NextEvent: MsgSend_NextEvent,

    msgSend_Void: *const fn (class: ?*Class, sel: ?*Selector, arg1: ?*ID) callconv(.C) void,
    msgSend_ID_Void: *const fn (class: ?*Class, sel: ?*Selector, id: ?*anyopaque) callconv(.C) void,
    msgSend_Int_Bool: *const fn (class: ?*Class, sel: ?*Selector, arg1: u64) callconv(.C) bool,
    msgSend_UInt_Void: *const fn (class: ?*Class, sel: ?*Selector, arg1: NSUInteger) callconv(.C) void,
    msgSend_Bool_Void: *const fn (class: ?*Class, sel: ?*Selector, arg1: bool) callconv(.C) void,
    msgSend_String_Void: *const fn (class: ?*Class, sel: ?*Selector, id: [*c]const u8) callconv(.C) void,

    defaultRunLoopMode: ?*ID,

    objc: std.DynLib,
    appkit: std.DynLib,
    foundation: std.DynLib,

    pub fn init() !@This() {
        var objc = try std.DynLib.open("libobjc.A.dylib");
        var foundation = try std.DynLib.open("/System/Library/Frameworks/Foundation.framework/Resources/BridgeSupport/Foundation.dylib");
        const appkit = try std.DynLib.open("/System/Library/Frameworks/AppKit.framework/Resources/BridgeSupport/AppKit.dylib");
        _ = try std.DynLib.open("/System/Library/Frameworks/CoreFoundation.framework/Resources/BridgeSupport/CoreFoundation.dylib");
        //_ = try std.DynLib.open("/System/Library/Frameworks/CoreGraphics.framework/Resources/BridgeSupport/CoreGraphics.dylib");
        //_ = try std.DynLib.open("/System/Library/Frameworks/IOKit.framework/Resources/BridgeSupport/IOKit.dylib");

        const msgSend = objc.lookup(MsgSend, "objc_msgSend") orelse return error.MsgSendFnNotFound;
        return .{
            .objc = objc,
            .foundation = foundation,
            .appkit = appkit,

            //.NSApp = appkit.lookup(*Class, "NSApp") orelse return error.NSAppNotFound,

            .getClass = objc.lookup(GetClass, "objc_getClass") orelse return error.GetClassFnNotFound,
            .registerName = objc.lookup(RegisterName, "sel_registerName") orelse return error.RegisterNameFnNotFound,

            .allocateClassPair = objc.lookup(AllocateClassPair, "objc_allocateClassPair") orelse return error.AllocateClassPairFnNotFound,
            .registerClassPair = objc.lookup(RegisterClassPair, "objc_registerClassPair") orelse return error.RegisterClassPairFnNotFound,
            .getProtocol = objc.lookup(GetProtocol, "objc_getProtocol") orelse return error.GetProtocolNameFnNotFound,
            .addProtocol = objc.lookup(AddProtocol, "class_addProtocol") orelse return error.AddProtocolNameFnNotFound,
            .addMethod = objc.lookup(AddMethod, "class_addMethod") orelse return error.AddMethodNameFnNotFound,

            .msgSend = msgSend,
            .msgSend_ID = @ptrCast(msgSend),
            .msgSend_Int = @ptrCast(msgSend),
            .msgSend_UInt = @ptrCast(msgSend),
            .msgSend_Bool = @ptrCast(msgSend),
            .msgSend_Window = @ptrCast(msgSend),
            .msgSend_String = @ptrCast(msgSend),
            .msgSend_NextEvent = @ptrCast(msgSend),

            .msgSend_Void = @ptrCast(msgSend),
            .msgSend_ID_Void = @ptrCast(msgSend),
            .msgSend_Int_Bool = @ptrCast(msgSend),
            .msgSend_UInt_Void = @ptrCast(msgSend),
            .msgSend_Bool_Void = @ptrCast(msgSend),
            .msgSend_String_Void = @ptrCast(msgSend),

            .makeRect = foundation.lookup(MakeRect, "NSMakeRect") orelse return error.MakeRectFnNotFound,

            .defaultRunLoopMode = foundation.lookup(*ID, "NSDefaultRunLoopMode") orelse return error.DefaultRunLoopModeNotFound,
        };
    }

    pub fn deinit(self: @This()) void {
        self.objc.close();
        self.appkit.close();
        self.foundation.close();
    }
};

pub const ApplicationActivationPolicy = enum(c_int) {
    Regular = 0,
    Accessory = 1,
    ERROR = 2,
};

pub const WindowStyleMask = enum(c_uint) {
    Borderless = 0,
    Titled = 1 << 0,
    Closable = 1 << 1,
    Miniaturizable = 1 << 2,
    Resizable = 1 << 3,
};

pub const BackingStoreType = enum(c_uint) {
    Buffered = 2,
};
