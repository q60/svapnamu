const std = @import("std");
const http = std.http;
const json = std.json;
const stdout = std.io.getStdOut().writer();

const quotes_uri = "https://api.forismatic.com/api/1.0/?method=getQuote&format=json&lang=en";
const max_text_length = 45;

const Quote = struct {
    quoteText: []u8,
    quoteAuthor: []u8,
};

pub fn main() !u8 {
    // thread-safe allocator for http client and everything else
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const quote_json = get_quote(allocator, quotes_uri) catch {
        try stdout.print("http request has failed\n", .{});

        return 1;
    };
    defer allocator.free(quote_json);

    if (parse_quote(allocator, quote_json)) |quote_parsed| {
        defer quote_parsed.deinit();
        const quote = quote_parsed.value;

        const text = try wrap_string(allocator, quote.quoteText, max_text_length);
        defer allocator.free(text);
        const author = quote.quoteAuthor;

        // this api loves to respond with junk
        const text_trimmed = std.mem.trim(u8, text, " \n");
        const author_trimmed = std.mem.trim(u8, author, " \n");

        try stdout.print("\"\x1B[94m\x1B[1m{s}\x1B[0m\"\n", .{text_trimmed});
        if (author_trimmed.len != 0) {
            try stdout.print("\x1B[93m{s}\x1B[0m\n", .{author_trimmed});
        }

        return 0;
    } else |err| switch (err) {
        // this api is literally garbage
        json.Error.SyntaxError => {
            try stdout.print("failed to parse response from the API\n", .{});

            return 1;
        },
        else => |other_error| return other_error,
    }
}

fn get_quote(allocator: std.mem.Allocator, api_uri: []const u8) ![]u8 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(api_uri);
    const headers_buffer = try allocator.alloc(u8, 0x400);
    defer allocator.free(headers_buffer);

    var request = try client.open(.GET, uri, .{
        .server_header_buffer = headers_buffer,
    });
    defer request.deinit();

    try request.send();
    try request.finish();
    try request.wait();

    var request_reader = request.reader();
    const body = try request_reader.readAllAlloc(allocator, 0x200);

    return body;
}

fn parse_quote(allocator: std.mem.Allocator, json_string: []const u8) !json.Parsed(Quote) {
    const parsed_quote = try json.parseFromSlice(Quote, allocator, json_string, .{
        .ignore_unknown_fields = true,
    });

    return parsed_quote;
}

fn wrap_string(allocator: std.mem.Allocator, string: []const u8, max_length: usize) ![]u8 {
    var words = std.mem.split(u8, string, " ");
    var head = words.next();

    var acc: usize = 0;
    var total_length: usize = 0;

    var result = try allocator.alloc(u8, string.len);

    while (head != null) {
        const word = head.?;
        const word_length = word.len;

        if (total_length + word_length < string.len) {
            if (acc >= max_length) {
                acc = word_length;
                result[total_length + word_length] = '\n';
            } else {
                acc += word_length + 1;
                result[total_length + word_length] = ' ';
            }
        }

        for (word, 0..) |char, i| {
            result[i + total_length] = char;
        }

        total_length += word_length + 1;
        head = words.next();
    }

    return result;
}
