const std = @import("std");
const clap = @import("clap");
const bookmarkPaths = @import("./paths.zig");

fn handleDeleteAll(allocator: std.mem.Allocator, skipConfirmation: bool) !void {
    if (!skipConfirmation) {
        // write to std out asking if they really want to do this
    }

    return bookmarkPaths.deleteBookmarkFile(allocator);
}

fn handleDelete(bookmarkKey: []const u8, skipConfirmation: bool) !void {}

fn handleOpen(bookmarkKey: []const u8) !void {}

fn handleStore(bookmarkKey: []const u8, bookmarkValue: []const u8) !void {}

fn handleList() !void {}

fn handleSearch(searchQuery: []const u8) !void {}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-s, --search <str>     Search for existing bookmarks against the provided query
        \\-t, --tags   <str>     Comma separated tags for faster searching
        \\-d, --delete <str>     Delete the bookmark with the provided key
        \\-l, --list             List all bookmarks
        \\-D, --deleteAll        Ignore other flags and delete bookmark database
        \\-Y, --yes              Accept all future confirmations with "yes"
        \\<str>...
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
        return handleDeleteAll(res.args.yes);
    }

    if (res.args.list != 0) {
        return handleList();
    }

    if (res.args.delete != 0 and res.positionals[0]) |bookmarkKey| {
        return handleDelete(bookmarkKey);
    }

    if (res.positionals[0]) |bookmarkKey| {
        if (res.positionals[1]) |bookmarkValue| {
            return handleStore(bookmarkKey, bookmarkValue);
        } else {
            return handleOpen(bookmarkKey);
        }
    }

    if (res.args.search) |query| {
        return handleSearch(query);
    }

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }
}
