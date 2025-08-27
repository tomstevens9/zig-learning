const std = @import("std");
const JsonTokeniser = @import("tokeniser.zig").JsonTokeniser;
const TokenizerError = @import("tokeniser.zig").TokenizerError;
const printToken = @import("tokeniser.zig").printToken;

const ParserError = error {
    UnexpectedToken,
    UnexpectedEnd, // TODO better name
} || std.mem.Allocator.Error || TokenizerError;

const JsonValue = union(enum) {
    object: std.StringHashMap(JsonValue),
    array: std.ArrayList(JsonValue),
    number: f32,
    string: []const u8,
    boolean: bool,
    null_value,
};

pub const JsonParser = struct {
    allocator: std.mem.Allocator,
    tokeniser: *JsonTokeniser,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, tokeniser: *JsonTokeniser) JsonParser {
        return JsonParser{ .allocator = allocator, .tokeniser = tokeniser };
    }

    // TODO implement deinit()

    pub fn parse(self: *Self) ParserError!JsonValue {
        return try self.parseElement();
    }

    fn parseElement(self: *Self) ParserError!JsonValue {
        std.debug.print("parseElement()\n", .{});
        const token = try self.tokeniser.next() orelse {
            return ParserError.UnexpectedEnd;
        };
        std.debug.print("parseElement() Token - ", .{});
        printToken(token);
        return switch (token) {
            .NUMBER => .{ .number = token.NUMBER },
            .STRING => JsonValue{ .string = try self.allocator.dupe(u8, token.STRING) },
            .TRUE => .{ .boolean = true },
            .FALSE => .{ .boolean = false },
            .NULL => .null_value,
            .OPEN_SQUARE_BRACE => self.parseArray(),
            .OPEN_CURLY_BRACE => self.parseObject(),
            else => ParserError.UnexpectedToken,
        };
    }

    fn parseArray(self: *Self) ParserError!JsonValue {
        std.debug.print("parseArray()\n", .{});
        var array_list = std.ArrayList(JsonValue){};
        // Handle special case of empty array
        if (try self.tokeniser.peek()) |token| {
            if (token == .CLOSE_SQUARE_BRACE) {
                _ = try self.tokeniser.next();  // Consume token
                return .{ .array = array_list};
            }
        }
        std.debug.print("parseArray() - Array not empty\n", .{});

        while(true) {
            const element = try self.parseElement();
            try array_list.append(self.allocator, element);
            const token = try self.tokeniser.peek() orelse return ParserError.UnexpectedEnd;
            switch (token) {
                .CLOSE_SQUARE_BRACE => {
                    _ = try self.tokeniser.next(); // Consume the token
                    break;
                },
                .COMMA => {
                    _ = try self.tokeniser.next(); // Consume the token
                },
                else => return ParserError.UnexpectedToken,
            }
        }
        return .{ .array = array_list};
    }

    fn parseObject(self: *Self) ParserError!JsonValue {
        std.debug.print("parseObject()\n", .{});
        var hash_map = std.StringHashMap(JsonValue).init(self.allocator);
        // Handle special case of empty object
        if (try self.tokeniser.peek()) |token| {
            if (token == .CLOSE_CURLY_BRACE) {
                _ = try self.tokeniser.next();  // Consume token
                return .{ .object = hash_map};
            }
        }
        std.debug.print("parseObject() - Object not empty\n", .{});

        while(true) {
            const key_token = try self.tokeniser.next() orelse return ParserError.UnexpectedEnd;
            const key = switch (key_token) {
                .STRING => key_token.STRING,
                else => return ParserError.UnexpectedToken,
            };
            // TODO Check that key is string
            const expected_colon_token = try self.tokeniser.next() orelse return ParserError.UnexpectedEnd;
            if (expected_colon_token != .COLON) return ParserError.UnexpectedToken;
            const value = try self.parseElement();
            try hash_map.put(key, value);
            const token = try self.tokeniser.peek() orelse return ParserError.UnexpectedEnd;
            switch (token) {
                .CLOSE_CURLY_BRACE => {
                    _ = try self.tokeniser.next(); // Consume the token
                    break;
                },
                .COMMA => {
                    _ = try self.tokeniser.next(); // Consume the token
                },
                else => return ParserError.UnexpectedToken,
            }
        }
        return .{ .object = hash_map};
    }
};
