const std = @import("std");

fn getStoragePath(allocator: std.mem.Allocator) ![]const u8 {
    return std.fs.getAppDataDir(allocator, "bradcypert.book");
}

pub fn getBookmarkFilePath(allocator: std.mem.Allocator) ![]const u8 {
    const path = try getStoragePath(allocator);
    return std.fs.path.join(allocator, &.{ path, "bookmarks.csv" });
}

pub fn deleteBookmarkFile(allocator: std.mem.Allocator) !void {
    const path = try getBookmarkFilePath(allocator);
    defer allocator.free(path);

    return std.fs.cwd().deleteFile(path);
}

pub fn getBookmarkFile(allocator: std.mem.Allocator) !std.fs.File {
    const path = try getBookmarkFilePath(allocator);
    defer allocator.free(path);
    const storage_path = getStoragePath(allocator);
    defer allocator.free(storage_path);

    std.fs.cwd().makePath(storage_path);
    return std.fs.cwd().createFile(path, .{
        .mode = .ModeAppend,
        .truncate = false,
        .read = true,
    });
}
