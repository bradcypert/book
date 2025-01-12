const std = @import("std");

fn getStoragePath(allocator: *std.mem.Allocator) ![]const u8 {
    const config_dir = try std.fs.getConfigDirAlloc(allocator);
    defer allocator.free(config_dir);

    const storage_path = try std.fs.path.join(allocator, &[_][]const u8{ config_dir, "bradcypert" });
    return storage_path;
}

fn getBookmarkFilePath(allocator: *std.mem.Allocator) ![]const u8 {
    const storage_path = try getStoragePath(allocator);
    defer allocator.free(storage_path);

    const bookmark_file_path = try std.fs.path.join(allocator, &[_][]const u8{ storage_path, "bookmarks.csv" });
    return bookmark_file_path;
}

pub fn deleteBookmarkFile(allocator: *std.mem.Allocator) !void {
    const bookmark_file_path = try getBookmarkFilePath(allocator);
    defer allocator.free(bookmark_file_path);

    try std.fs.cwd().unlinkFile(bookmark_file_path);
}

fn getBookmarkFile(allocator: *std.mem.Allocator, file_mode: std.fs.File.OpenFlags) !std.fs.File {
    const bookmark_file_path = try getBookmarkFilePath(allocator);
    defer allocator.free(bookmark_file_path);

    const storage_path = try getStoragePath(allocator);
    defer allocator.free(storage_path);

    try std.fs.cwd().createDir(storage_path, std.fs.Dir.CreateDirOptions{ .mode = std.fs.constants.modePerm });

    if (std.fs.cwd().stat(bookmark_file_path)) |stat| {
        if (!stat.is_file) {
            return error.InvalidPath;
        }
    } else |err| {
        if (err != std.os.errno.ENOENT) return err;
        return std.fs.cwd().createFile(bookmark_file_path);
    }

    return std.fs.cwd().openFile(bookmark_file_path, file_mode);
}

pub fn main() void {
    const allocator = std.heap.page_allocator;

    // Example usage to delete bookmark file
    if (deleteBookmarkFile(allocator)) |err| {
        std.debug.print("Failed to delete bookmark file: {}\n", .{err});
        return;
    }
    std.debug.print("Bookmark file deleted successfully\n", .{});

    // Example usage to get bookmark file (read-only)
    const file = getBookmarkFile(allocator, .{ .read = true }) catch |err| {
        std.debug.print("Failed to get bookmark file: {}\n", .{err});
        return;
    };
    defer file.close();
    std.debug.print("Bookmark file opened successfully\n", .{});
}
