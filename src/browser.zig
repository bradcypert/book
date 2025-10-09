const std = @import("std");
const builtin = @import("builtin");

/// Open a path or URL in the system's default application.
/// On Linux: uses xdg-open
/// On Windows: uses rundll32 for URLs, explorer for files
/// On macOS: uses open
pub fn openExternal(path: []const u8) !void {
    const result = switch (builtin.os.tag) {
        .linux => try std.process.Child.run(.{
            .allocator = std.heap.page_allocator,
            .argv = &[_][]const u8{ "xdg-open", path },
        }),
        .windows => blk: {
            // Check if it's a URL (starts with http:// or https://)
            const is_url = std.mem.startsWith(u8, path, "http://") or
                std.mem.startsWith(u8, path, "https://");

            if (is_url) {
                break :blk try std.process.Child.run(.{
                    .allocator = std.heap.page_allocator,
                    .argv = &[_][]const u8{ "rundll32", "url.dll,FileProtocolHandler", path },
                });
            } else {
                break :blk try std.process.Child.run(.{
                    .allocator = std.heap.page_allocator,
                    .argv = &[_][]const u8{ "explorer", "/select,", path },
                });
            }
        },
        .macos => try std.process.Child.run(.{
            .allocator = std.heap.page_allocator,
            .argv = &[_][]const u8{ "open", path },
        }),
        else => return error.UnsupportedPlatform,
    };

    defer std.heap.page_allocator.free(result.stdout);
    defer std.heap.page_allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        return error.CommandFailed;
    }
}

test "openExternal URL detection" {
    const testing = std.testing;

    // Test URL detection logic
    const url1 = "https://github.com";
    const url2 = "http://example.com";
    const file_path = "/home/user/file.txt";

    try testing.expect(std.mem.startsWith(u8, url1, "http://") or std.mem.startsWith(u8, url1, "https://"));
    try testing.expect(std.mem.startsWith(u8, url2, "http://") or std.mem.startsWith(u8, url2, "https://"));
    try testing.expect(!(std.mem.startsWith(u8, file_path, "http://") or std.mem.startsWith(u8, file_path, "https://")));
}
