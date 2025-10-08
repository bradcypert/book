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

    pub fn lookup(reader: *std.Io.Reader, value: []const u8, allocator: std.mem.Allocator) !Bookmark {
        while (true) {
            const line = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
                error.EndOfStream => return error.NotFound,
                else => |e| return e,
            };

            var iter = std.mem.splitScalar(u8, line, ',');
            const first = iter.first();
            if (std.mem.eql(u8, first, value)) {
                const path = iter.next() orelse return error.InvalidFormat;

                // Collect remaining fields as tags
                var tags: std.ArrayList([]const u8) = .empty;
                defer tags.deinit(allocator);
                while (iter.next()) |tag| {
                    if (tag.len > 0) { // Skip empty strings
                        try tags.append(allocator, tag);
                    }
                }

                return .{
                    .value = first,
                    .path = path,
                    .tags = try tags.toOwnedSlice(allocator),
                };
            }
        }
    }
};

test "storeBookmark" {
    var bookmark = Bookmark.init("gh", "https://www.github.com");
    bookmark.tags = &.{ "dev", "code", "test123" };
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try bookmark.storeBookmark(&writer);

    try writer.flush();
    try testing.expectEqualStrings("gh,https://www.github.com,dev,code,test123,\n", writer.buffered());
}

test "lookupBookmark" {
    // lookup a bookmark from a reader
    const data = "gh,https://www.github.com,dev,code,test123,\n";
    var reader = std.Io.Reader.fixed(data);
    const bookmark = try Bookmark.lookup(&reader, "gh", testing.allocator);
    defer testing.allocator.free(bookmark.tags);
    try testing.expectEqualStrings("gh", bookmark.value);
    try testing.expectEqualStrings("https://www.github.com", bookmark.path);
    try testing.expectEqualStrings("dev", bookmark.tags[0]);
    try testing.expectEqualStrings("code", bookmark.tags[1]);
    try testing.expectEqualStrings("test123", bookmark.tags[2]);
}
