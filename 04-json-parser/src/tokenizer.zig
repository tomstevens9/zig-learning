const std = @import("std");

pub const TokenizerError = error{
    InvalidValue,
    UnexpectedCharacter,
    InvalidNumber,
    UnclosedString,
} || std.mem.Allocator.Error;

const TRUE = "true";
const FALSE = "false";
const NULL = "null";

pub const Token = union(enum) {
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

pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    pos: usize,
    next_token: ?Token,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Tokenizer {
        return .{ .allocator = allocator, .input = input, .pos = 0, .next_token = null };
    }

    pub fn deinit(self: Self) void {
        if (self.next_token) |token| {
            token.deinit(self.allocator);
        }
    }

    pub fn peek(self: *Self) TokenizerError!?Token {
        // We already have a token cached. Return that.
        if (self.next_token != null) return self.next_token;
        // Return null if we've parsed the whole input
        if (self.pos >= self.input.len) {
            return null;
        }
        // Skip any whitespace
        while (std.ascii.isWhitespace(self.peekChar() orelse return null)) {
            self.pos += 1;
        }
        // Peek the next value
        if (self.nextTokenIsNumber()) {
            self.next_token = try self.tokenizeNumber();
        } else {
            self.next_token = switch (self.peekChar() orelse return null) {
                '"' => try self.tokenizeString(),
                't' => try self.tokenizeTrue(),
                'f' => try self.tokenizeFalse(),
                'n' => try self.tokenizeNull(),
                else => try self.tokenizeCharacter(),
            };
        }
        return self.next_token;
    }

    pub fn next(self: *Self) TokenizerError!?Token {
        if (self.next_token == null) _ = try self.peek();
        const return_value = self.next_token;
        self.next_token = null;
        // Pass ownership of the token to the caller
        return return_value;
    }

    pub fn skip(self: *Self) TokenizerError!void {
        if (try self.next()) |token| token.deinit(self.allocator);
    }

    fn peekChar(self: *Self) ?u8 {
        if (self.pos >= self.input.len) return null;
        return self.input[self.pos];
    }

    fn consumeChar(self: *Self) ?u8 {
        const current_char = self.peekChar() orelse return null; // TODO Could just use .?
        self.pos += 1;
        return current_char;
    }

    fn tokenizeString(self: *Self) TokenizerError!Token {
        // TODO support escape sequences
        // Look ahead to find the closing quote
        var offset: usize = 1;
        while (self.input[self.pos + offset] != '"') {
            offset += 1;
            if (self.pos + offset >= self.input.len) {
                return TokenizerError.UnclosedString;
            }
        }
        // Store the string itself as part of the tagged union. Exclude the quotation marks
        const slice = self.input[self.pos + 1 .. self.pos + offset];
        const owned_string = try self.allocator.dupe(u8, slice);
        errdefer self.allocator.free(owned_string);
        self.pos += (offset + 1);
        return .{ .STRING = owned_string };
    }

    fn nextTokenIsNumber(self: *Self) bool {
        if (self.peekChar()) |char| {
            return (std.ascii.isDigit(char) or char == '-');
        }
        return false;
    }

    fn tokenizeNumber(self: *Self) TokenizerError!Token {
        // Check whether number is negative and consume '-' if it is
        // Note: We trust that the first char will not be null because it
        // is what determined the next token was a number
        const sign_multiplier: f32 = if (self.peekChar().? == '-') -1.0 else 1.0;
        if (sign_multiplier == -1.0) {
            _ = self.consumeChar();
        }
        // Parse whole part
        const whole_part = try self.tokenizeNumberWholePart();
        // Parse fraction part (if present)
        const fraction_part = try self.tokenizeNumberFractionPart();
        // Parse exponent part (if present)
        const exponent_part = try self.tokenizeNumberExponentPart();
        // Bring it all together
        const result = sign_multiplier * ((whole_part + fraction_part) * std.math.pow(f32, 10, exponent_part));
        return .{ .NUMBER = result };
    }

    fn tokenizeNumberWholePart(self: *Self) TokenizerError!f32 {
        var whole_part: f32 = 0.0;
        const is_zero = (self.peekChar() orelse return TokenizerError.InvalidNumber) == '0';
        if (is_zero) {
            _ = self.consumeChar();
        } else {
            while (self.peekChar()) |char| {
                if (!std.ascii.isDigit(char)) break;
                _ = self.consumeChar();
                const value: f32 = @as(f32, @floatFromInt(char)) - @as(f32, 48.0);
                whole_part *= 10.0;
                whole_part += value;
            }
        }
        return whole_part;
    }

    fn tokenizeNumberFractionPart(self: *Self) TokenizerError!f32 {
        var fraction_part: f32 = 0.0;
        const contains_fraction_part = if (self.peekChar()) |char| char == '.' else false;
        if (contains_fraction_part) {
            // Consume the decimal
            _ = self.consumeChar();
            // There has to be at least one digit after the decimal point
            if (self.peekChar()) |char| {
                if (!std.ascii.isDigit(char)) return TokenizerError.InvalidNumber;
            } else return TokenizerError.InvalidNumber;
            // Parse the digits
            var coefficient: f32 = 0.1;
            while (self.peekChar()) |char| {
                if (!std.ascii.isDigit(char)) break;
                _ = self.consumeChar();
                const value: f32 = @as(f32, @floatFromInt(char)) - @as(f32, 48.0);
                fraction_part += (value * coefficient);
                coefficient *= 0.1;
            }
        }
        return fraction_part;
    }

    fn tokenizeNumberExponentPart(self: *Self) TokenizerError!f32 {
        var exponent_part: f32 = 0.0;
        const contains_exponent_part = if (self.peekChar()) |char| (std.ascii.toLower(char) == 'e') else false;
        if (contains_exponent_part) {
            // Consume the exponent symbol
            _ = self.consumeChar();
            // There can be a sign after the exponent part
            const exponent_sign_multiplier: f32 = if ((self.peekChar() orelse return TokenizerError.InvalidNumber) == '-') -1.0 else 1.0;
            // peekChar() will not return null because we checked it on the previous line
            if (self.peekChar()) |char| {
                if (char == '-' or char == '+') _ = self.consumeChar();
            }
            // There has to be at least one digit after exponent
            if (self.peekChar()) |char| {
                if (!std.ascii.isDigit(char)) return TokenizerError.InvalidNumber;
            } else return TokenizerError.InvalidNumber;
            // Parse the digits
            while (self.peekChar()) |char| {
                if (!std.ascii.isDigit(char)) break;
                _ = self.consumeChar();
                const value: f32 = @as(f32, @floatFromInt(char)) - @as(f32, 48.0);
                exponent_part *= 10.0;
                exponent_part += value;
            }
            exponent_part *= exponent_sign_multiplier;
        }
        return exponent_part;
    }

    fn tokenizeTrue(self: *Self) TokenizerError!Token {
        if (!self.safeCompareAhead(TRUE)) {
            return TokenizerError.InvalidValue;
        }
        self.pos += TRUE.len;
        return .TRUE;
    }

    fn tokenizeFalse(self: *Self) TokenizerError!Token {
        if (!self.safeCompareAhead(FALSE)) {
            return TokenizerError.InvalidValue;
        }
        self.pos += FALSE.len;
        return .FALSE;
    }

    fn tokenizeNull(self: *Self) TokenizerError!Token {
        if (!self.safeCompareAhead(NULL)) {
            return TokenizerError.InvalidValue;
        }
        self.pos += NULL.len;
        return .NULL;
    }

    fn tokenizeCharacter(self: *Self) TokenizerError!?Token {
        return switch (self.consumeChar() orelse return null) {
            '{' => .OPEN_CURLY_BRACE,
            '}' => .CLOSE_CURLY_BRACE,
            '[' => .OPEN_SQUARE_BRACE,
            ']' => .CLOSE_SQUARE_BRACE,
            ',' => .COMMA,
            ':' => .COLON,
            else => return TokenizerError.UnexpectedCharacter,
        };
    }

    fn safeCompareAhead(self: *Self, s: []const u8) bool {
        if (self.pos + s.len > self.input.len) return false;
        const slice = self.input[self.pos .. self.pos + s.len];
        return std.mem.eql(u8, slice, s);
    }
};

//debug function
pub fn printToken(token: Token) void {
    switch (token) {
        .NUMBER => std.debug.print("{s}({d})\n", .{ @tagName(token), token.NUMBER }),
        .STRING => std.debug.print("{s}({s})\n", .{ @tagName(token), token.STRING }),
        else => std.debug.print("{s}\n", .{@tagName(token)}),
    }
}
