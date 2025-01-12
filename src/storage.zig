const std = @import("std");

const Error = error{
    ReadError,
    BookmarkNotFound,
};

const Bookmark = struct {
    value: [] const u8,
    path: [] const u8,
    tags: [][] const u8,

    pub fn fromLine(allocator: std.mem.Allocator, line: []u8) !Bookmark {
        var splitter = std.mem.split(line, ',');
        defer splitter.deinit();

        var parts = std.ArrayList([]const u8).init(allocator);
        defer parts.deinit();

        while (splitter.next()) |part| {
            try parts.append(part);
        }

        if (parts.items.len < 2) {
            return error.InvalidInput;
        }

        const value = parts.items[0];
        const path = parts.items[1];

        var tags = try allocator.alloc([]const u8, parts.items.len - 2);
        for (parts.items[2..], 2..) |tag, index| {
            tags[index] = tag;
        }

        return Bookmark{
            .value = value,
            .path = path,
            .tags = tags,
        };
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

fn storeBookmark(allocator: std.mem.Allocator, writer: std.io.Writer, bookmark: Bookmark) !void {
    // Join tags array into a comma-separated string
    const tags_str = std.mem.join(allocator, bookmark.tags, ",") catch {
        return error.OutOfMemory;
    };
    defer allocator.free(tags_str);
    try writer.print("{s},{s},{any}\n", .{ bookmark.value, bookmark.path, tags_str, });
}

pub fn deleteBookmark(allocator: *std.mem.Allocator, reader: anytype, bookmark: []const u8) !void {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    var input = std.io.bufferedReader(reader);

    while (try input.readUntilDelimiterOrEofAlloc(allocator, '\n')) |line| {
        if (!std.mem.startsWith(u8, line, bookmark) or (line[bookmark.len] != ',')) {
            try buf.appendSlice(line);
            try buf.appendSlice("\n");
        }
    }

    const fp = try getBookmarkFilePath();

    var file = try std.fs.Dir.cwd().createFile(fp, .{});
    defer file.close();

    try file.writeAll(buf.items);
}

pub fn searchBookmarks(allocator: *std.mem.Allocator, reader: anytype, query: []const u8) ![]Bookmark {
    var searchResults = std.ArrayList(Bookmark).init(allocator);
    defer searchResults.deinit();

    var input = std.io.bufferedReader(reader);

    while (try input.readUntilDelimiterOrEofAlloc(allocator, '\n')) |line| {
        if (std.mem.contains(u8, line, query)) {
            const bookmark = try Bookmark.fromLine(allocator, line);
            try searchResults.append(bookmark);
        }
    }

    if (input.hasError()) {
        return error.SearchError;
    }

    return searchResults.toOwnedSlice();
}


pub fn getBookmark(allocator: *std.mem.Allocator, reader: anytype, bookmark: []const u8) !Bookmark {
    var input = std.io.bufferedReader(reader);

    while (try input.readUntilDelimiterOrEofAlloc(allocator, '\n')) |line| {
        if (std.mem.startsWith(u8, line, bookmark)) {
            return Bookmark.fromLine(allocator, line);
        }
    }

    if (input.hasError()) {
        return Error.ReadError;
    }

    return Error.BookmarkNotFound;
}
