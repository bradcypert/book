const std = @import("std");
const storage = @import("storage.zig");
const paths = @import("paths.zig");
const browser = @import("browser.zig");

const Bookmark = storage.Bookmark;

const Input = struct {
    bookmark: []const u8,
    path: []const u8,
    tags: []const []const u8,
    search: bool,
    delete_all: bool,
    delete: bool,
    list: bool,
    i_am_sure: bool,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = parseArgs(allocator) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
    defer {
        if (input.tags.len > 0) allocator.free(input.tags);
    }

    if (input.delete_all) {
        try handleDeleteAll(allocator, input);
    } else if (input.list) {
        try handleList(allocator);
    } else if (input.delete and input.bookmark.len > 0) {
        try handleDelete(allocator, input);
    } else if (input.path.len > 0) {
        try handleStore(allocator, input);
    } else if (input.search) {
        try handleSearch(allocator, input);
    } else {
        try handleOpen(allocator, input);
    }
}

fn handleDeleteAll(allocator: std.mem.Allocator, input: Input) !void {
    var confirmed = input.i_am_sure;

    if (!confirmed) {
        var stdout_buf: [256]u8 = undefined;
        var stdin_buf: [256]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
        const stdout = &stdout_writer.interface;
        var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
        const stdin = &stdin_reader.interface;

        _ = try stdout.write("Are you sure you want to delete all bookmarks? [y/N] ");
        try stdout.flush();

        const user_input = try stdin.take(10);
        const trimmed = std.mem.trim(u8, user_input, &std.ascii.whitespace);
        confirmed = std.ascii.eqlIgnoreCase(trimmed, "y");
    }

    if (confirmed) {
        try paths.deleteBookmarkFile(allocator);
        var buf: [256]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&buf);
        const stdout = &stdout_writer.interface;
        _ = try stdout.write("All bookmarks deleted.\n");
        try stdout.flush();
    } else {
        var buf: [256]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&buf);
        const stdout = &stdout_writer.interface;
        _ = try stdout.write("Cancelled.\n");
        try stdout.flush();
    }
}

fn handleDelete(allocator: std.mem.Allocator, input: Input) !void {
    const file_path = try paths.getBookmarkFilePath(allocator);
    defer allocator.free(file_path);

    const file_contents = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(file_contents);

    var reader = std.Io.Reader.fixed(file_contents);

    // Create an allocating writer
    var allocating_writer = std.Io.Writer.Allocating.init(allocator);
    defer allocating_writer.deinit();

    try Bookmark.delete(&reader, input.bookmark, &allocating_writer.writer);

    // Write to file
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();
    try file.writeAll(allocating_writer.writer.buffered());

    var buf: [256]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;
    try stdout.print("Deleted bookmark: {s}\n", .{input.bookmark});
    try stdout.flush();
}

fn handleStore(allocator: std.mem.Allocator, input: Input) !void {
    const file = try paths.getBookmarkFile(allocator, .append);
    defer file.close();

    // Format the bookmark line: "value,path,tag1,tag2,\n"
    var line: std.ArrayList(u8) = .empty;
    defer line.deinit(allocator);

    try line.writer(allocator).print("{s},{s},", .{ input.bookmark, input.path });
    for (input.tags) |tag| {
        try line.writer(allocator).print("{s},", .{tag});
    }
    try line.append(allocator, '\n');

    // Write directly to the file
    try file.writeAll(line.items);

    var stdout_buf: [256]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;
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

fn handleSearch(allocator: std.mem.Allocator, input: Input) !void {
    const file = try paths.getBookmarkFile(allocator, .read_only);
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var reader = file.reader(&buffer);
    const results = try Bookmark.search(allocator, &reader.interface, input.bookmark);
    defer {
        for (results) |bookmark| {
            allocator.free(bookmark.tags);
        }
        allocator.free(results);
    }

    try printTable(allocator, results);
}

fn handleOpen(allocator: std.mem.Allocator, input: Input) !void {
    const file = try paths.getBookmarkFile(allocator, .read_only);
    defer file.close();

    const file_contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_contents);

    var reader = std.Io.Reader.fixed(file_contents);
    const bookmark = Bookmark.lookup(allocator, &reader, input.bookmark) catch |err| {
        std.debug.print("Bookmark not found: {s}\n", .{input.bookmark});
        return err;
    };
    defer allocator.free(bookmark.tags);

    try browser.openExternal(bookmark.path);
}

fn printTable(_: std.mem.Allocator, bookmarks: []const Bookmark) !void {
    var buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;

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

    var input = Input{
        .bookmark = "",
        .path = "",
        .tags = &[_][]const u8{},
        .search = false,
        .delete_all = false,
        .delete = false,
        .list = false,
        .i_am_sure = false,
    };

    var tags_list: std.ArrayList([]const u8) = .empty;
    defer tags_list.deinit(allocator);

    var positional_args: std.ArrayList([]const u8) = .empty;
    defer positional_args.deinit(allocator);

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
            input.search = true;
        } else if (std.mem.eql(u8, arg, "-deleteAll") or std.mem.eql(u8, arg, "--deleteAll")) {
            input.delete_all = true;
        } else if (std.mem.eql(u8, arg, "-yes") or std.mem.eql(u8, arg, "--yes")) {
            input.i_am_sure = true;
        } else if (std.mem.eql(u8, arg, "-delete") or std.mem.eql(u8, arg, "--delete")) {
            input.delete = true;
        } else if (std.mem.eql(u8, arg, "-list") or std.mem.eql(u8, arg, "--list")) {
            input.list = true;
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            try positional_args.append(allocator, arg);
        }
    }

    // Parse positional arguments
    if (positional_args.items.len > 0) {
        input.bookmark = positional_args.items[0];
    }
    if (positional_args.items.len > 1) {
        input.path = positional_args.items[1];
    }

    // Validate
    if (input.bookmark.len == 0 and !input.delete_all and !input.list) {
        return error.BookmarkRequired;
    }

    input.tags = try tags_list.toOwnedSlice(allocator);
    return input;
}

test {
    std.testing.refAllDecls(@This());
}
