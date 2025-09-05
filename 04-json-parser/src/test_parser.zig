const std = @import("std");
const json_parser = @import("parser.zig");
const JsonValue = json_parser.JsonValue;

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;
const expectError = testing.expectError;

// Helper function to parse JSON with testing allocator
fn parseJson(input: []const u8) !JsonValue {
    return json_parser.parse(testing.allocator, input);
}

// Test basic null value
test "parse null" {
    const result = try parseJson("null");
    try expectEqual(JsonValue.null_value, result);
}

// Test boolean values
test "parse true" {
    const result = try parseJson("true");
    try expectEqual(@as(bool, true), result.boolean);
}

test "parse false" {
    const result = try parseJson("false");
    try expectEqual(@as(bool, false), result.boolean);
}

// Test basic numbers
test "parse positive integer" {
    const result = try parseJson("123");
    try expectEqual(@as(f64, 123.0), result.number);
}

test "parse negative integer" {
    const result = try parseJson("-456");
    try expectEqual(@as(f64, -456.0), result.number);
}

test "parse zero" {
    const result = try parseJson("0");
    try expectEqual(@as(f64, 0.0), result.number);
}

test "parse floating point" {
    const result = try parseJson("123.456");
    try expect(std.math.approxEqAbs(f64, 123.456, result.number, 0.001));
}

test "parse negative floating point" {
    const result = try parseJson("-123.456");
    try expect(std.math.approxEqAbs(f64, -123.456, result.number, 0.001));
}

test "parse scientific notation positive exponent" {
    const result = try parseJson("1.23e2");
    try expect(std.math.approxEqAbs(f64, 123.0, result.number, 0.001));
}

test "parse scientific notation negative exponent" {
    const result = try parseJson("1.23e-2");
    try expect(std.math.approxEqAbs(f64, 0.0123, result.number, 0.00001));
}

test "parse scientific notation explicit positive exponent" {
    const result = try parseJson("1.23e+2");
    try expect(std.math.approxEqAbs(f64, 123.0, result.number, 0.001));
}

// Test basic strings
test "parse simple string" {
    var result = try parseJson("\"hello world\"");
    defer result.deinit(testing.allocator);
    
    try expectEqualStrings("hello world", result.string);
}

test "parse empty string" {
    var result = try parseJson("\"\"");
    defer result.deinit(testing.allocator);
    
    try expectEqualStrings("", result.string);
}

test "parse string with escape sequences" {
    var result = try parseJson("\"Hello\\nWorld\\t!\"");
    defer result.deinit(testing.allocator);
    
    try expectEqualStrings("Hello\nWorld\t!", result.string);
}

test "parse string with unicode escape" {
    var result = try parseJson("\"\\u0041\\u0042\\u0043\"");
    defer result.deinit(testing.allocator);
    
    try expectEqualStrings("ABC", result.string);
}

test "parse string with quote escape" {
    var result = try parseJson("\"Say \\\"Hello\\\"\"");
    defer result.deinit(testing.allocator);
    
    try expectEqualStrings("Say \"Hello\"", result.string);
}

// Test arrays
test "parse empty array" {
    var result = try parseJson("[]");
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(usize, 0), result.array.items.len);
}

test "parse array with single element" {
    var result = try parseJson("[42]");
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(usize, 1), result.array.items.len);
    try expectEqual(@as(f64, 42.0), result.array.items[0].number);
}

test "parse array with multiple elements" {
    var result = try parseJson("[1, true, \"hello\", null]");
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(usize, 4), result.array.items.len);
    try expectEqual(@as(f64, 1.0), result.array.items[0].number);
    try expectEqual(@as(bool, true), result.array.items[1].boolean);
    try expectEqualStrings("hello", result.array.items[2].string);
    try expectEqual(JsonValue.null_value, result.array.items[3]);
}

test "parse nested arrays" {
    var result = try parseJson("[[1, 2], [3, 4]]");
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(usize, 2), result.array.items.len);
    try expectEqual(@as(usize, 2), result.array.items[0].array.items.len);
    try expectEqual(@as(usize, 2), result.array.items[1].array.items.len);
    try expectEqual(@as(f64, 1.0), result.array.items[0].array.items[0].number);
    try expectEqual(@as(f64, 4.0), result.array.items[1].array.items[1].number);
}

