const std = @import("std");

fn getStoragePath(allocator: std.mem.Allocator) ![]const u8 {
    const config_dir = try std.fs.getAppDataDir(allocator, "book");
    return config_dir;
}

pub fn getBookmarkFilePath(allocator: std.mem.Allocator) ![]const u8 {
    const storage_path = try getStoragePath(allocator);
    defer allocator.free(storage_path);

    const bookmark_file_path = try std.fs.path.join(allocator, &[_][]const u8{ storage_path, "bookmarks.csv" });
    return bookmark_file_path;
}

pub fn deleteBookmarkFile(allocator: std.mem.Allocator) !void {
    const bookmark_file_path = try getBookmarkFilePath(allocator);
    defer allocator.free(bookmark_file_path);

    try std.fs.deleteFileAbsolute(bookmark_file_path);
}

pub fn getBookmarkFile(allocator: std.mem.Allocator, file_mode: std.fs.File.OpenFlags) !std.fs.File {
    const bookmark_file_path = try getBookmarkFilePath(allocator);
    defer allocator.free(bookmark_file_path);

    const storage_path = try getStoragePath(allocator);
    defer allocator.free(storage_path);

    try std.fs.makeDirAbsolute(storage_path);

    return std.fs.cwd().openFile(bookmark_file_path, file_mode) catch std.fs.cwd().createFile(bookmark_file_path, .{ .read = true });
}
