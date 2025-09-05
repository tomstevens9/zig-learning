const std = @import("std");

pub const NumberParser = struct {
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

    pub fn parse(self: *Self) f64 {
        const sign_multiplier: f64 = if (self.peek().? == '-') -1.0 else 1.0;
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
        return sign_multiplier * ((whole_part + fraction_part) * std.math.pow(f64, 10, exponent_part));
    }

    fn parseWholePart(self: *Self) f64 {
        var whole_part: f64 = 0.0;
        // Validated number is guaranteed to have some whole part
        const is_zero = (self.peek().?) == '0';
        if (is_zero) {
            _ = self.consume();
        } else {
            while (self.peek()) |char| {
                if (!std.ascii.isDigit(char)) break;
                _ = self.consume();
                const value: f64 = @floatFromInt(char - 48);
                whole_part *= 10.0;
                whole_part += value;
            }
        }
        return whole_part;
    }

    fn parseFractionPart(self: *Self) f64 {
        var fraction_part: f64 = 0.0;
        const contains_fraction_part = if (self.peek()) |char| char == '.' else false;
        if (!contains_fraction_part) return fraction_part;

        // Consume the decimal
        _ = self.consume();
        // Parse the digits
        var coefficient: f64 = 0.1;
        while (self.peek()) |char| {
            if (!std.ascii.isDigit(char)) break;
            _ = self.consume();
            const value: f64 = @floatFromInt(char - 48);
            fraction_part += (value * coefficient);
            coefficient *= 0.1;
        }
        return fraction_part;
    }

    fn parseExponentPart(self: *Self) f64 {
        var exponent_part: f64 = 0.0;
        const contains_exponent_part = if (self.peek()) |char| (std.ascii.toLower(char) == 'e') else false;
        if (!contains_exponent_part) return exponent_part;

        // Consume the exponent symbol
        _ = self.consume();
        // There can be a sign after the exponent part
        const exponent_sign_multiplier: f64 = if ((self.peek().?) == '-') -1.0 else 1.0;
        if (self.peek()) |char| {
            if (char == '-' or char == '+') _ = self.consume();
        }
        // There has to be at least one digit after exponent
        // Parse the digits
        while (self.peek()) |char| {
            if (!std.ascii.isDigit(char)) break;
            _ = self.consume();
            const value: f64 = @floatFromInt(char - 48);
            exponent_part *= 10.0;
            exponent_part += value;
        }
        exponent_part *= exponent_sign_multiplier;
        return exponent_part;
    }
};
