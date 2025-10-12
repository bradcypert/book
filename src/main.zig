const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const storage = @import("storage.zig");
const paths = @import("paths.zig");
const browser = @import("browser.zig");
const tui = @import("tui.zig");

const Bookmark = storage.Bookmark;

const InputAction = enum {
    TUI,
    Store,
    Open,
    Search,
    Delete,
    DeleteAll,
    List,
};

const Input = union(InputAction) {
    TUI: struct {},
    Store: struct {
        bookmark: []const u8,
        path: []const u8,
        tags: []const []const u8,
    },
    Open: struct {
        bookmark: []const u8,
    },
    Search: struct {
        query: []const u8,
    },
    Delete: struct {
        bookmark: []const u8,
    },
    DeleteAll: struct {
        i_am_sure: bool,
    },
    List: struct {},
};

var stdout_buf: [256]u8 = undefined;
var stdin_buf: [256]u8 = undefined;
var stderr_buf: [256]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
var stdout = &stdout_writer.interface;
var stdin = &stdin_reader.interface;
var stderr = &stderr_writer.interface;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = parseArgs(allocator) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        return err;
    };
    defer {
        switch (input) {
            .Store => |s| {
                if (s.tags.len > 0) allocator.free(s.tags);
            },
            else => {},
        }
    }

    switch (input) {
        .TUI => {
            const file = try paths.getBookmarkFile(allocator, .read_only);
            defer file.close();

            var buffer: [1024]u8 = undefined;
            var reader = file.reader(&buffer);

            const results = try Bookmark.search(allocator, &reader.interface, "");
            defer {
                for (results) |bookmark| {
                    allocator.free(bookmark.tags);
                }
                allocator.free(results);
            }

            var bookmarks: std.MultiArrayList(tui.Bookmark) = .empty;
            defer bookmarks.deinit(allocator);
            for (results) |bookmark| {
                try bookmarks.append(allocator, tui.Bookmark{
                    .value = bookmark.value,
                    .path = bookmark.path,
                    .tags = "",
                });
            }

            try tui.launch(allocator, bookmarks);
        },
        .Store => |s| {
            handleStore(allocator, s) catch |err| {
                try stderr.print("Error storing bookmark: {any}\n", .{err});
                try stderr.flush();
            };
        },
        .Open => |o| {
            handleOpen(allocator, o) catch {
                try stderr.print("Bookmark not found: {s}\n", .{o.bookmark});
                try stderr.flush();
            };
        },
        .Search => |s| {
            handleSearch(allocator, s) catch |err| {
                try stderr.print("Error searching bookmarks: {any}\n", .{err});
                try stderr.flush();
            };
        },
        .Delete => |d| {
            handleDelete(allocator, d) catch |err| {
                try stderr.print("Error deleting bookmark: {any}\n", .{err});
                try stderr.flush();
            };
        },
        .DeleteAll => |da| {
            handleDeleteAll(allocator, da) catch |err| {
                try stderr.print("Error deleting all bookmarks: {any}\n", .{err});
                try stderr.flush();
            };
        },
        .List => {
            handleList(allocator) catch |err| {
                try stderr.print("Error listing bookmarks: {any}\n", .{err});
                try stderr.flush();
            };
        },
    }
}

fn handleDeleteAll(allocator: std.mem.Allocator, input: @TypeOf(@as(Input, undefined).DeleteAll)) !void {
    var confirmed = input.i_am_sure;

    if (!confirmed) {
        _ = try stdout.write("Are you sure you want to delete all bookmarks? [y/N] ");
        try stdout.flush();

        const user_input = try stdin.take(10);
        const trimmed = std.mem.trim(u8, user_input, &std.ascii.whitespace);
        confirmed = std.ascii.eqlIgnoreCase(trimmed, "y");
    }

    if (confirmed) {
        try paths.deleteBookmarkFile(allocator);
        _ = try stdout.write("All bookmarks deleted.\n");
        try stdout.flush();
    } else {
        _ = try stdout.write("Cancelled.\n");
        try stdout.flush();
    }
}

fn handleDelete(allocator: std.mem.Allocator, input: @TypeOf(@as(Input, undefined).Delete)) !void {
    const in_file = try paths.getBookmarkFile(allocator, .read_only);
    defer in_file.close();

    const bookmark_file_path = try paths.getBookmarkFilePath(allocator);
    defer allocator.free(bookmark_file_path);

    var buffer: [1024]u8 = undefined;
    var reader = in_file.reader(&buffer);

    // Create an allocating writer
    var allocating_writer = std.Io.Writer.Allocating.init(allocator);
    defer allocating_writer.deinit();

    try Bookmark.delete(&reader.interface, input.bookmark, &allocating_writer.writer);

    // Write to file
    const file = try std.fs.cwd().createFile(bookmark_file_path, .{});
    defer file.close();
    try file.writeAll(allocating_writer.writer.buffered());

    try stdout.print("Deleted bookmark: {s}\n", .{input.bookmark});
    try stdout.flush();
}

fn handleStore(allocator: std.mem.Allocator, input: @TypeOf(@as(Input, undefined).Store)) !void {
    const file = try paths.getBookmarkFile(allocator, .append);
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var writer = file.writer(&buffer);
    try writer.seekTo(try writer.file.getEndPos());

    var bookmark = Bookmark.init(input.bookmark, input.path);
    bookmark.tags = input.tags;

    try bookmark.storeBookmark(&writer.interface);
    try writer.interface.flush();

    try stdout.print("Stored bookmark: {s} -> {s}\n", .{ input.bookmark, input.path });
    try stdout.flush();
}

