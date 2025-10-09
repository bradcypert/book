const std = @import("std");

/// File open modes matching Go's os.O_* constants
pub const FileMode = enum {
    read_only, // os.O_RDONLY
    write_only, // os.O_WRONLY
    read_write, // os.O_RDWR
    append, // os.O_APPEND | os.O_WRONLY
    append_read_write, // os.O_APPEND | os.O_RDWR
};

fn getStoragePath(allocator: std.mem.Allocator) ![]const u8 {
    return std.fs.getAppDataDir(allocator, "bradcypert.book");
}

pub fn getBookmarkFilePath(allocator: std.mem.Allocator) ![]const u8 {
    const storage_path = try getStoragePath(allocator);
    defer allocator.free(storage_path);
    return std.fs.path.join(allocator, &.{ storage_path, "bookmarks.csv" });
}

pub fn deleteBookmarkFile(allocator: std.mem.Allocator) !void {
    const path = try getBookmarkFilePath(allocator);
    defer allocator.free(path);

    return std.fs.cwd().deleteFile(path);
}

pub fn getBookmarkFile(allocator: std.mem.Allocator, mode: FileMode) !std.fs.File {
    const path = try getBookmarkFilePath(allocator);
    defer allocator.free(path);
    
    const storage_path = try getStoragePath(allocator);
    defer allocator.free(storage_path);

    // Create storage directory if it doesn't exist
    std.fs.cwd().makePath(storage_path) catch |err| switch (err) {
        error.PathAlreadyExists => {}, // This is fine
        else => return err,
    };

    // Check if file exists
    const file_exists = blk: {
        std.fs.cwd().access(path, .{}) catch |err| switch (err) {
            error.FileNotFound => break :blk false,
            else => return err,
        };
        break :blk true;
    };

    // If file doesn't exist, create it
    if (!file_exists) {
        const file = try std.fs.cwd().createFile(path, .{ .read = true });
        return file;
    }

    // File exists, open it with the appropriate mode
    return switch (mode) {
        .read_only => try std.fs.cwd().openFile(path, .{ .mode = .read_only }),
        .write_only => try std.fs.cwd().openFile(path, .{ .mode = .write_only }),
        .read_write => try std.fs.cwd().openFile(path, .{ .mode = .read_write }),
        .append => blk: {
            const file = try std.fs.cwd().openFile(path, .{ .mode = .write_only });
            try file.seekFromEnd(0);
            break :blk file;
        },
        .append_read_write => blk: {
            const file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
            try file.seekFromEnd(0);
            break :blk file;
        },
    };
}

test "getBookmarkFilePath" {
    const testing = std.testing;
    const path = try getBookmarkFilePath(testing.allocator);
    defer testing.allocator.free(path);

    // Should end with bookmarks.csv
    try testing.expect(std.mem.endsWith(u8, path, "bookmarks.csv"));
    // Should contain the app directory
    try testing.expect(std.mem.indexOf(u8, path, "bradcypert.book") != null);
}

test "getBookmarkFile creates directory and file" {
    const testing = std.testing;
    
    // Get a temporary test path
    const test_file_path = try getBookmarkFilePath(testing.allocator);
    defer testing.allocator.free(test_file_path);
    
    // Clean up any existing test file
    std.fs.cwd().deleteFile(test_file_path) catch {};
    
    // Create the file
    const file = try getBookmarkFile(testing.allocator, .read_write);
    defer file.close();
    
    // Verify file exists and is accessible
    const file_stat = try file.stat();
    try testing.expect(file_stat.size >= 0);
    
    // Clean up
    std.fs.cwd().deleteFile(test_file_path) catch {};
}

test "getBookmarkFile different modes" {
    const testing = std.testing;
    
    const test_file_path = try getBookmarkFilePath(testing.allocator);
    defer testing.allocator.free(test_file_path);
    
    // Clean up any existing test file
    std.fs.cwd().deleteFile(test_file_path) catch {};
    
    // Create file with write mode
    {
        const file = try getBookmarkFile(testing.allocator, .write_only);
        defer file.close();
        try file.writeAll("test,data,\n");
    }
    
    // Read file with read mode
    {
        const file = try getBookmarkFile(testing.allocator, .read_only);
        defer file.close();
        var buffer: [100]u8 = undefined;
        const bytes_read = try file.readAll(&buffer);
        try testing.expectEqualStrings("test,data,\n", buffer[0..bytes_read]);
    }
    
    // Append to file with append mode
    {
        const file = try getBookmarkFile(testing.allocator, .append);
        defer file.close();
        try file.writeAll("more,data,\n");
    }
    
    // Verify appended data
    {
        const file = try getBookmarkFile(testing.allocator, .read_only);
        defer file.close();
        var buffer: [100]u8 = undefined;
        const bytes_read = try file.readAll(&buffer);
        try testing.expectEqualStrings("test,data,\nmore,data,\n", buffer[0..bytes_read]);
    }
    
    // Clean up
    std.fs.cwd().deleteFile(test_file_path) catch {};
}


