const std = @import("std");

pub const TokenizerError = error{
    InvalidValue,
    UnclosedString,
} || std.mem.Allocator.Error;

const TRUE = "true";
const FALSE = "false";
const NULL = "null";

const JsonToken = union(enum) {
    OPEN_CURLY_BRACE,
    CLOSE_CURLY_BRACE,
    OPEN_SQUARE_BRACE,
    CLOSE_SQUARE_BRACE,
    COMMA,
    COLON,
    TRUE,
    FALSE,
    NULL,
    STRING: []const u8,
    NUMBER: f32,

    const Self = @This();
    
    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        if (self == .STRING) {
            allocator.free(self.STRING);
        }
    }
};

pub const JsonTokeniser = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    pos: usize,
    peeked_value: ?JsonToken,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, input: []const u8) JsonTokeniser {
        return .{ .allocator = allocator, .input = input, .pos = 0, .peeked_value = null };
    }

    pub fn deinit(self: Self) void {
        if (self.peeked_value) |token| {
            token.deinit(self.allocator);
        }
    }

    pub fn peek(self: *Self) TokenizerError!?JsonToken {
        // We already have a token cached. Return that.
        if (self.peeked_value != null) return self.peeked_value;
        // Return null if we've parsed the whole input
        if (self.pos >= self.input.len) {
            return null;
        }
        // Skip any whitespace
        while (std.ascii.isWhitespace(self.peekInput())) {
            self.pos += 1;
        }
        // Peek the next value
        const current_char = self.peekInput();
        if (std.ascii.isDigit(current_char) or current_char == '-') {
            self.peeked_value = self.tokeniseNumber();
        } else {
            self.peeked_value = switch (current_char) {
                '"' => try self.tokeniseString(),
                't' => try self.tokeniseTrue(),
                'f' => try self.tokeniseFalse(),
                'n' => try self.tokeniseNull(),
                else => try self.tokeniseCharacter(),
            };
        }
        return self.peeked_value;
    }

    pub fn next(self: *Self) TokenizerError!?JsonToken {
        if (self.peeked_value == null) _ = try self.peek();
        const return_value = self.peeked_value;
        self.peeked_value = null;
        // Pass ownership of the token to the caller
        return return_value;
    }

    pub fn skip(self: *Self) TokenizerError!void {
        if (try self.next()) |token| token.deinit(self.allocator);
    }

    fn peekInput(self: *Self) u8 {
        return self.input[self.pos];
    }

    fn consume(self: *Self) u8 {
        const current_char = self.peekInput();
        self.pos += 1;
        return current_char;
    }

    fn tokeniseString(self: *Self) TokenizerError!JsonToken {
        // TODO support escape sequences
        // Look ahead to find the closing quote
        var offset: u32 = 1;
        while (self.input[self.pos + offset] != '"') {
            offset += 1;
            if (self.pos + offset >= self.input.len) {
                return TokenizerError.UnclosedString;
            }
        }
        // Store the string itself as part of the tagged union. Exclude the quotation marks
        const slice = self.input[self.pos + 1..self.pos + offset];
        const owned_string = try self.allocator.dupe(u8, slice);
        errdefer self.allocator.free(owned_string);
        self.pos += (offset + 1);
        return .{ .STRING = owned_string };
    }

    fn tokeniseNumber(self: *Self) JsonToken {
        // TODO extend to support numbers other than positive integers
        var offset: u32 = 1;
        while (std.ascii.isDigit(self.input[self.pos + offset])) {
            offset += 1;
            if (self.pos + offset >= self.input.len) {
                break;
            }
        }
        const slice = self.input[self.pos..self.pos + offset];
        self.pos += offset;

        return .{ .NUMBER = std.fmt.parseFloat(f32, slice) catch unreachable };
    }

    fn tokeniseTrue(self: *Self) TokenizerError!JsonToken {
        if (!self.safeCompareAhead(TRUE)) {
            return TokenizerError.InvalidValue;
        }
        self.pos += TRUE.len;
        return .TRUE;
    }

    fn tokeniseFalse(self: *Self) TokenizerError!JsonToken {
        if (!self.safeCompareAhead(FALSE)) {
            return TokenizerError.InvalidValue;
        }
        self.pos += FALSE.len;
        return .FALSE;
    }

    fn tokeniseNull(self: *Self) TokenizerError!JsonToken {
        if (!self.safeCompareAhead(NULL)) {
            return TokenizerError.InvalidValue;
        }
        self.pos += NULL.len;
        return .NULL;
    }

    fn tokeniseCharacter(self: *Self) TokenizerError!JsonToken {
        return switch (self.consume()) {
            '{' => .OPEN_CURLY_BRACE,
            '}' => .CLOSE_CURLY_BRACE,
            '[' => .OPEN_SQUARE_BRACE,
            ']' => .CLOSE_SQUARE_BRACE,
            ',' => .COMMA,
            ':' => .COLON,
            else => return TokenizerError.InvalidValue,
        };
    }

    fn safeCompareAhead(self: *Self, s: []const u8) bool {
        if (self.pos + s.len > self.input.len) return false;
        const slice = self.input[self.pos..self.pos + s.len];
        return std.mem.eql(u8, slice, s);
    }
};

//debug function
pub fn printToken(token: JsonToken) void {
    switch(token) {
        .NUMBER => std.debug.print("{s}({d})\n", .{@tagName(token), token.NUMBER}),
        .STRING => std.debug.print("{s}({s})\n", .{@tagName(token), token.STRING}),
        else => std.debug.print("{s}\n", .{@tagName(token)}),
    }
}
