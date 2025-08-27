const std = @import("std");
const JsonTokeniser = @import("tokeniser.zig").JsonTokeniser;
const TokenizerError = @import("tokeniser.zig").TokenizerError;

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

    const Self = @This();

    // TODO implement deinit()
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        switch(self.*) {
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

const JsonParser = struct {
    allocator: std.mem.Allocator,
    tokeniser: *JsonTokeniser,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, tokeniser: *JsonTokeniser) JsonParser {
        return JsonParser{ .allocator = allocator, .tokeniser = tokeniser };
    }

    pub fn parse(self: *Self) ParserError!JsonValue {
        return try self.parseElement();
    }

    fn parseElement(self: *Self) ParserError!JsonValue {
        var token = try self.tokeniser.next() orelse {
            return ParserError.UnexpectedEnd;
        };
        defer token.deinit(self.allocator);
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
        var array_list = std.ArrayList(JsonValue){};
        // Handle special case of empty array
        if (try self.tokeniser.peek()) |token| {
            if (token == .CLOSE_SQUARE_BRACE) {
                try self.tokeniser.skip();  // Consume token
                return .{ .array = array_list};
            }
        }

        while(true) {
            const element = try self.parseElement();
            try array_list.append(self.allocator, element);
            const token = try self.tokeniser.peek() orelse return ParserError.UnexpectedEnd;
            switch (token) {
                .CLOSE_SQUARE_BRACE => {
                    try self.tokeniser.skip();
                    break;
                },
                .COMMA => try self.tokeniser.skip(),
                else => return ParserError.UnexpectedToken,
            }
        }
        return .{ .array = array_list};
    }

    fn parseObject(self: *Self) ParserError!JsonValue {
        var hash_map = std.StringHashMap(JsonValue).init(self.allocator);
        errdefer hash_map.deinit();

        // Handle special case of empty object
        if (try self.tokeniser.peek()) |token| {
            if (token == .CLOSE_CURLY_BRACE) {
                try self.tokeniser.skip();
                return .{ .object = hash_map};
            }
        }

        while(true) {
            const key_token = try self.tokeniser.next() orelse return ParserError.UnexpectedEnd;
            defer key_token.deinit(self.allocator);
            const key = switch (key_token) {
                .STRING => try self.allocator.dupe(u8, key_token.STRING),
                else => return ParserError.UnexpectedToken,
            };
            errdefer self.allocator.free(key);
            const expected_colon_token = try self.tokeniser.next() orelse return ParserError.UnexpectedEnd;
            defer expected_colon_token.deinit(self.allocator);
            if (expected_colon_token != .COLON) return ParserError.UnexpectedToken;
            const value = try self.parseElement();
            try hash_map.put(key, value);
            const token = try self.tokeniser.peek() orelse return ParserError.UnexpectedEnd;
            switch (token) {
                .CLOSE_CURLY_BRACE => {
                    try self.tokeniser.skip();
                    break;
                },
                .COMMA => try self.tokeniser.skip(),
                else => return ParserError.UnexpectedToken,
            }
        }
        return .{ .object = hash_map};
    }
};

pub fn parse(allocator: std.mem.Allocator, input: []const u8) ParserError!JsonValue {
    var tokeniser = JsonTokeniser.init(allocator, input);
    tokeniser.deinit();
    var parser = JsonParser.init(allocator, &tokeniser);
    return parser.parse();
}
