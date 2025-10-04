const std = @import("std");
const testing = std.testing;

pub const Bookmark = struct {
    value: []const u8,
    path: []const u8,
    tags: []const []const u8,

    pub fn init(value: []const u8, path: []const u8) Bookmark {
        return .{ .value = value, .path = path, .tags = &.{} };
    }

    pub fn storeBookmark(self: Bookmark, writer: *std.Io.Writer) !void {
        try writer.print("{s},{s},", .{ self.value, self.path });
        for (self.tags) |tag| {
            try writer.print("{s},", .{tag});
        }
        _ = try writer.write("\n");
    }

    // TODO: Is there a cleaner way to do this without both a reader and writer
    pub fn deleteBookmark(self: Bookmark, writer: *std.Io.Writer, reader: std.Io.Reader) !void {
        // instead of getting the file path and managing writing,
        // we are just going to take in a writer and write to the provided writer.
        while (!std.mem.eql(u8, reader.peek(self.value.len), self.value))
            reader.streamDelimiter(writer, "\n");
        reader.streamRemaining(writer);
    }

    pub fn lookup(reader: std.Io.Reader, value: []const u8) !Bookmark {
        while (reader.peekByte()) {
            const line = reader.takeDelimiter();
            var i = std.mem.splitScalar(u8, line, ",");
            if (std.mem.eql(u8, i.first(), value)) {
                return .{
                    .value = i.first(),
                    .path = i.next(),
                    .tags = &.{},
                    // TODO Tags?
                };
            }
        }
    }
};

test "storeBookmark" {
    var bookmark = Bookmark.init("gh", "https://www.github.com");
    bookmark.tags = &.{ "dev", "code", "test123" };
    const buffer: [1024]u8 = undefined;
    var writer = std.Io.Reader.fixed(buffer);
    const w = &writer.interface;
    try bookmark.storeBookmark(w);

    try writer.flush();
    try testing.expectEqualStrings("", writer.buffered());
}
