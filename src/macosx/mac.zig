const std = @import("std");

pub const ID = anyopaque;
pub const Class = ID;
pub const Selector = ID;
pub const Protocol = ID;

const MsgSend = *const fn (class: ?*Class, sel: ?*Selector) callconv(.C) ?*ID;
const GetClass = *const fn (name: [*c]const u8) callconv(.C) ?*Class;
const RegisterName = *const fn (name: [*c]const u8) callconv(.C) ?*Selector;

const AllocateClassPair = *const fn (class: ?*Class, name: [*c]const u8, extra_bytes: c_int) callconv(.C) ?*Class;
const RegisterClassPair = *const fn (class: ?*Class) callconv(.C) void;
const AddMethod = *const fn (class: ?*Class, name: ?*Selector, imp: Implementation, types: [*c]const u8) callconv(.C) bool;
const GetProtocol = *const fn (name: [*c]const u8) callconv(.C) ?*Protocol;
const AddProtocol = *const fn (?*Class, ?*Protocol) callconv(.C) bool;

const Implementation = *const fn (id: ?*ID, selector: ?*Selector, window: ?*ID) callconv(.C) bool;

pub const load = Fns.init;

const Fns = struct {
    getClass: GetClass,
    registerName: RegisterName,

    msgSend: MsgSend,

    msgSend_ID: *const fn (class: ?*Class, sel: ?*Selector) callconv(.C) ?*ID,
    msgSend_Void: *const fn (class: ?*Class, sel: ?*Selector) callconv(.C) void,
    msgSend_ID_Void: *const fn (class: ?*Class, sel: ?*Selector, id: ?*ID) callconv(.C) void,
    msgSend_Int_Bool: *const fn (class: ?*Class, sel: ?*Selector, arg1: c_uint) callconv(.C) bool,
    msgSend_Bool_Void: *const fn (class: ?*Class, sel: ?*Selector, arg1: bool) callconv(.C) void,
    msgSend_String_ID: *const fn (class: ?*Class, sel: ?*Selector, id: [*c]const u8) callconv(.C) ?*ID,
    msgSend_String_Void: *const fn (class: ?*Class, sel: ?*Selector, id: [*c]const u8) callconv(.C) void,

    msgSend_WindowInit_ID: *const fn (class: ?*Class, sel: ?*Selector, rect: Rect, style_mask: c_uint, backing_store: c_uint, _defer: bool) callconv(.C) ?*ID,

    allocateClassPair: AllocateClassPair,
    registerClassPair: RegisterClassPair,
    addMethod: AddMethod,
    getProtocol: GetProtocol,
    addProtocol: AddProtocol,

    objc: std.DynLib,
    appkit: std.DynLib,
    foundation: std.DynLib,
    coreFoundation: std.DynLib,

    pub fn init() !@This() {
        var objc = try std.DynLib.open("libobjc.A.dylib");
        const appkit = try std.DynLib.open("/System/Library/Frameworks/AppKit.framework/Resources/BridgeSupport/AppKit.dylib");
        const foundation = try std.DynLib.open("/System/Library/Frameworks/Foundation.framework/Resources/BridgeSupport/Foundation.dylib");
        const coreFoundation = try std.DynLib.open("/System/Library/Frameworks/CoreFoundation.framework/Resources/BridgeSupport/CoreFoundation.dylib");

        const msgSend = objc.lookup(MsgSend, "objc_msgSend") orelse return error.MsgSendFnNotFound;

        return .{
            .objc = objc,
            .appkit = appkit,
            .foundation = foundation,
            .coreFoundation = coreFoundation,

            .getClass = objc.lookup(GetClass, "objc_getClass") orelse return error.GetClassFnNotFound,
            .registerName = objc.lookup(RegisterName, "sel_registerName") orelse return error.RegisterNameFnNotFound,

            .allocateClassPair = objc.lookup(AllocateClassPair, "objc_allocateClassPair") orelse return error.AllocateClassPairFnNotFound,
            .registerClassPair = objc.lookup(RegisterClassPair, "objc_registerClassPair") orelse return error.RegisterClassPairFnNotFound,
            .getProtocol = objc.lookup(GetProtocol, "objc_getProtocol") orelse return error.GetProtocolNameFnNotFound,
            .addProtocol = objc.lookup(AddProtocol, "class_addProtocol") orelse return error.AddProtocolNameFnNotFound,
            .addMethod = objc.lookup(AddMethod, "class_addMethod") orelse return error.AddMethodNameFnNotFound,

            .msgSend = msgSend,
            .msgSend_ID = @ptrCast(msgSend),
            .msgSend_Void = @ptrCast(msgSend),
            .msgSend_ID_Void = @ptrCast(msgSend),
            .msgSend_Int_Bool = @ptrCast(msgSend),
            .msgSend_Bool_Void = @ptrCast(msgSend),
            .msgSend_String_ID = @ptrCast(msgSend),
            .msgSend_String_Void = @ptrCast(msgSend),

            .msgSend_WindowInit_ID = @ptrCast(msgSend),
        };
    }

    pub fn deinit(self: @This()) void {
        self.objc.close();
        self.appkit.close();
        self.foundation.close();
        self.coreFoundation.close();
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

    Default = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3),
};

pub const BackingStoreType = enum(c_uint) {
    Buffered = 2,
};

pub const Rect = extern struct {
    x: f64,
    y: f64,
    w: f64,
    h: f64,
};
