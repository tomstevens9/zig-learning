const std = @import("std");
const Allocator = std.mem.Allocator;

pub const StringParserError = error{
    MalformedUtf8String,
    MalformedUnicodeEscape,
    InvalidEscapeSequence,
    InvalidHexDigit,
} || Allocator.Error;

pub fn parse(allocator: Allocator, s: []const u8) StringParserError![]const u8 {
    // 1. Decode the input string.
    const decoded_s = try decodeUtf8String(allocator, s);
    defer allocator.free(decoded_s);
    // 2. Handle escape characters
    const processed_s = try handleEscapeSequences(allocator, decoded_s);
    defer allocator.free(processed_s);
    // 3. Re-encode the string before returning
    const encoded_s = try encodeUtf8String(allocator, processed_s);
    return encoded_s;
}

fn decodeUtf8String(allocator: Allocator, s: []const u8) StringParserError![]const u21 {
    //
    var pos: usize = 0;
    var string_builder = std.ArrayList(u21){};
    defer string_builder.deinit(allocator);

    while (pos < s.len) {
        const utf8_chr = s[pos];
        const cp_len = std.unicode.utf8ByteSequenceLength(utf8_chr) catch return StringParserError.MalformedUtf8String;
        if (pos + cp_len > s.len) return StringParserError.MalformedUtf8String;
        const bytes = s[pos .. pos + cp_len];
        const cp = std.unicode.utf8Decode(bytes) catch return StringParserError.MalformedUtf8String;
        try string_builder.append(allocator, cp);
        pos += cp_len;
    }
    return try allocator.dupe(u21, string_builder.items);
}

fn decodeUtf8Character(bytes: []const u8) u21 {
    return switch (bytes.len) {
        1 => @as(u21, bytes[0]),
        2 => std.unicode.utf8Decode2(bytes) catch unreachable,
        3 => std.unicode.utf8Decode3(bytes) catch unreachable,
        4 => std.unicode.utf8Decode4(bytes) catch unreachable,
        else => unreachable,
    };
}

fn handleEscapeSequences(allocator: Allocator, s: []const u21) StringParserError![]const u21 {
    var pos: usize = 0;
    var string_builder = std.ArrayList(u21){};
    defer string_builder.deinit(allocator);

    while (pos < s.len) {
        const c = s[pos];
        // Not an escape sequence. Add current character to string
        // builder and continue loop.
        if (c != '\\') {
            try string_builder.append(allocator, c);
            pos += 1;
            continue;
        }
        pos += 1;
        const escape_chr = s[pos];
        if (escape_chr == 'u') {
            pos += 1;
            if (pos + 4 > s.len) return StringParserError.InvalidEscapeSequence;
            const cp = try processUnicodeHexDigits(s[pos .. pos + 4]);
            try string_builder.append(allocator, cp);
            pos += 4;
        } else {
            const escaped_chr: u21 = switch (escape_chr) {
                '"' => '"',
                '\\' => '\\',
                '/' => '/',
                'b' => '\x08', // backspace
                't' => '\t',
                'n' => '\n',
                'f' => '\x0c', // formfeed
                'r' => '\r',
                else => return StringParserError.InvalidEscapeSequence,
            };
            try string_builder.append(allocator, escaped_chr);
            pos += 1;
        }
    }
    return try allocator.dupe(u21, string_builder.items);
}

fn processUnicodeHexDigits(hex_digits: []const u21) StringParserError!u21 {
    var result: u21 = 0;
    var multiplier: u21 = 4096;
    for (hex_digits) |cp| {
        result += multiplier * try hexDigitToInt(cp);
        multiplier /= 16;
    }
    return result;
}

fn hexDigitToInt(c: u21) StringParserError!u21 {
    const truncated_c: u8 = @truncate(c);
    if (std.ascii.isDigit(truncated_c)) return c - 48;
    return switch (std.ascii.toLower(truncated_c)) {
        'a' => 10,
        'b' => 11,
        'c' => 12,
        'd' => 13,
        'e' => 14,
        'f' => 15,
        else => StringParserError.InvalidHexDigit,
    };
}

fn encodeUtf8String(allocator: Allocator, s: []const u21) StringParserError![]const u8 {
    var string_builder = std.ArrayList(u8){};
    defer string_builder.deinit(allocator);

    const buf: []u8 = try allocator.alloc(u8, 4);
    for (s) |cp| {
        const no_bytes_written = std.unicode.utf8Encode(cp, buf) catch return StringParserError.MalformedUnicodeEscape;
        try string_builder.appendSlice(allocator, buf[0..no_bytes_written]);
    }
    return allocator.dupe(u8, string_builder.items);
}
