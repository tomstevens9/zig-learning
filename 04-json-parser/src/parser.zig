const std = @import("std");
const tokenizer = @import("tokenizer.zig");
const Tokenizer = tokenizer.Tokenizer;
const TokenizerError = tokenizer.TokenizerError;
const string_parser = @import("string_parser.zig");
const StringParserError = string_parser.StringParserError;

const ParserError = error{
    UnexpectedToken,
    UnexpectedEndOfInput,
    InvalidHexDigit,
    MalformedUtf8,
    MalformedUnicodeEscape,
    InvalidEscapeSequence,
} || std.mem.Allocator.Error || TokenizerError || StringParserError;

const JsonValue = union(enum) {
    object: std.StringHashMap(JsonValue),
    array: std.ArrayList(JsonValue),
    number: f32,
    string: []const u8,
    boolean: bool,
    null_value,

    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
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

const NumberParser = struct {
    input: []const u8,
    pos: usize,

    const Self = @This();

    pub fn init(input: []const u8) NumberParser {
        return NumberParser{ .input = input, .pos = 0 };
    }

    fn peek(self: *Self) ?u8 {
        if (self.pos >= self.input.len) return null;
        return self.input[self.pos];
    }

    fn consume(self: *Self) ?u8 {
        const c = self.peek() orelse return null;
        self.pos += 1;
        return c;
    }

    fn parse(self: *Self) f32 {
        const sign_multiplier: f32 = if (self.peek().? == '-') -1.0 else 1.0;
        if (sign_multiplier == -1.0) {
            _ = self.consume();
        }
        // Parse whole part
        const whole_part = self.parseWholePart();
        // Parse fraction part (if present)
        const fraction_part = self.parseFractionPart();
        // Parse exponent part (if present)
        const exponent_part = self.parseExponentPart();
        // Bring it all together
        return sign_multiplier * ((whole_part + fraction_part) * std.math.pow(f32, 10, exponent_part));
    }

    fn parseWholePart(self: *Self) f32 {
        var whole_part: f32 = 0.0;
        // Validated number is guaranteed to have some whole part
        const is_zero = (self.peek().?) == '0';
        if (is_zero) {
            _ = self.consume();
        } else {
            while (self.peek()) |char| {
                if (!std.ascii.isDigit(char)) break;
                _ = self.consume();
                const value: f32 = @floatFromInt(char - 48);
                whole_part *= 10.0;
                whole_part += value;
            }
        }
        return whole_part;
    }

    fn parseFractionPart(self: *Self) f32 {
        var fraction_part: f32 = 0.0;
        const contains_fraction_part = if (self.peek()) |char| char == '.' else false;
        if (!contains_fraction_part) return fraction_part;

        // Consume the decimal
        _ = self.consume();
        // Parse the digits
        var coefficient: f32 = 0.1;
        while (self.peek()) |char| {
            if (!std.ascii.isDigit(char)) break;
            _ = self.consume();
            const value: f32 = @floatFromInt(char - 48);
            fraction_part += (value * coefficient);
            coefficient *= 0.1;
        }
        return fraction_part;
    }

    fn parseExponentPart(self: *Self) f32 {
        var exponent_part: f32 = 0.0;
        const contains_exponent_part = if (self.peek()) |char| (std.ascii.toLower(char) == 'e') else false;
        if (!contains_exponent_part) return exponent_part;

        // Consume the exponent symbol
        _ = self.consume();
        // There can be a sign after the exponent part
        const exponent_sign_multiplier: f32 = if ((self.peek().?) == '-') -1.0 else 1.0;
        if (self.peek()) |char| {
            if (char == '-' or char == '+') _ = self.consume();
        }
        // There has to be at least one digit after exponent
        // Parse the digits
        while (self.peek()) |char| {
            if (!std.ascii.isDigit(char)) break;
            _ = self.consume();
            const value: f32 = @floatFromInt(char - 48);
            exponent_part *= 10.0;
            exponent_part += value;
        }
        exponent_part *= exponent_sign_multiplier;
        return exponent_part;
    }
};

fn parseNumber(input: []const u8) f32 {
    var number_parser = NumberParser.init(input);
    return number_parser.parse();
}

const JsonParser = struct {
    allocator: std.mem.Allocator,
    tokeniser: Tokenizer,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, tokeniser: Tokenizer) JsonParser {
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

pub fn parse(allocator: std.mem.Allocator, input: []const u8) ParserError!JsonValue {
    const tokeniser = Tokenizer.init(input);
    var parser = JsonParser.init(allocator, tokeniser);
    return parser.parse();
}