fn handleList(allocator: std.mem.Allocator) !void {
    const file = try paths.getBookmarkFile(allocator, .read_only);
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var reader = file.reader(&buffer);

    const results = try Bookmark.search(allocator, &reader.interface, "");
    defer {
        for (results) |bookmark| {
            allocator.free(bookmark.tags);
        }
        allocator.free(results);
    }

    try printTable(allocator, results);
}

fn handleSearch(allocator: std.mem.Allocator, input: @TypeOf(@as(Input, undefined).Search)) !void {
    const file = try paths.getBookmarkFile(allocator, .read_only);
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var reader = file.reader(&buffer);
    const results = try Bookmark.search(allocator, &reader.interface, input.query);
    defer {
        for (results) |bookmark| {
            allocator.free(bookmark.tags);
        }
        allocator.free(results);
    }

    try printTable(allocator, results);
}

fn handleOpen(allocator: std.mem.Allocator, input: @TypeOf(@as(Input, undefined).Open)) !void {
    const file = try paths.getBookmarkFile(allocator, .read_only);
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_contents);

    var reader = std.Io.Reader.fixed(file_contents);
    const bookmark = Bookmark.lookup(allocator, &reader, input.bookmark) catch |err| {
        return err;
    };
    defer allocator.free(bookmark.tags);

    try browser.openExternal(bookmark.path);
}

fn printTable(_: std.mem.Allocator, bookmarks: []const Bookmark) !void {
    // Print header
    _ = try stdout.write("Bookmark          Path                                      Tags\n");
    _ = try stdout.write("----------------  ----------------------------------------  --------------------\n");

    for (bookmarks) |bookmark| {
        // Print bookmark name (padded to 16 chars)
        try stdout.print("{s}", .{bookmark.value});
        if (bookmark.value.len < 16) {
            var i: usize = 0;
            while (i < 16 - bookmark.value.len) : (i += 1) {
                _ = try stdout.write(" ");
            }
        }
        _ = try stdout.write("  ");

        // Print path (padded to 40 chars)
        const path_display = if (bookmark.path.len > 40) bookmark.path[0..37] else bookmark.path;
        try stdout.print("{s}", .{path_display});
        if (bookmark.path.len > 40) {
            _ = try stdout.write("...");
        } else {
            var i: usize = 0;
            while (i < 40 - bookmark.path.len) : (i += 1) {
                _ = try stdout.write(" ");
            }
        }
        _ = try stdout.write("  ");

        // Print tags (joined with commas)
        for (bookmark.tags, 0..) |tag, i| {
            if (i > 0) _ = try stdout.write(",");
            try stdout.print("{s}", .{tag});
        }
        _ = try stdout.write("\n");
    }
    try stdout.flush();
}

fn parseArgs(allocator: std.mem.Allocator) !Input {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    var tags_list: std.ArrayList([]const u8) = .empty;
    defer tags_list.deinit(allocator);

    var positional_args: std.ArrayList([]const u8) = .empty;
    defer positional_args.deinit(allocator);

    var is_search = false;
    var is_delete_all = false;
    var is_delete = false;
    var is_list = false;
    var i_am_sure = false;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-tags") or std.mem.eql(u8, arg, "--tags")) {
            const tags_str = args.next() orelse return error.MissingTagsValue;
            var iter = std.mem.splitScalar(u8, tags_str, ',');
            while (iter.next()) |tag| {
                if (tag.len > 0) {
                    try tags_list.append(allocator, tag);
                }
            }
        } else if (std.mem.eql(u8, arg, "-search") or std.mem.eql(u8, arg, "--search")) {
            is_search = true;
        } else if (std.mem.eql(u8, arg, "-deleteAll") or std.mem.eql(u8, arg, "--deleteAll")) {
            is_delete_all = true;
        } else if (std.mem.eql(u8, arg, "-yes") or std.mem.eql(u8, arg, "--yes")) {
            i_am_sure = true;
        } else if (std.mem.eql(u8, arg, "-delete") or std.mem.eql(u8, arg, "--delete")) {
            is_delete = true;
        } else if (std.mem.eql(u8, arg, "-list") or std.mem.eql(u8, arg, "--list")) {
            is_list = true;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            try positional_args.append(allocator, arg);
        }
    }

    if (positional_args.items.len == 0 and !is_list and !is_delete_all) {
        return Input{ .TUI = .{} };
    }

    // Return the appropriate tagged union variant based on flags
    if (is_delete_all) {
        return Input{ .DeleteAll = .{ .i_am_sure = i_am_sure } };
    }

    if (is_list) {
        return Input{ .List = .{} };
    }

    const bookmark = if (positional_args.items.len > 0) positional_args.items[0] else "";

    if (is_delete) {
        if (bookmark.len == 0) return error.BookmarkRequired;
        return Input{ .Delete = .{ .bookmark = bookmark } };
    }

    if (is_search) {
        if (bookmark.len == 0) return error.BookmarkRequired;
        return Input{ .Search = .{ .query = bookmark } };
    }

    // If we have a path (2nd positional arg), this is a Store operation
    if (positional_args.items.len > 1) {
        const tags = try tags_list.toOwnedSlice(allocator);
        return Input{ .Store = .{
            .bookmark = bookmark,
            .path = positional_args.items[1],
            .tags = tags,
        } };
    }

    // Otherwise, if we have just a bookmark, this is an Open operation
    if (bookmark.len > 0) {
        return Input{ .Open = .{ .bookmark = bookmark } };
    }

    return error.BookmarkRequired;
}

test {
    std.testing.refAllDecls(@This());
}
