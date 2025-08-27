const std = @import("std");
const JsonTokeniser = @import("tokeniser.zig").JsonTokeniser;
const JsonParser = @import("parser.zig").JsonParser;


pub fn main() !void {
    const test_input = 
        \\{
        \\  "name": "Tom Stevens",
        \\  "age": 29,
        \\  "ownsDog": true,
        \\  "ownsCat": false,
        \\  "sample": null
        \\}
    ;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tokeniser = JsonTokeniser.init(test_input);
    var parser = JsonParser.init(allocator, &tokeniser);
    const result = try parser.parse();
    std.debug.print("--- RESULT ---\n", .{});
    std.debug.print("name: {s}\n", .{ result.object.get("name").?.string });
    std.debug.print("age: {d}\n", .{ result.object.get("age").?.number });
    std.debug.print("owns dog: {s}\n", .{ boolToStr(result.object.get("ownsDog").?.boolean )});
    std.debug.print("owns cat: {s}\n", .{ boolToStr(result.object.get("ownsCat").?.boolean )});
    std.debug.print("sample: {s}\n", .{ if (result.object.get("sample").? == .null_value) "Null" else "NotNull"  });
}

fn boolToStr(b: bool) []const u8 {
    return if (b) "True" else "False";
}
