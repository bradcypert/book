const std = @import("std");

const urlRegex = std.regex.compile("https?://") catch unreachable;

fn openExternal(path: []const u8) !void {
    var err: ?std.os.Error = null;

    const os = std.builtin.os.tag;
    switch (os) {
        std.builtin.Os.linux => {
            err = std.os.spawnProcess("xdg-open", &[_][]const u8{path}, std.os.ProcessOptions{}) catch |e| e;
        },
        std.builtin.Os.windows => {
            if (std.mem.match(path, urlRegex)) {
                err = std.os.spawnProcess("rundll32", &[_][]const u8{ "url.dll,FileProtocolHandler", path }, std.os.ProcessOptions{}) catch |e| e;
            } else {
                err = std.os.spawnProcess("explorer", &[_][]const u8{ "/select,", path }, std.os.ProcessOptions{}) catch |e| e;
            }
        },
        std.builtin.Os.macos => {
            err = std.os.spawnProcess("open", &[_][]const u8{path}, std.os.ProcessOptions{}) catch |e| e;
        },
        else => {
            return error.UnsupportedPlatform;
        },
    }

    if (err) |e| {
        return e;
    }
}
