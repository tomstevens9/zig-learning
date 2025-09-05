const std = @import("std");

pub const TokenizerError = error{
    InvalidValue,
    UnexpectedCharacter,
    InvalidNumber,
    UnclosedString,
};

const Keyword = enum {
    true,
    false,
    null,
};

pub const Token = union(enum) {
    OPEN_CURLY_BRACE: void,
    CLOSE_CURLY_BRACE: void,
    OPEN_SQUARE_BRACE: void,
    CLOSE_SQUARE_BRACE: void,
    COMMA: void,
    COLON: void,
    TRUE: void,
    FALSE: void,
    NULL: void,
    STRING: []const u8,
    NUMBER: []const u8,
};

fn isWhitespace(c: u8) bool {
    return switch (c) {
        ' ', '\n', '\r', '\t' => true,
        else => false,
    };
}

fn keywordToToken(keyword: Keyword) Token {
    return switch (keyword) {
        .true => .TRUE,
        .false => .FALSE,
        .null => .NULL,
    };
}

fn characterToToken(c: u8) TokenizerError!Token {
    return switch (c) {
        '{' => .OPEN_CURLY_BRACE,
        '}' => .CLOSE_CURLY_BRACE,
        '[' => .OPEN_SQUARE_BRACE,
        ']' => .CLOSE_SQUARE_BRACE,
        ',' => .COMMA,
        ':' => .COLON,
        else => return TokenizerError.UnexpectedCharacter,
    };
}

// This struct uses slices to reference parts of the input. As such, it is
// couples to the lifetime of the input. This shouldn't be an issue because
// the tokenizer is immediately passed to, and used, by the parser, which
// _does_ allocate it's own memory and is therefore not couples to the input.
pub const Tokenizer = struct {
    input: []const u8,
    pos: usize,
    next_token: ?Token,

    const Self = @This();

    pub fn init(input: []const u8) Tokenizer {
        return .{ .input = input, .pos = 0, .next_token = null };
    }

    pub fn peek(self: *Self) TokenizerError!?Token {
        // We already have a token cached. Return that.
        if (self.next_token != null) return self.next_token;
        // Return null if we've parsed the whole input
        if (self.pos >= self.input.len) {
            return null;
        }
        // Skip any whitespace
        while (isWhitespace(self.peekChar() orelse return null)) {
            self.pos += 1;
        }
        // Peek the next value
        if (self.nextTokenIsNumber()) {
            self.next_token = try self.tokenizeNumber();
        } else if (self.nextTokenIsString()) {
            self.next_token = try self.tokenizeString();
        } else {
            self.next_token = switch (self.peekChar() orelse return null) {
                't', 'f', 'n' => try self.tokenizeKeyword(),
                else => try characterToToken(self.consumeChar().?),
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
        _ = try self.next();
    }

    fn peekChar(self: *Self) ?u8 {
        if (self.pos >= self.input.len) return null;
        return self.input[self.pos];
    }

    fn consumeChar(self: *Self) ?u8 {
        const char = self.peekChar() orelse return null;
        self.pos += 1;
        return char;
    }

    fn nextTokenIsString(self: *Self) bool {
        if (self.peekChar()) |char| {
            return char == '"';
        }
        return false;
    }

    fn tokenizeString(self: *Self) TokenizerError!Token {
        // Consume opening quote
        _ = self.consumeChar();

        // Find length of string (excluding quotes)
        const start: usize = self.pos;
        var len: usize = 0;
        var previous_char_was_escape = false;
        while (self.consumeChar()) |char| : (len += 1) {
            if (char == '"' and !previous_char_was_escape) break;
            previous_char_was_escape = char == '\\';
        } else return TokenizerError.UnclosedString;

        // Store the raw string as part of the token
        return .{ .STRING = self.input[start .. start + len] };
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
        const start: usize = self.pos;
        var len: usize = 0;
        const sign_multiplier: f64 = if (self.peekChar().? == '-') -1.0 else 1.0;
        if (sign_multiplier == -1.0) {
            _ = self.consumeChar();
            len += 1;
        }
        // Validate whole part
        len += try self.tokenizeNumberWholePart();
        // Validate fraction part (if present)
        len += try self.tokenizeNumberFractionPart();
        // Validate exponent part (if present)
        len += try self.tokenizeNumberExponentPart();
        return .{ .NUMBER = self.input[start .. start + len] };
    }

    fn tokenizeNumberWholePart(self: *Self) TokenizerError!usize {
        const is_zero = (self.peekChar() orelse return TokenizerError.InvalidNumber) == '0';
        if (is_zero) {
            _ = self.consumeChar();
            return 1;
        } else {
            var len: usize = 0;
            while (self.peekChar()) |char| {
                if (!std.ascii.isDigit(char)) break;
                _ = self.consumeChar();
                len += 1;
            }
            return len;
        }
    }

    fn tokenizeNumberFractionPart(self: *Self) TokenizerError!usize {
        var len: usize = 0;
        const contains_fraction_part = if (self.peekChar()) |char| char == '.' else false;
        if (contains_fraction_part) {
            // Consume the decimal
            _ = self.consumeChar();
            len += 1;
            // There has to be at least one digit after the decimal point
            if (self.peekChar()) |char| {
                if (!std.ascii.isDigit(char)) return TokenizerError.InvalidNumber;
            } else return TokenizerError.InvalidNumber;
            // Parse the digits
            while (self.peekChar()) |char| {
                if (!std.ascii.isDigit(char)) break;
                _ = self.consumeChar();
                len += 1;
            }
        }
        return len;
    }

    fn tokenizeNumberExponentPart(self: *Self) TokenizerError!usize {
        var len: usize = 0;
        const contains_exponent_part = if (self.peekChar()) |char| (std.ascii.toLower(char) == 'e') else false;
        if (contains_exponent_part) {
            // Consume the exponent symbol
            _ = self.consumeChar();
            len += 1;
            // Check for explicit exponent sign
            if (self.peekChar()) |char| {
                if (char == '-' or char == '+') {
                    _ = self.consumeChar();
                    len += 1;
                }
            } else return TokenizerError.InvalidNumber;
            // There has to be at least one digit after exponent
            if (self.peekChar()) |char| {
                if (!std.ascii.isDigit(char)) return TokenizerError.InvalidNumber;
            } else return TokenizerError.InvalidNumber;
            // Parse the digits
            while (self.peekChar()) |char| {
                if (!std.ascii.isDigit(char)) break;
                _ = self.consumeChar();
                len += 1;
            }
        }
        return len;
    }

    fn tokenizeKeyword(self: *Self) TokenizerError!Token {
        const expected_keyword_enum: Keyword = switch (self.peekChar().?) {
            't' => .true,
            'f' => .false,
            'n' => .null,
            else => return TokenizerError.InvalidValue,
        };
        const expected_str = @tagName(expected_keyword_enum);
        if (!self.safeCompareAhead(expected_str)) {
            return TokenizerError.InvalidValue;
        }
        for (0..expected_str.len) |_| {
            _ = self.consumeChar();
        }
        return keywordToToken(expected_keyword_enum);
    }

    fn tokenizeCharacter(self: *Self) TokenizerError!?Token {
        return switch (self.consumeChar().?) {
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
