const std = @import("std");
const testing = std.testing;

pub const Bookmark = struct {
    value: []const u8,
    path: []const u8,
    tags: []const []const u8,

    pub fn init(value: []const u8, path: []const u8) Bookmark {
        return .{
            .value = value,
            .path = path,
            .tags = &.{},
        };
    }

    pub fn storeBookmark(self: Bookmark, writer: *std.Io.Writer) !void {
        try writer.print("{s},{s},", .{ self.value, self.path });
        for (self.tags) |tag| {
            try writer.print("{s},", .{tag});
        }
        _ = try writer.write("\n");
    }

    pub fn deleteBookmark(self: Bookmark, writer: *std.Io.Writer, reader: std.Io.Reader) !void {
        while (!std.mem.eql(u8, reader.peek(self.value.len), self.value))
            reader.streamDelimiter(writer, "\n");
        reader.streamRemaining(writer);
    }

    pub fn lookup(allocator: std.mem.Allocator, reader: *std.Io.Reader, value: []const u8) !Bookmark {
        while (true) {
            const line = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
                error.EndOfStream, error.StreamTooLong => return error.NotFound,
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

    /// Search bookmarks by query string. Searches in bookmark name, path, and tags.
    /// Returns all bookmarks that contain the query string anywhere in their data.
    /// Caller owns returned slice and must free it.
    pub fn search(allocator: std.mem.Allocator, reader: *std.Io.Reader, query: []const u8) ![]Bookmark {
        var results: std.ArrayList(Bookmark) = .empty;
        errdefer {
            for (results.items) |bookmark| {
                allocator.free(bookmark.tags);
            }
            results.deinit(allocator);
        }

        while (true) {
            const line = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
                error.EndOfStream, error.StreamTooLong => break,
                else => |e| return e,
            };

            // If query is empty, match all lines. Otherwise check if line contains query
            if (query.len == 0 or std.mem.indexOf(u8, line, query) != null) {
                var iter = std.mem.splitScalar(u8, line, ',');
                const value = iter.first();
                const path = iter.next() orelse continue; // Skip malformed lines

                // Collect remaining fields as tags
                var tags: std.ArrayList([]const u8) = .empty;
                defer tags.deinit(allocator);
                while (iter.next()) |tag| {
                    if (tag.len > 0) {
                        try tags.append(allocator, tag);
                    }
                }

                try results.append(allocator, .{
                    .value = value,
                    .path = path,
                    .tags = try tags.toOwnedSlice(allocator),
                });
            }
        }

        return results.toOwnedSlice(allocator);
    }

    /// Delete a bookmark by name. Reads all bookmarks from reader, filters out the one
    /// matching the bookmark name, and writes the remaining bookmarks to writer.
    pub fn delete(reader: *std.Io.Reader, bookmark_name: []const u8, writer: *std.Io.Writer) !void {
        while (true) {
            const line = reader.takeDelimiterExclusive('\n') catch |err| switch (err) {
                error.EndOfStream, error.StreamTooLong => break,
                else => |e| return e,
            };

            // Check if this line starts with the bookmark name followed by a comma
            const prefix_len = bookmark_name.len + 1; // name + comma
            if (line.len < prefix_len or !std.mem.startsWith(u8, line, bookmark_name) or line[bookmark_name.len] != ',') {
                // Keep this line - it's not the bookmark we're deleting
                try writer.writeAll(line);
                try writer.writeByte('\n');
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

test "storeMultipleBookmarks" {
    var bookmark = Bookmark.init("gh", "https://www.github.com");
    bookmark.tags = &.{ "dev", "code", "test123" };
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try bookmark.storeBookmark(&writer);

    var bookmark2 = Bookmark.init("x", "https://www.x.com");
    try bookmark2.storeBookmark(&writer);

    try testing.expectEqualStrings("gh,https://www.github.com,dev,code,test123,\nx,https://www.x.com,\n", writer.buffered());
}

test "lookupBookmark" {
    // lookup a bookmark from a reader
    const data = "gh,https://www.github.com,dev,code,test123,\n";
    var reader = std.Io.Reader.fixed(data);
    const bookmark = try Bookmark.lookup(testing.allocator, &reader, "gh");
    defer testing.allocator.free(bookmark.tags);
    try testing.expectEqualStrings("gh", bookmark.value);
    try testing.expectEqualStrings("https://www.github.com", bookmark.path);
    try testing.expectEqualStrings("dev", bookmark.tags[0]);
    try testing.expectEqualStrings("code", bookmark.tags[1]);
    try testing.expectEqualStrings("test123", bookmark.tags[2]);
}

test "searchBookmarks" {
    const data =
        \\gh,https://www.github.com,dev,code,
        \\gl,https://gitlab.com,dev,ci,
        \\hn,https://news.ycombinator.com,news,tech,
        \\
    ;
    var reader = std.Io.Reader.fixed(data);
    const results = try Bookmark.search(testing.allocator, &reader, "dev");
    defer {
        for (results) |bookmark| {
            testing.allocator.free(bookmark.tags);
        }
        testing.allocator.free(results);
    }

    try testing.expectEqual(@as(usize, 2), results.len);
    try testing.expectEqualStrings("gh", results[0].value);
    try testing.expectEqualStrings("gl", results[1].value);
}

test "searchBookmarksAll" {
    const data =
        \\gh,https://www.github.com,dev,code,
        \\gl,https://gitlab.com,dev,ci,
        \\
    ;
    var reader = std.Io.Reader.fixed(data);
    const results = try Bookmark.search(testing.allocator, &reader, "");
    defer {
        for (results) |bookmark| {
            testing.allocator.free(bookmark.tags);
        }
        testing.allocator.free(results);
    }

    try testing.expectEqual(@as(usize, 2), results.len);
}

test "deleteBookmark" {
    const data =
        \\gh,https://www.github.com,dev,code,
        \\gl,https://gitlab.com,dev,ci,
        \\hn,https://news.ycombinator.com,news,tech,
        \\
    ;

    var reader = std.Io.Reader.fixed(data);
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    // Delete the "gl" bookmark
    try Bookmark.delete(&reader, "gl", &writer);
    try writer.flush();

    // Verify "gl" is gone but others remain
    var result_reader = std.Io.Reader.fixed(writer.buffered());
    const results = try Bookmark.search(
        testing.allocator,
        &result_reader,
        "",
    );
    defer {
        for (results) |bookmark| {
            testing.allocator.free(bookmark.tags);
        }
        testing.allocator.free(results);
    }

    try testing.expectEqual(@as(usize, 2), results.len);
    try testing.expectEqualStrings("gh", results[0].value);
    try testing.expectEqualStrings("hn", results[1].value);
}

test "searchBookmarksEmpty" {
    // Test with empty file
    const data = "";
    var reader = std.Io.Reader.fixed(data);
    const results = try Bookmark.search(testing.allocator, &reader, "");
    defer testing.allocator.free(results);

    try testing.expectEqual(@as(usize, 0), results.len);
}

test "searchBookmarksNoTrailingNewline" {
    // Test with file that doesn't have a trailing newline
    const data = "gh,https://www.github.com,dev,code,";
    var reader = std.Io.Reader.fixed(data);
    const results = try Bookmark.search(testing.allocator, &reader, "");
    defer {
        for (results) |bookmark| {
            testing.allocator.free(bookmark.tags);
        }
        testing.allocator.free(results);
    }

    try testing.expectEqual(@as(usize, 0), results.len); // StreamTooLong means no delimiter found, so no complete lines
}
