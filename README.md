# Zig Learning Projects

A collection of projects for learning the Zig programming language, progressing from simple command-line tools to more complex systems programming concepts.

## About This Repository

This repository contains various projects designed to explore Zig's features, including memory management, error handling, testing, and systems programming concepts. Each project builds upon previous knowledge whilst introducing new concepts.

## Projects

### 1. CLI Calculator (`01-cli-calculator/`)

A command-line calculator that performs basic arithmetic operations.

**Features:**
- Basic operations: addition, subtraction, multiplication, division
- Proper error handling for invalid inputs and edge cases
- Help system with usage examples
- Division by zero protection

**Usage:**
```bash
zig run 01-cli-calculator/calculator.zig -- add 5 3
zig run 01-cli-calculator/calculator.zig -- div 10 2.5
zig run 01-cli-calculator/calculator.zig -- help
```

**Learning Focus:**
- Command-line argument parsing
- Error handling and custom error types
- Basic I/O operations
- Float parsing and arithmetic

### 2. Word Counter (`02-word-counter/`)

A text analysis tool that counts word frequencies in files.

**Features:**
- Case-sensitive and case-insensitive counting modes
- Optional alphabetical sorting of results
- Handles various text formats and edge cases
- Comprehensive sample files for testing

**Usage:**
```bash
zig run 02-word-counter/wordcount.zig -- sample_input/simple.txt
zig run 02-word-counter/wordcount.zig -- --case-insensitive --sort sample_input/mixed_case.txt
```

**Learning Focus:**
- File I/O operations
- HashMap usage and custom hash contexts
- String processing and manipulation
- Memory allocation patterns
- Command-line flag parsing

### 3. JSON Parser (`04-json-parser/`)

A complete JSON parser implementation built from scratch.

**Features:**
- Full JSON specification support
- Recursive parsing for nested structures
- Unicode escape sequence handling
- Scientific notation for numbers
- Comprehensive test suite
- Modular architecture

**Structure:**
- `src/main.zig` - Entry point and example usage
- `src/parser.zig` - Main parser logic and JsonValue type
- `src/tokenizer.zig` - Lexical analysis
- `src/string_parser.zig` - String parsing with escape sequences
- `src/number_parser.zig` - Number parsing including scientific notation
- `src/test_parser.zig` - Comprehensive test suite

**Usage:**
```bash
cd 04-json-parser
zig build run
zig build test
```

**Learning Focus:**
- Complex memory management with allocators
- Recursive data structures and algorithms
- Union types and pattern matching
- Unicode and UTF-8 handling
- Comprehensive error handling
- Test-driven development
- Modular project structure

## Building and Running

### Prerequisites
- Zig 0.15.1 or later

### Running Individual Projects

For simple single-file projects:
```bash
zig run <project-directory>/<filename>.zig -- [arguments]
```

For the JSON parser (structured project):
```bash
cd 04-json-parser
zig build run
zig build test
```

## Learning Progression

The projects are designed to introduce Zig concepts gradually:

1. **Calculator**: Basic syntax, error handling, and simple I/O
2. **Word Counter**: File operations, data structures, and memory management
3. **JSON Parser**: Advanced memory management, complex data structures, and comprehensive testing

## Key Zig Concepts Explored

- **Memory Management**: Allocators, arena allocation, manual memory management
- **Error Handling**: Error unions, error propagation, and custom error types
- **Data Structures**: ArrayLists, HashMaps, and unions
- **Testing**: Built-in testing framework and test-driven development
- **String Processing**: UTF-8 handling, escape sequences, and text parsing
- **Parsing**: Tokenization, recursive descent parsing, and grammar implementation
- **Project Structure**: Multi-file projects and build system usage
