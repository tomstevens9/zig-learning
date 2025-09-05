const std = @import("std");
const Allocator = std.mem.Allocator;
const tokenizer = @import("tokenizer.zig");
const Tokenizer = tokenizer.Tokenizer;
const TokenizerError = tokenizer.TokenizerError;
const string_parser = @import("string_parser.zig");
const StringParserError = string_parser.StringParserError;
const NumberParser = @import("number_parser.zig").NumberParser;

const ParserError = error{
    UnexpectedToken,
    UnexpectedEndOfInput,
    InvalidHexDigit,
    MalformedUtf8,
    MalformedUnicodeEscape,
    InvalidEscapeSequence,
} || Allocator.Error || TokenizerError || StringParserError;

const JsonValue = union(enum) {
    object: std.StringHashMap(JsonValue),
    array: std.ArrayList(JsonValue),
    number: f32,
    string: []const u8,
    boolean: bool,
    null_value,

    const Self = @This();

    pub fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.*) {
            .object => |*obj| {
                var iterator = obj.iterator();
                while (iterator.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                obj.deinit();
            },
            .array => |*arr| {
                for (arr.items) |*item| item.deinit(allocator);
                arr.deinit(allocator);
            },
            .string => |str| allocator.free(str),
            else => return,
        }
    }
};

fn parseNumber(input: []const u8) f32 {
    var number_parser = NumberParser.init(input);
    return number_parser.parse();
}

const JsonParser = struct {
    allocator: Allocator,
    tokeniser: Tokenizer,

    const Self = @This();

    pub fn init(allocator: Allocator, tokeniser: Tokenizer) JsonParser {
        return JsonParser{ .allocator = allocator, .tokeniser = tokeniser };
    }

    pub fn parse(self: *Self) ParserError!JsonValue {
        return try self.parseElement();
    }

    fn parseElement(self: *Self) ParserError!JsonValue {
        const token = try self.tokeniser.next() orelse return ParserError.UnexpectedEndOfInput;
        return switch (token) {
            .NUMBER => .{ .number = parseNumber(token.NUMBER) },
            .STRING => {
                return JsonValue{ .string = try string_parser.parse(self.allocator, token.STRING) };
            },
            .TRUE => .{ .boolean = true },
            .FALSE => .{ .boolean = false },
            .NULL => .null_value,
            .OPEN_SQUARE_BRACE => self.parseArray(),
            .OPEN_CURLY_BRACE => self.parseObject(),
            else => ParserError.UnexpectedToken,
        };
    }

    fn parseArray(self: *Self) ParserError!JsonValue {
        var array_list = std.ArrayList(JsonValue){};
        // Handle special case of empty array
        if (try self.tokeniser.peek()) |token| {
            if (token == .CLOSE_SQUARE_BRACE) {
                try self.tokeniser.skip(); // Consume token
                return .{ .array = array_list };
            }
        }

        while (true) {
            const element = try self.parseElement();
            try array_list.append(self.allocator, element);
            const token = try self.tokeniser.peek() orelse return ParserError.UnexpectedEndOfInput;
            switch (token) {
                .CLOSE_SQUARE_BRACE => {
                    try self.tokeniser.skip();
                    break;
                },
                .COMMA => try self.tokeniser.skip(),
                else => return ParserError.UnexpectedToken,
            }
        }
        return .{ .array = array_list };
    }

    fn parseObject(self: *Self) ParserError!JsonValue {
        var hash_map = std.StringHashMap(JsonValue).init(self.allocator);
        errdefer hash_map.deinit();

        // Handle special case of empty object
        if (try self.tokeniser.peek()) |token| {
            if (token == .CLOSE_CURLY_BRACE) {
                try self.tokeniser.skip();
                return .{ .object = hash_map };
            }
        }

        while (true) {
            const key_token = try self.tokeniser.next() orelse return ParserError.UnexpectedEndOfInput;
            const key = switch (key_token) {
                .STRING => try self.allocator.dupe(u8, key_token.STRING),
                else => return ParserError.UnexpectedToken,
            };
            errdefer self.allocator.free(key);
            const expected_colon_token = try self.tokeniser.next() orelse return ParserError.UnexpectedEndOfInput;
            if (expected_colon_token != .COLON) return ParserError.UnexpectedToken;
            var value = try self.parseElement();
            errdefer value.deinit(self.allocator);
            try hash_map.put(key, value);
            const token = try self.tokeniser.peek() orelse return ParserError.UnexpectedEndOfInput;
            switch (token) {
                .CLOSE_CURLY_BRACE => {
                    try self.tokeniser.skip();
                    break;
                },
                .COMMA => try self.tokeniser.skip(),
                else => return ParserError.UnexpectedToken,
            }
        }
        return .{ .object = hash_map };
    }
};

pub fn parse(allocator: Allocator, input: []const u8) ParserError!JsonValue {
    const tokeniser = Tokenizer.init(input);
    var parser = JsonParser.init(allocator, tokeniser);
    return parser.parse();
}
