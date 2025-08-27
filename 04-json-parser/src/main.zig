const std = @import("std");
const json_parser = @import("parser.zig");

const TEST_INPUT = 
    \\{
    \\  "name": "Tom Stevens",
    \\  "age": 29,
    \\  "ownsDog": true,
    \\  "ownsCat": false,
    \\  "sample": null
    \\}
;


pub fn main() !void {

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var result = try json_parser.parse(allocator, TEST_INPUT);
    defer result.deinit();

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
