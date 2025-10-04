const std = @import("std");
const book = @import("book");
const storage = @import("../src/storage.zig");
const paths = @import("../src/paths.zig");

pub fn main() !void {
    var bookmark = storage.Bookmark.init("gh", "https://www.github.com");
    bookmark.tags = &.{ "dev", "code", "test123" };
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try bookmark.storeBookmark(stdout);

    try stdout.flush();
}
