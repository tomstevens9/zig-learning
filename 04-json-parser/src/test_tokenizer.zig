const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const TokenizerError = @import("tokenizer.zig").TokenizerError;

const SQRT_EPS_VALUE = @sqrt(std.math.floatEps(f32));

// Test basic tokenization
test "tokenize single characters" {
    const input_string = "{}[],:";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const expected_tokens = [_]Token{
        .OPEN_CURLY_BRACE,
        .CLOSE_CURLY_BRACE,
        .OPEN_SQUARE_BRACE,
        .CLOSE_SQUARE_BRACE,
        .COMMA,
        .COLON,
    };

    for (expected_tokens) |expected_token| {
        const token = try tokenizer.next() orelse unreachable;
        defer token.deinit(std.testing.allocator);

        try std.testing.expectEqual(expected_token, token);
    }
}

test "tokenize keywords" {
    const input_string = "true false null";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const expected_tokens = [_]Token{
        .TRUE,
        .FALSE,
        .NULL,
    };

    for (expected_tokens) |expected_token| {
        const token = try tokenizer.next() orelse unreachable;
        defer token.deinit(std.testing.allocator);

        try std.testing.expectEqual(expected_token, token);
    }
}

test "tokenize string" {
    const input_string = "\"Hello, World!\"";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;
    defer token.deinit(std.testing.allocator);

    switch (token) {
        .STRING => |str| try std.testing.expect(std.mem.eql(u8, str, "Hello, World!")),
        else => try std.testing.expect(false),
    }
}

test "tokenize number" {
    const input_string = "123";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;

    try std.testing.expectEqual(Token{ .NUMBER = 123 }, token);
}

test "tokenize unexpected character" {
    const input_string = "A";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    try std.testing.expectError(TokenizerError.UnexpectedCharacter, tokenizer.next());
}

// Detailed number parsing tests
test "tokenize positive integer" {
    const input_string = "123";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;

    try std.testing.expectEqual(123, token.NUMBER);
}

test "tokenize negative integer" {
    const input_string = "-123";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;

    try std.testing.expectEqual(-123, token.NUMBER);
}

test "tokenize zero" {
    const input_string = "0";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;

    try std.testing.expectEqual(0, token.NUMBER);
}

test "tokenize positive fraction" {
    const input_string = "12.3";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;

    try std.testing.expectEqual(12.3, token.NUMBER);
}

test "tokenize negative fraction" {
    const input_string = "-12.3";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;

    try std.testing.expectEqual(-12.3, token.NUMBER);
}

test "tokenize zero as fraction" {
    const input_string = "0.0";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;

    try std.testing.expectEqual(0.0, token.NUMBER);
}

test "tokenize implictly positive exponent" {
    const input_string = "12.3e2";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;

    try std.testing.expectEqual(1230, token.NUMBER);
}

test "tokenize explicitly positive exponent" {
    const input_string = "12.3e+2";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;

    try std.testing.expectEqual(1230, token.NUMBER);
}

test "tokenize negative exponent" {
    const input_string = "12.3e-2";

    var tokenizer = Tokenizer.init(std.testing.allocator, input_string);
    defer tokenizer.deinit();

    const token = try tokenizer.next() orelse unreachable;

    try std.testing.expectApproxEqRel(0.123, token.NUMBER, SQRT_EPS_VALUE);
}

// Detailed string parsing
test "tokenize escape sequences" {
    
    const test_data = [_][2][]const u8{
        // input string, expected tokenized string
        .{ "\"\\\"\"", "\"" },
        .{ "\"\\\\\"", "\\" },
        .{ "\"\\/\"", "/" },
        .{ "\"\\b\"", "\x08" },
        .{ "\"\\t\"", "\t" },
        .{ "\"\\n\"", "\n" },
        .{ "\"\\f\"", "\x0c" },
        .{ "\"\\r\"", "\r" },
    };

    for (test_data) |row| {
        var tokenizer = Tokenizer.init(std.testing.allocator, row[0]);
        defer tokenizer.deinit();

        const token = try tokenizer.next() orelse unreachable;
        defer token.deinit(std.testing.allocator);

        try std.testing.expectEqualStrings(row[1], token.STRING);
    }

}
