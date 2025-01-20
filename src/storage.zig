const std = @import("std");
const paths = @import("./paths.zig");

const Error = error{
    ReadError,
    BookmarkNotFound,
};

pub const Bookmark = struct {
    value: []const u8,
    path: []const u8,
    tags: []const []const u8,

    pub fn fromLine(allocator: std.mem.Allocator, line: []u8) !Bookmark {
        var splitter = std.mem.split(u8, line, ",");

        var parts = std.ArrayList([]const u8).init(allocator);
        defer parts.deinit();

        while (splitter.next()) |part| {
            try parts.append(try allocator.dupe(u8, part));
        }
        defer {
            for (parts.items) |part| {
                allocator.free(part);
            }
        }

        const value = try allocator.dupe(u8, parts.items[0]);
        const path = try allocator.dupe(u8, parts.items[1]);

        var tags = try allocator.alloc([]const u8, parts.items.len - 2);
        for (parts.items[2..], 0..) |tag, index| {
            tags[index] = try allocator.dupe(u8, tag);
        }

        return Bookmark{
            .value = value,
            .path = path,
            .tags = tags,
        };
    }

    pub fn free(self: Bookmark, allocator: std.mem.Allocator) void {
        for (self.tags) |tag| {
            allocator.free(tag);
        }
        allocator.free(self.tags);
        allocator.free(self.path);
        allocator.free(self.value);
    }
};

fn nextLine(reader: std.io.Reader, buffer: []u8) !?[]const u8 {
    const line = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;
    // trim annoying windows-only carriage return character
    if (@import("builtin").os.tag == .windows) {
        return std.mem.trimRight(u8, line, "\r");
    } else {
        return line;
    }
}

pub fn storeBookmark(allocator: std.mem.Allocator, writer: anytype, bookmark: Bookmark) !void {
    // Join tags array into a comma-separated string
    var tags = std.ArrayList(u8).init(allocator);
    defer tags.deinit();

    for (bookmark.tags) |tag| {
        try tags.appendSlice(tag);
        try tags.appendSlice(",");
    }
    const tagSlice = try tags.toOwnedSlice();
    defer allocator.free(tagSlice);
    try writer.print("{s},{s},{any}\n", .{
        bookmark.value,
        bookmark.path,
        tagSlice,
    });
}

pub fn deleteBookmark(allocator: std.mem.Allocator, reader: anytype, bookmark: []const u8) !void {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    var buffIo = std.io.bufferedReader(reader);
    var input = buffIo.reader();

    while (try input.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096)) |line| {
        if (!std.mem.startsWith(u8, line, bookmark) or (line[bookmark.len] != ',')) {
            try buf.appendSlice(line);
            try buf.appendSlice("\n");
        }
    }

    const fp = try paths.getBookmarkFilePath(allocator);
    defer allocator.free(fp);

    var file = try std.fs.cwd().createFile(fp, .{});
    defer file.close();

    try file.writeAll(buf.items);
}

pub fn searchBookmarks(allocator: std.mem.Allocator, reader: anytype, query: []const u8) ![]Bookmark {
    var searchResults = std.ArrayList(Bookmark).init(allocator);
    defer searchResults.deinit();

    var buffIo = std.io.bufferedReader(reader);
    var input = buffIo.reader();

    while (try input.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096)) |line| {
        if (std.mem.indexOf(u8, line, query)) |_| {
            const bookmark = try Bookmark.fromLine(allocator, line);
            try searchResults.append(bookmark);
            allocator.free(line);
        }
    }

    return searchResults.toOwnedSlice();
}

pub fn getBookmark(allocator: std.mem.Allocator, reader: anytype, bookmark: []const u8) !Bookmark {
    var buffIo = std.io.bufferedReader(reader);
    var input = buffIo.reader();

    while (try input.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096)) |line| {
        defer allocator.free(line);
        if (std.mem.startsWith(u8, line, bookmark)) {
            return Bookmark.fromLine(allocator, line);
        }
    }

    return Error.BookmarkNotFound;
}
