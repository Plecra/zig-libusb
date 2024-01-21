const libusb = @cImport(@cInclude("libusb.h"));
const std = @import("std");

const errors = brk: while (true) {
    const PREFIX = "LIBUSB_ERROR_";

    var names: []const std.builtin.Type.Error = &.{};
    var codes: []const isize = &.{};
    const decls = std.meta.declarations(libusb);
    @setEvalBranchQuota(decls.len * 3);
    for (decls) |err| {
        if (!std.mem.startsWith(u8, err.name, PREFIX)) continue;

        const name = err.name[PREFIX.len..];
        names = names ++ .{std.builtin.Type.Error{ .name = name }};
        codes = codes ++ .{@field(libusb, err.name)};
    }
    break :brk .{ .names = names, .codes = codes };
};
const LibUsbError = @Type(.{ .ErrorSet = errors.names });
fn libusb_try(res: isize) (LibUsbError || error{Unexpected})!usize {
    if (res >= 0) return @intCast(res);
    inline for (errors.names, errors.codes) |name, code| {
        if (res == code) return @field(LibUsbError, name.name);
    }
    return error.Unexpected;
}
pub fn main() !void {
    _ = try libusb_try(libusb.libusb_init(null));
    defer libusb.libusb_exit(null);
    var devs: [*c]?*libusb.libusb_device = undefined;
    const cnt = try libusb_try(libusb.libusb_get_device_list(null, &devs));
    defer libusb.libusb_free_device_list(devs, 1);

    for (devs[0..cnt]) |dev| {
        print_device(dev.?, null);
    }
}
fn print_device(dev: *libusb.libusb_device, _: ?*libusb.libusb_device_handle) void {
    var desc: libusb.libusb_device_descriptor = undefined;
    _ = libusb_try(libusb.libusb_get_device_descriptor(dev, &desc)) catch return;
    std.debug.print("Bus {:0>3} Device {:0>3} ID {X:0>4}:{X:0>4} \n", .{ libusb.libusb_get_bus_number(dev), libusb.libusb_get_device_address(dev), desc.idVendor, desc.idProduct });
}
