const std = @import("std");

const bss: [*]u8 = @extern([*]u8, .{ .name = "__bss" });
const bss_end: [*]u8 = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top: [*]u8 = @extern([*]u8, .{ .name = "__stack_top" });

const SYSCON_REG_ADDR: usize = 0x11100000;
const UART_BUF_REG_ADDR: usize = 0x10000000;

const syscon: *volatile u32 = @ptrFromInt(SYSCON_REG_ADDR);
const uart_buf_reg: *volatile u8 = @ptrFromInt(UART_BUF_REG_ADDR);

// ================================
// Current todos:
// - understand and comment the kernel_entry function
// - handle trap call -> implement
// - Adding stack traces to panic: https://andrewkelley.me/post/zig-stack-traces-kernel-panic-bare-bones-os.html

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
    const x: u32 = 1;
    const text = "abcd";
    const somenum: u64 = 111;
    print("{x}\tx={d}: \n{x}\ttext: {s}\n{x} anotherNum {d} ", .{ x, x, text, text, somenum, somenum });
    @panic("abcdeeee");

    //syscon.* = 0x5555; // send powerdown; commented, cause qemu restarts image, making it an infinite loop of hello worlds
}

fn kernel_entry() void {
    // sscratch - register used as a temporary storage to save
    //      stack pointer at exception occurrence. later restored
    //
    // TODO: comment more of this code to make sure i understand this shit

    asm volatile (
        \\csrw sscratch, sp
        //   write stack pointer into csr (control and status reg.)
        \\addi sp, sp, -4*31
        //   move stack pointer down by 4*31 bytes (make space for 31 4-byte registers to be saved on the stack)
        \\sw ra, 4* 0(sp)
        \\sw gp, 4* 1(sp)
        \\sw tp, 4* 2(sp)
        \\sw t0, 4* 3(sp)
        \\sw t1, 4* 4(sp)
        \\sw t2, 4* 5(sp)
        \\sw t3, 4* 6(sp)
        \\sw t4, 4* 7(sp)
        \\sw t5, 4* 8(sp)
        \\sw t6, 4* 9(sp)
        \\sw a0, 4* 10(sp)
        \\sw a1, 4* 11(sp)
        \\sw a2, 4* 12(sp)
        \\sw a3, 4* 13(sp)
        \\sw a4, 4* 14(sp)
        \\sw a5, 4* 15(sp)
        \\sw a6, 4* 16(sp)
        \\sw a7, 4* 17(sp)
        \\sw s0, 4* 18(sp)
        \\sw s1, 4* 19(sp)
        \\sw s2, 4* 20(sp)
        \\sw s3, 4* 21(sp)
        \\sw s4, 4* 22(sp)
        \\sw s5, 4* 23(sp)
        \\sw s6, 4* 24(sp)
        \\sw s7, 4* 25(sp)
        \\sw s8, 4* 26(sp)
        \\sw s9, 4* 27(sp)
        \\sw s10, 4* 28(sp)
        \\sw s11, 4* 29(sp)
        // save register [$1] into memory at offset sp
        // using sw (store word)
        \\
        \\csrr a0, sscratch
        // read value from sscratch csr into a0
        // this restores stack pointer from before (downwards it has register data)
        \\sw a0, 4*30(sp)
        // moves sp into a0,
        // prepares stack frame to be passed into handle_trap function, as a0 is about to be used
        \\
        \\mv a0 sp
        // sp is copied into a0, in order to pass argument to handle_trap
        \\call handle_trap
        // actual code for handling trap. Implemented below
        \\
        \\lw ra, 4* 0(sp)
        \\lw gp, 4* 1(sp)
        \\lw tp, 4* 2(sp)
        \\lw t0, 4* 3(sp)
        \\lw t1, 4* 4(sp)
        \\lw t2, 4* 5(sp)
        \\lw t3, 4* 6(sp)
        \\lw t4, 4* 7(sp)
        \\lw t5, 4* 8(sp)
        \\lw t6, 4* 9(sp)
        \\lw a0, 4* 10(sp)
        \\lw a1, 4* 11(sp)
        \\lw a2, 4* 12(sp)
        \\lw a3, 4* 13(sp)
        \\lw a4, 4* 14(sp)
        \\lw a5, 4* 15(sp)
        \\lw a6, 4* 16(sp)
        \\lw a7, 4* 17(sp)
        \\lw s0, 4* 18(sp)
        \\lw s1, 4* 19(sp)
        \\lw s2, 4* 20(sp)
        \\lw s3, 4* 21(sp)
        \\lw s4, 4* 22(sp)
        \\lw s5, 4* 23(sp)
        \\lw s6, 4* 24(sp)
        \\lw s7, 4* 25(sp)
        \\lw s8, 4* 26(sp)
        \\lw    s9, 4* 27(sp)
        \\lw    s10, 4* 28(sp)
        \\lw    s11, 4* 29(sp)
        // loading previously saved registers back.
        \\sret
    );
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
    const args_type_info = @typeInfo(@TypeOf(args));
    const field_info = args_type_info.Struct.fields;

    comptime {
        std.debug.assert(format.len != 0);
        if (args_type_info != .Struct or !args_type_info.Struct.is_tuple) {
            @compileError("Expected a tuple or a struct in kernel print");
        }
    }

    comptime var current_arg: usize = 0;
    comptime var i: usize = 0;
    comptime var c: u8 = undefined;
    inline while (i < format.len) : (i += 1) {
        c = format[i];
        switch (c) {
            '\\' => { // escape
                if (i + 1 == format.len) return;
                const next_tok = format[i + 1];
                putchar(next_tok);

                // i += 1;
                // TODO: i want to skip 2 tokens here, but since i'm unrolling this part at compile time, i+1 cannot happen in runtime code. So, I either have to make this work without skipping tokens, or .... idk actually; maybe instead of looking ahead i should look behind, and if there is a single \ sign before a token, then treat it as escape. Hmm, doesn't sound bad.
            },
            'x', 'd', 's' => {
                if (i > 0 and format[i - 1] == '{') continue;
                putchar(c);
            },
            '}' => { // TODO: same for other control characters
                if (i > 0 and (format[i - 1] == '\\' and format[i - 2] != '\\')) putchar('}');
            },
            '{' => {
                if (i + 2 > format.len or current_arg >= field_info.len) return;
                if (i > 0 and format[i - 1] != '\\' and format[i + 2] != '}') @compileError("{ char neither escaped nor part of var");
                const field = field_info[current_arg];
                const value = @field(args, field.name);

                switch (format[i + 1]) {
                    'x' => {
                        const ptr: usize = switch (@typeInfo(field.type)) {
                            .Pointer => @intFromPtr(value),
                            else => @intFromPtr(&value),
                        };
                        putchar('0');
                        putchar('x');
                        for (0..7) |j| {
                            const shift: u5 = @intCast((7 - j) * 4);
                            const nibble: usize = (ptr >> shift) & 0xf;
                            putchar("0123456789abcdef"[nibble]);
                        }
                    },
                    'd' => {
                        var val: u32 = value;
                        if (val < 0) {
                            putchar('-');
                            val = -value;
                        }
                        var divisor: u32 = 1;
                        while (val / divisor > 9) {
                            divisor = divisor * 10;
                        }

                        while (divisor > 0) {
                            putchar('0' + @as(u8, @truncate(val / divisor)));
                            val %= divisor;
                            divisor /= 10;
                        }
                    },
                    's' => {
                        //if (field.is_comptime) @compileError("{s} print supplied type that's not []u8");
                        // TODO: make this check work, one day
                        for (value) |v| {
                            putchar(v);
                        }
                    },
                    else => @compileError(format[i .. i + 1]),
                }
                current_arg += 1;
            },
            else => {
                putchar(c);
            },
        }
    }
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = ret_addr; // autofix
    _ = error_return_trace; // autofix
    print("custom PANIC at {s}\n", .{msg});
    while (true) {
        asm volatile ("");
    }
}
