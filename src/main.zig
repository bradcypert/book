const std = @import("std");
const clap = @import("clap");
const bookmarkPaths = @import("./paths.zig");
const storage = @import("./storage.zig");
const browser = @import("./browser.zig");

fn handleDeleteAll(allocator: std.mem.Allocator, skipConfirmation: bool) !void {
    if (!skipConfirmation) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("Are you sure you want to delete all bookmarks? (y/n): ", .{});
        var input: [1]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        _ = stdin.readUntilDelimiter(&input, '\n') catch return;

        if (!std.mem.eql(u8, &input, "y") and !std.mem.eql(u8, &input, "Y")) {
            return;
        }
    }

    return bookmarkPaths.deleteBookmarkFile(allocator);
}

fn handleDelete(allocator: std.mem.Allocator, bookmarkKey: []const u8, skipConfirmation: bool) !void {
    if (!skipConfirmation) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("Are you sure you want to delete the bookmark '{s}'? (y/n): ", .{bookmarkKey});
        var input: [1]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        _ = try stdin.readUntilDelimiter(&input, '\n');

        if (!std.mem.eql(u8, &input, "y") or !std.mem.eql(u8, &input, "Y")) {
            return;
        }
    }

    var file = try bookmarkPaths.getBookmarkFile(allocator, .{ .mode = .read_write });
    try storage.deleteBookmark(allocator, file.reader(), bookmarkKey);
}

fn handleOpen(allocator: std.mem.Allocator, bookmarkKey: []const u8) !void {
    const file = try bookmarkPaths.getBookmarkFile(allocator, .{ .mode = .read_only });
    // LEAKING HERE-ISH
    const bookmark = try storage.getBookmark(allocator, file.reader(), bookmarkKey);
    defer bookmark.free(allocator);
    // END LEAK HERE
    try browser.openExternal(allocator, bookmark.path);
}

fn handleStore(allocator: std.mem.Allocator, bookmarkKey: []const u8, bookmarkValue: []const u8, bookmarkTags: [][]const u8) !void {
    const file = try bookmarkPaths.getBookmarkFile(allocator, .{ .mode = .read_write });

    try storage.storeBookmark(allocator, file.writer(), storage.Bookmark{
        .value = bookmarkKey,
        .path = bookmarkValue,
        .tags = bookmarkTags,
    });
}

fn printBookmarks(allocator: std.mem.Allocator, bookmarks: []storage.Bookmark, writer: anytype) !void {
    for (bookmarks) |bookmark| {
        const tags_str = try std.mem.join(allocator, ",", bookmark.tags);
        defer allocator.free(tags_str);
        try writer.print(">> {s}, {s}, {s}\n", .{
            bookmark.value,
            bookmark.path,
            tags_str,
        });
    }
}

fn handleList(allocator: std.mem.Allocator, writer: anytype) !void {
    const file = try bookmarkPaths.getBookmarkFile(allocator, .{ .mode = .read_only });
    const bookmarks = try storage.searchBookmarks(allocator, file.reader(), "");
    defer {
        for (bookmarks) |bookmark| {
            bookmark.free(allocator);
        }
        allocator.free(bookmarks);
    }
    try printBookmarks(allocator, bookmarks, writer);
}

fn handleSearch(allocator: std.mem.Allocator, writer: anytype, searchQuery: []const u8) !void {
    const file = try bookmarkPaths.getBookmarkFile(allocator, .{ .mode = .read_only });
    const bookmarks = try storage.searchBookmarks(allocator, file.reader(), searchQuery);
    defer {
        for (bookmarks) |bookmark| {
            bookmark.free(allocator);
        }
        allocator.free(bookmarks);
    }
    try printBookmarks(allocator, bookmarks, writer);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 50 }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-s, --search <str>     Search for existing bookmarks against the provided query
        \\-t, --tags   <str>     Comma separated tags for faster searching
        \\-d, --delete           Delete the bookmark with the provided key
        \\-l, --list             List all bookmarks
        \\-D, --deleteAll        Ignore other flags and delete bookmark database
        \\-Y, --yes              Accept all future confirmations with "yes"
        \\<str>                  Bookmark key
        \\<str>                  Bookmark value
        \\<str>                  Bookmark tags (separated by comma)
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        // Report useful error and exit.
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.deleteAll != 0) {
        return handleDeleteAll(allocator, res.args.yes == 0);
    }

    if (res.args.list != 0) {
        return handleList(allocator, std.io.getStdOut().writer());
    }

    if (res.args.delete != 0) {
        if (res.positionals[0].len != 0) {
            const bookmarkKey = res.positionals[0];
            return handleDelete(allocator, bookmarkKey, res.args.yes == 0);
        }
    }

    if (res.positionals.len > 0 and res.positionals[0].len != 0) {
        const bookmarkKey = res.positionals[0];
        if (res.positionals.len > 1 and res.positionals[1].len != 0) {
            const bookmarkValue = res.positionals[1];
            const bookmarkTags = if (res.positionals.len > 2) res.positionals[2] else &[_]u8{};
            var tagIterator = std.mem.split(u8, bookmarkTags, ",");

            var list = std.ArrayList([]const u8).init(allocator);
            defer list.deinit();
            while (tagIterator.next()) |tag| try list.append(tag);
            const tags = try list.toOwnedSlice();
            defer allocator.free(tags);

            return handleStore(allocator, bookmarkKey, bookmarkValue, tags);
        } else {
            return handleOpen(allocator, bookmarkKey);
        }
    }

    if (res.args.search) |query| {
        return handleSearch(allocator, std.io.getStdOut().writer(), query);
    }

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }
}
