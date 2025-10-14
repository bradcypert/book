const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

pub const Bookmark = struct {
    value: []const u8,
    path: []const u8,
    tags: []const u8,
};

pub fn launch(allocator: std.mem.Allocator, bookmarks: std.MultiArrayList(Bookmark)) !void {
    var buffer: [1024]u8 = undefined;
    var tty = try vaxis.Tty.init(&buffer);
    defer tty.deinit();
    const tty_writer = tty.writer();
    var vx = try vaxis.init(allocator, .{
        .kitty_keyboard_flags = .{ .report_events = true },
    });
    defer vx.deinit(allocator, tty.writer());
    var loop: vaxis.Loop(union(enum) {
        key_press: vaxis.Key,
        winsize: vaxis.Winsize,
        table_upd,
    }) = .{ .tty = &tty, .vaxis = &vx };

    try loop.init();
    try loop.start();
    defer loop.stop();
    try vx.enterAltScreen(tty.writer());
    try vx.queryTerminal(tty.writer(), 250 * std.time.ns_per_ms);

    var cmd_input = vaxis.widgets.TextInput.init(allocator);
    defer cmd_input.deinit();

    const active_bg: vaxis.Cell.Color = .{ .rgb = .{ 64, 128, 255 } };
    const selected_bg: vaxis.Cell.Color = .{ .rgb = .{ 32, 64, 255 } };

    var demo_tbl: vaxis.widgets.Table.TableContext = .{
        .active_bg = active_bg,
        .active_fg = .{ .rgb = .{ 0, 0, 0 } },
        .row_bg_1 = .{ .rgb = .{ 8, 8, 8 } },
        .selected_bg = selected_bg,
        .header_names = .{
            .custom = &.{
                "Value",
                "Path",
                "Tags",
            },
        },
        //.header_align = .left,
        .col_indexes = .{ .by_idx = &.{ 0, 1, 2 } },
        //.col_align = .{ .by_idx = &.{ .left, .left, .center, .center, .left } },
        //.col_align = .{ .all = .center },
        //.header_borders = true,
        //.col_borders = true,
        //.col_width = .{ .static_all = 15 },
        //.col_width = .{ .dynamic_header_len = 3 },
        //.col_width = .{ .static_individual = &.{ 10, 20, 15, 25, 15 } },
        //.col_width = .dynamic_fill,
        //.y_off = 10,
    };

    // Investigate this -- what exactly is sel_rows?
    defer if (demo_tbl.sel_rows) |rows| allocator.free(rows);

    var event_arena = std.heap.ArenaAllocator.init(allocator);
    defer event_arena.deinit();
    while (true) {
        defer _ = event_arena.reset(.retain_capacity);
        defer tty_writer.flush() catch {};
        const event_alloc = event_arena.allocator();
        const event = loop.nextEvent();

        switch (event) {
            .key_press => |key| keyEvt: {
                if (key.matches('c', .{ .ctrl = true })) {
                    break;
                }

                if (key.matches('l', .{ .ctrl = true })) {
                    vx.queueRefresh();
                    break :keyEvt;
                }
                if (key.matchesAny(&.{ vaxis.Key.up, 'k' }, .{})) demo_tbl.row -|= 1;
                if (key.matchesAny(&.{ vaxis.Key.down, 'j' }, .{})) demo_tbl.row +|= 1;
                // Change Column
                if (key.matchesAny(&.{ vaxis.Key.left, 'h' }, .{})) demo_tbl.col -|= 1;
                if (key.matchesAny(&.{ vaxis.Key.right, 'l' }, .{})) demo_tbl.col +|= 1;
                if (key.matches(vaxis.Key.space, .{})) {
                    const rows = demo_tbl.sel_rows orelse createRows: {
                        demo_tbl.sel_rows = try allocator.alloc(u16, 1);
                        break :createRows demo_tbl.sel_rows.?;
                    };
                    var rows_list = std.ArrayList(u16).fromOwnedSlice(rows);
                    for (rows_list.items, 0..) |row, idx| {
                        if (row != demo_tbl.row) continue;
                        _ = rows_list.orderedRemove(idx);
                        break;
                    } else try rows_list.append(allocator, demo_tbl.row);
                    demo_tbl.sel_rows = try rows_list.toOwnedSlice(allocator);
                }
            },
            .winsize => |ws| try vx.resize(allocator, tty.writer(), ws),
            else => {},
        }

        const win = vx.window();
        win.clear();
        const middle_bar = win.child(.{
            .x_off = 0,
            .y_off = 0,
            .width = win.width,
            .height = win.height,
        });

        if (bookmarks.items(.path).len > 0) {
            demo_tbl.active = true;
            try vaxis.widgets.Table.drawTable(event_alloc, middle_bar, bookmarks, &demo_tbl);
        }

        try vx.render(tty_writer);
    }
}
