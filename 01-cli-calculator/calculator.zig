const std = @import("std");

const CalculatorError = error{ MissingArguments, TooManyArguments, UnknownOperation, InvalidNumber };

const Operation = enum {
    add,
    sub,
    mul,
    div,

    pub fn fromString(str: []const u8) ?Operation {
        return std.meta.stringToEnum(Operation, str);
    }
};

const Args = struct { operation: Operation, number1: f32, number2: f32 };

fn parseArgs(allocator: std.mem.Allocator) (CalculatorError || std.mem.Allocator.Error)!Args {
    var args_iterator = try std.process.argsWithAllocator(allocator);

    _ = args_iterator.next(); // skip program name
    const operation_str = args_iterator.next() orelse return CalculatorError.MissingArguments;
    if (std.mem.eql(u8, operation_str, "help")) {
        printUsage();
        printHelp();
        std.process.exit(1);
    }
    const operation = Operation.fromString(operation_str) orelse {
        return CalculatorError.UnknownOperation;
    };
    const number1_str = args_iterator.next() orelse return CalculatorError.MissingArguments;
    const number2_str = args_iterator.next() orelse return CalculatorError.MissingArguments;

    if (args_iterator.next() != null) return CalculatorError.TooManyArguments;

    const number1 = std.fmt.parseFloat(f32, number1_str) catch {
        return CalculatorError.InvalidNumber;
    };
    const number2 = std.fmt.parseFloat(f32, number2_str) catch {
        return CalculatorError.InvalidNumber;
    };

    return Args{ .operation = operation, .number1 = number1, .number2 = number2 };
}

fn printUsage() void {
    std.debug.print("Usage: calculator <operation> <number1> <number2>\n", .{});
    std.debug.print("Operations: add, sub, mul, div\n", .{});
}

fn printHelp() void {
    printUsage();
    std.debug.print("\n", .{});
    std.debug.print("Operations:\n", .{});
    std.debug.print("  add - Addition\n", .{});
    std.debug.print("  sub - Subtraction  \n", .{});
    std.debug.print("  mul - Multiplication\n", .{});
    std.debug.print("  div - Division\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Examples:\n", .{});
    std.debug.print("  calculator add 5 3\n", .{});
    std.debug.print("  calculator div 10 2.5\n", .{});
    std.debug.print("  calculator mul -4 7\n", .{});
}

fn handleCalculatorError(err: CalculatorError) void {
    switch (err) {
        CalculatorError.MissingArguments => {
            std.debug.print("Error: Missing arguments\n", .{});
            printUsage();
        },
        CalculatorError.TooManyArguments => {
            std.debug.print("Error: Too many arguments\n", .{});
            printUsage();
        },
        CalculatorError.UnknownOperation => {
            std.debug.print("Error: Unknown operation\n", .{});
            std.debug.print("Available operations: add, sub, mul, div\n", .{});
        },
        CalculatorError.InvalidNumber => {
            std.debug.print("Error: Invalid number'\n", .{});
        },
    }
}

pub fn main() !void {
    // Set up allocator
    // Use ArenaAllocator because this is a short-lived command line process
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse the command line arguments
    const args = parseArgs(allocator) catch |err| {
        switch (err) {
            CalculatorError.MissingArguments => handleCalculatorError(CalculatorError.MissingArguments),
            CalculatorError.TooManyArguments => handleCalculatorError(CalculatorError.TooManyArguments),
            CalculatorError.UnknownOperation => handleCalculatorError(CalculatorError.UnknownOperation),
            CalculatorError.InvalidNumber => handleCalculatorError(CalculatorError.InvalidNumber),
            error.OutOfMemory => return err,
        }
        return;
    };
    // Catch division by zero
    if (args.operation == .div and args.number2 == 0.0) {
        std.debug.print("Error: Division by zero\n", .{});
        return;
    }
    // Calculate the result
    const result = switch (args.operation) {
        .add => args.number1 + args.number2,
        .sub => args.number1 - args.number2,
        .mul => args.number1 * args.number2,
        .div => args.number1 / args.number2,
    };
    // Print the result to the command line
    std.debug.print("{d}\n", .{result});
}
