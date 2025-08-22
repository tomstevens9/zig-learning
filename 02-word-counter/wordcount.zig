const std = @import("std");

const WordcountError = error{
    MissingArgument,
    UnexpectedArgument,
};

const Args = struct {
    filepath: []const u8,
    case_insensitive: bool,
    sort: bool,
};

const CaseSensitiveStringContext = struct {
    seed: u64,
    case_insensitive: bool,

    pub fn hash(self: @This(), s: []const u8) u64 {
        var hasher = std.hash.Wyhash.init(self.seed);
        for (s) |c| {
            const char = if (self.case_insensitive) std.ascii.toLower(c) else c;
            hasher.update(&[_]u8{char});
        }
        return hasher.final();
    }

    pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        if (self.case_insensitive) {
            for (a, b) |ca, cb| {
                if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) return false;
            }
            return true;
        }
        return std.mem.eql(u8, a, b);
    }
};

const CaseSensitiveStringHashMap = std.hash_map.HashMap([]const u8, u32, CaseSensitiveStringContext, std.hash_map.default_max_load_percentage);

fn stringPtrLessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

fn parseArgs(allocator: std.mem.Allocator) WordcountError!Args {
    var args_iterator = try std.process.argsWithAllocator(allocator);
    // Skip program name
    _ = args_iterator.next();

    var filepath: ?[]const u8 = null;
    var case_insensitive = false;
    var sort = false;

    while (args_iterator.next()) |arg| {
        if (arg[0] == '-') {
            if (std.mem.eql(u8, arg, "--case-insensitive")) {
                case_insensitive = true;
            } else if (std.mem.eql(u8, arg, "--sort")) {
                sort = true;
            } else {
                return WordcountError.UnexpectedArgument;
            }
        } else {
            if (filepath != null) {
                return WordcountError.UnexpectedArgument;
            }
            filepath = arg;
        }
    }
    return .{
        .filepath = filepath orelse {
            return WordcountError.MissingArgument;
        },
        .case_insensitive = case_insensitive,
        .sort = sort,
    };
}

fn printUsage() void {
    std.debug.print("Usage: wordcount.zig [--case-insensitive] [--sort] <filepath>\n", .{});
}

fn handleWordcountError(err: WordcountError) void {
    switch (err) {
        WordcountError.MissingArgument => {
            std.debug.print("Error: Please provide a file path\n", .{}); // TODO improve
            printUsage();
        },
        WordcountError.UnexpectedArgument => {
            std.debug.print("Error: Unexpected argument\n", .{}); // TODO improve
            printUsage();
        },
    }
}

fn readEntireFile(allocator: std.mem.Allocator, filepath: []const u8) ![]u8 {
    // Allow FileOpen errors to propgate as the will be informative to the user
    const file = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer file.close();

    const file_size = try file.getEndPos();
    return try file.readToEndAlloc(allocator, file_size);
}

fn countWords(allocator: std.mem.Allocator, text: []const u8, case_insensitive: bool) !CaseSensitiveStringHashMap {
    // Count the frequency of words
    var words_map = CaseSensitiveStringHashMap.initContext(allocator, CaseSensitiveStringContext{ .case_insensitive = case_insensitive, .seed = 0 });

    var i: usize = 0;
    while (i < text.len) {
        while (i < text.len and !std.ascii.isAlphabetic(text[i])) {
            i += 1;
        }

        const word_start = i;
        while (i < text.len and std.ascii.isAlphabetic(text[i])) {
            i += 1;
        }

        if (word_start < i) {
            const word = text[word_start..i];
            const count = words_map.get(word) orelse 0;
            try words_map.put(word, count + 1);
        }
    }
    return words_map;
}

fn printWordCounts(allocator: std.mem.Allocator, words_map: CaseSensitiveStringHashMap, sort: bool) !void {
    var words_map_key_iterator = words_map.keyIterator();
    var key_array: [][]const u8 = try allocator.alloc([]const u8, words_map.count());
    var idx: usize = 0;
    while (words_map_key_iterator.next()) |key| {
        key_array[idx] = key.*;
        idx += 1;
    }
    if (sort) {
        std.mem.sort([]const u8, key_array, {}, stringPtrLessThan);
    }

    var total_words: u32 = 0;
    for (key_array) |key| {
        const count = words_map.get(key).?;
        total_words += count;
        std.debug.print("{s}: {d}\n", .{ key, count });
    }

    if (words_map.count() == 0) {
        std.debug.print("(no words found)\n", .{});
    }

    std.debug.print("\n", .{});
    std.debug.print("Total words: {d}\n", .{total_words});
    std.debug.print("Unique words: {d}\n", .{words_map.count()});
}

pub fn main() !void {
    // Create allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse filename from command line args
    const args = parseArgs(allocator) catch |err| {
        handleWordcountError(err);
        return;
    };

    // Print out the name of the file being inspected

    const file_content = readEntireFile(allocator, args.filepath) catch |err| {
        switch (err) {
            error.FileNotFound => {
                std.debug.print("Error: File {s} not found\n", .{args.filepath});
                return;
            },
            error.AccessDenied => {
                std.debug.print("Error: Permission denied accessing '{s}'\n", .{args.filepath});
                return;
            },
            else => return err,
        }
    };

    var words_map = try countWords(allocator, file_content, args.case_insensitive);
    defer words_map.deinit();

    std.debug.print("Word frequencies for '{s}':\n", .{args.filepath});
    try printWordCounts(allocator, words_map, args.sort);
}