// Test objects
test "parse empty object" {
    var result = try parseJson("{}");
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(u32, 0), result.object.count());
}

test "parse object with single key-value pair" {
    var result = try parseJson("{\"name\": \"John\"}");
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(u32, 1), result.object.count());
    const value = result.object.get("name").?;
    try expectEqualStrings("John", value.string);
}

test "parse object with multiple key-value pairs" {
    var result = try parseJson("{\"name\": \"John\", \"age\": 30, \"active\": true}");
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(u32, 3), result.object.count());
    try expectEqualStrings("John", result.object.get("name").?.string);
    try expectEqual(@as(f64, 30.0), result.object.get("age").?.number);
    try expectEqual(@as(bool, true), result.object.get("active").?.boolean);
}

test "parse nested objects" {
    var result = try parseJson("{\"person\": {\"name\": \"John\", \"age\": 30}}");
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(u32, 1), result.object.count());
    const person = result.object.get("person").?;
    try expectEqual(@as(u32, 2), person.object.count());
    try expectEqualStrings("John", person.object.get("name").?.string);
    try expectEqual(@as(f64, 30.0), person.object.get("age").?.number);
}

test "parse complex nested structure" {
    const json_input = 
        \\{
        \\  "users": [
        \\    {"name": "Alice", "scores": [95, 87, 92]},
        \\    {"name": "Bob", "scores": [78, 85, 90]}
        \\  ],
        \\  "total": 2
        \\}
    ;
    
    var result = try parseJson(json_input);
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(u32, 2), result.object.count());
    try expectEqual(@as(f64, 2.0), result.object.get("total").?.number);
    
    const users = result.object.get("users").?;
    try expectEqual(@as(usize, 2), users.array.items.len);
    
    const alice = users.array.items[0];
    try expectEqualStrings("Alice", alice.object.get("name").?.string);
    try expectEqual(@as(usize, 3), alice.object.get("scores").?.array.items.len);
    try expectEqual(@as(f64, 95.0), alice.object.get("scores").?.array.items[0].number);
}

// Test whitespace handling
test "parse with whitespace" {
    var result = try parseJson("  {  \"name\"  :  \"John\"  }  ");
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(u32, 1), result.object.count());
    try expectEqualStrings("John", result.object.get("name").?.string);
}

test "parse with newlines and tabs" {
    const json_input = "{\n\t\"name\": \"John\",\n\t\"age\": 30\n}";
    
    var result = try parseJson(json_input);
    defer result.deinit(testing.allocator);
    
    try expectEqual(@as(u32, 2), result.object.count());
    try expectEqualStrings("John", result.object.get("name").?.string);
    try expectEqual(@as(f64, 30.0), result.object.get("age").?.number);
}

// Test error cases
test "parse invalid json - unexpected character" {
    try expectError(error.UnexpectedCharacter, parseJson("hello"));
}

test "parse invalid json - unexpected end of input" {
    try expectError(error.UnexpectedEndOfInput, parseJson("{"));
}

test "parse invalid json - unclosed string" {
    try expectError(error.UnclosedString, parseJson("\"hello"));
}

test "parse invalid json - invalid number" {
    try expectError(error.InvalidNumber, parseJson("123."));
}

test "parse invalid json - unexpected token in object" {
    try expectError(error.UnexpectedToken, parseJson("{123}"));
}

test "parse invalid json - unexpected token in array" {
    try expectError(error.UnexpectedToken, parseJson("[,]"));
}

test "parse invalid json - missing colon in object" {
    try expectError(error.UnexpectedToken, parseJson("{\"name\" \"John\"}"));
}

test "parse invalid json - trailing comma in object" {
    try expectError(error.UnexpectedToken, parseJson("{\"name\": \"John\",}"));
}

test "parse invalid json - trailing comma in array" {
    try expectError(error.UnexpectedToken, parseJson("[1, 2,]"));
}
