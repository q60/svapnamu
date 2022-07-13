const std = @import("std");
const stdout = std.io.getStdOut().writer();

const zfetch = @import("zfetch");


pub fn main() !void {
    try zfetch.init();
    defer zfetch.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var headers = zfetch.Headers.init(allocator);
    defer headers.deinit();

    var req = try zfetch.Request.init(allocator, "http://q.veleth.cyou/quote", null);
    defer req.deinit();

    try req.do(.GET, headers, null);
    const reader = req.reader();

    var buf: [1024]u8 = undefined;
    while (true) {
        const read = try reader.read(&buf);
        if (read == 0) break;

        var quote = std.mem.split(u8, buf[0..read], "\n");
        const quote_text = try wrap(allocator, quote.next().?, 40);
        defer allocator.free(quote_text);
        const quote_author = quote.next();

        try stdout.print("\"\x1B[94m\x1B[1m{s}\x1B[0m\"\n", .{ quote_text });
        if (quote_author != null) {
            try stdout.print("\x1B[93m{s}\x1B[0m\n", .{ quote_author });
        }
    }
}


fn wrap(allocator: std.mem.Allocator, str: []const u8, max_length: usize) ![]const u8 {
    var acc: usize = 0;

    var words = std.mem.split(u8, str, " ");
    var head = words.next();

    var res: []const u8 = "";

    while (head != null) {
        const word = head.?;
        if (acc >= max_length) {
            acc = word.len;
            const text = try std.mem.concat(allocator, u8, &[_][]const u8{ res, "\n", word });
            allocator.free(res);
            res = text;
        } else {
            acc += word.len;
            const text = try std.mem.concat(allocator, u8, &[_][]const u8{ res, " ", word });
            allocator.free(res);
            res = text;
        }

        head = words.next();
    }

    return res[1..];
}
