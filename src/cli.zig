const std = @import("std");
const mem = std.mem;

pub const Argument = struct {
    long: []const u8,
    description: []const u8,
    value: i8,
    necessary: bool,
    parameter_type: ParameterType,
};

pub const Program = struct {
    value: i8,
    parameter: []const u8,
};

pub const ParameterType = enum {
    flag,
    input,
};

pub const ParserError = error{
    UnknownParameter,
    UnknownParameterType,
    MissingParameter,
};

/// Please be aware, that redefinitions of help and version will not be considered
/// Or maybe, I'll redefine is so that redefinition of necessary will be possible
/// The first definition of any argument will be considered in parsing.
const necessary = [_]Argument{
    .{
        .long = "help",
        .description = "Show this help",
        .necessary = false,
        .value = -2,
        .parameter_type = ParameterType.flag,
    },
    .{
        .long = "version",
        .description = "Show the version",
        .necessary = false,
        .value = -3,
        .parameter_type = ParameterType.flag,
    },
};

pub fn Parser() type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        arguments: []const Argument,
        program: *std.ArrayList(Program),

        vsn: []const u8,

        pub fn init(
            allocator: std.mem.Allocator,
            args: []Argument,
            vsn: []const u8,
            list: *std.ArrayList(Program),
        ) !Self {
            var arguments = try allocator.alloc(Argument, args.len + necessary.len);
            @memcpy(arguments[0..necessary.len], necessary[0..]);
            @memcpy(arguments[necessary.len..], args);

            return Self{
                .allocator = allocator,
                .arguments = arguments[0..],
                .program = list,
                .vsn = vsn,
            };
        }

        /// Parse all given arguments
        pub fn parse(self: *Self) !void {
            var process_args =
                try std.process.ArgIterator.initWithAllocator(self.allocator);
            defer process_args.deinit();

            _ = process_args.skip();

            // Iterate program arguments
            while (process_args.next()) |arg| {
                if (std.mem.eql(u8, arg[0..2], "--")) {
                    // Long form
                    _ = try self.compare_long(arg[2..], &process_args);
                } else if (arg[0] == '-') {
                    // Short form
                    self.compare_short();
                } else {
                    return ParserError.UnknownParameter;
                }
            }
        }

        /// Compare given argument to long-form arguments in the Parser
        fn compare_long(
            self: *Self,
            argument: []const u8,
            process_args: *std.process.ArgIterator,
        ) !void {
            // Check against necessary
            if (std.mem.eql(u8, argument, "help")) {
                self.help();
                std.posix.exit(0);
                return;
            } else if (std.mem.eql(u8, argument, "version")) {
                self.version();
                std.posix.exit(0);
            }

            // Check against custom
            for (self.arguments[2..]) |arg| {
                if (std.mem.eql(u8, arg.long, argument)) {

                    // Check if parameter needed
                    if (arg.parameter_type == ParameterType.input) {
                        // Parameter necessary
                        do_nothing(undefined);

                        const p_arg = process_args.next();
                        if (p_arg == null) {
                            try self.program.append(Program{
                                .value = -1,
                                .parameter = arg.long,
                            });

                            return ParserError.MissingParameter;
                        } else if (p_arg.?[0] == '-') {
                            try self.program.append(Program{
                                .value = -1,
                                .parameter = arg.long,
                            });

                            return ParserError.MissingParameter;
                        }

                        try self.program.append(Program{
                            .value = arg.value,
                            .parameter = p_arg.?,
                        });
                    } else if (arg.parameter_type == ParameterType.flag) {
                        // Parameter not necessary
                        try self.program.append(Program{
                            .value = arg.value,
                            .parameter = undefined,
                        });
                    } else {
                        return ParserError.UnknownParameterType;
                    }
                }
            }
        }

        /// Compare given argument to short-form arguments in the Parser
        fn compare_short(self: *Self) void {
            _ = self;
        }

        fn help(self: *Self) void {
            for (self.arguments) |item| {
                std.debug.print("{s}\n", .{item.long});
            }
            std.posix.exit(0);
        }

        inline fn version(self: *Self) void {
            std.debug.print("{s}\n", .{self.vsn});
            std.posix.exit(0);
        }

        pub fn deinit(self: *Self) void {
            _ = self;
        }
    };
}

fn do_nothing(arg: anytype) void {
    _ = arg;
    return;
}
