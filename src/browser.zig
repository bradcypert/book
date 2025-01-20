const std = @import("std");
const builtin = @import("builtin");

const urlRegex = std.regex.compile("https?://") catch unreachable;

pub fn openExternal(allocator: std.mem.Allocator, path: []const u8) !void {
    const os = builtin.os.tag;
    switch (os) {
        .linux => {
            _ = try std.process.Child.run(.{ .argv = &[_][]const u8{"xdg-open"}, .allocator = allocator });
        },
        .windows => {
            if (std.mem.match(path, urlRegex)) {
                _ = try std.process.Child.run(.{ .argv = &[_][]const u8{ "rundll32", "url.dll,FileProtocolHandler", path }, .allocator = allocator });
            } else {
                _ = try std.process.Child.run(.{ .argv = &[_][]const u8{ "explorer", "/select,", path }, .allocator = allocator }).run();
            }
        },
        .macos => {
            _ = try std.process.Child.run(.{ .argv = &[_][]const u8{ "open", path }, .allocator = allocator });
        },
        else => {
            return error.UnsupportedPlatform;
        },
    }
}
