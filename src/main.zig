const std = @import("std");

const bss: [*]u8 = @extern([*]u8, .{ .name = "__bss" });
const bss_end: [*]u8 = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top: [*]u8 = @extern([*]u8, .{ .name = "__stack_top" });

const SYSCON_REG_ADDR: usize = 0x11100000;
const UART_BUF_REG_ADDR: usize = 0x10000000;

const syscon: *volatile u32 = @ptrFromInt(SYSCON_REG_ADDR);
const uart_buf_reg: *volatile u8 = @ptrFromInt(UART_BUF_REG_ADDR);

export fn boot() linksection(".text.boot") callconv(.Naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (stack_top),
    );
}

export fn kernel_main() noreturn {
    main() catch |err| std.debug.panic("{s}", .{@errorName(err)});
    while (true) {
        asm volatile (
            \\wfi
        );
    }
}

pub fn main() !void {
    const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bss_len], 0);
    // for ("Hello world\n") |b| {
    //     puchar_sbi(b);
    // }
    print("abcc", .{});
    //std.debug.print("hello, world in default print", .{});

    //syscon.* = 0x5555; // send powerdown; commented, cause qemu restarts image, making it an infinite loop of hello worlds
}

const sbi_ret = struct {
    error_: isize,
    value: usize,
};
// longs and ptrs are the size of integer register
fn sbi_call(arg0: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize, fid: usize, eid: usize) sbi_ret {
    var a0: isize = undefined;
    var a1: usize = undefined;
    asm volatile (
        \\ecall
        : [a0] "={a0}" (a0),
          [a1] "={a1}" (a1),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [fid] "{a6}" (fid),
          [eid] "{a7}" (eid),
        : "memory"
    );
    return sbi_ret{ .error_ = a0, .value = a1 };
}

// two different ways of doing console printing.
// sbi call communicates with qemu by using its own UART driver, and qemu sends it to std out.
fn puchar_sbi(c: u8) void {
    _ = sbi_call(c, 0, 0, 0, 0, 0, 0, 1);
}
// uart putchar instead does immediately send the character to uart register in memory
fn putchar_uart(c: u8) void {
    uart_buf_reg.* = c;
}
const putchar = putchar_uart;

fn print(comptime format: []const u8, args: anytype) void {
    comptime std.debug.assert(format.len != 0);
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(args);
    const field_info = args_type_info.@"struct".fields;
    const args_state :std.fmt.ArgState = .{.args_len = field_info.len};
    var current_arg: usize = 0;
    var i: usize = 0;
    var c: u8 = undefined;
    while (i < format.len) : (i += 1) {
        c = format[i];
        switch (c) {
            '\\' => { // escape
                if (i + 1 == format.len) return;
                const next_tok = format[i + 1];
                putchar(next_tok);
                i += 1;
            },
            '{' => {
                if (i + 2 < format.len or current_arg < args.len) return;
                switch (format[i + 1]) {
                    'x' => {
                        // const ptr: usize = @intFromPtr(args[current_arg]);
                        const ptr: usize = args_state.next_arg;
                        for (7..0) |j| {
                            const nibble = (ptr >> (j * 4)) & 0xf;
                            putchar("0123456789abcdef"[nibble]);
                        }
                        args_state.nextArg()
                    },
                    'd' => {},
                    's' => {},
                    else => @compileError("Wrong format string value type"),
                }
                current_arg += 1;

                // while (i < format.len or format[i] != '}') i += 1;
                // if (i == format.len) return;

            },
            else => {
                putchar(c[i]);
            },
        }
    }
}

// fn print(comptime u :i32) void {
// }
