const std = @import("std");
const stdout = std.io.getStdOut().writer();

const zfetch = @import("zfetch");


pub fn main() !void {
    var buffer: [0x5000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    try zfetch.init();
    defer zfetch.deinit();

    var headers = zfetch.Headers.init(allocator);
    defer headers.deinit();

    var request = try zfetch.Request.init(allocator, "http://q.veleth.cyou/quote", null);
    defer request.deinit();

    try request.do(.GET, headers, null);
    const reader = request.reader();

    var buf: [0x400]u8 = undefined;

    while (true) {
        const read = try reader.read(&buf);
        if (read == 0) break;

        var quote = std.mem.split(u8, buf[0..read], "\n");
        const quote_text = try wrap(allocator, quote.next().?, 40);
        defer allocator.free(quote_text);
        const quote_author = quote.next();

        try stdout.print("\"\x1B[94m\x1B[1m{s}\x1B[0m\"\n", .{quote_text});

        if (quote_author != null) {
            try stdout.print("\x1B[93m{s}\x1B[0m\n", .{quote_author});
        }
    }
}


fn wrap(allocator: std.mem.Allocator, string: []const u8, max_length: usize) ![]u8 {
    var words = std.mem.split(u8, string, " ");
    var head = words.next();

    var acc: usize = 0;
    var total_length: usize = 0;

    var result = try allocator.alloc(u8, string.len + 1);

    while (head != null) {
        const word = head.?;
        const word_length = word.len;

        if (acc >= max_length) {
            acc = word_length;
            result[total_length + word_length] = '\n';
        } else {
            acc += word_length;
            result[total_length + word_length] = ' ';
        }

        for (word) |char, i| {
            result[i + total_length] = char;
        }

        total_length += word_length + 1;
        head = words.next();
    }

    return result[0..string.len];
}
