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
    while (true) {}
}

pub fn main() !void {
    const bss_len = @intFromPtr(bss_end) - @intFromPtr(bss);
    @memset(bss[0..bss_len], 0);
    for ("Hello world\n") |b| {
        uart_buf_reg.* = b; // we write bytes one by one to UART fifo register (and quemu prints them)
    }
    //syscon.* = 0x5555; // send powerdown; commented, cause qemu restarts image, making it an infinite loop of hello worlds
}
