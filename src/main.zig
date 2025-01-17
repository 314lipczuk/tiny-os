// idk if its even remotely compilable. Should first figure out build.zig

//var stack_bytes: [128 * 1024]u8 align(16) linksection(".bss") = undefined;
extern const __bss: [*]u8;
extern const __bss_end: [*]u8;
extern const __stack_top: [*]u8;

const SYSCON_REG_ADDR: usize = 0x11100000;
const UART_BUF_REG_ADDR: usize = 0x10000000;

const syscon: *volatile u32 = @ptrFromInt(SYSCON_REG_ADDR);
const uart_buf_reg: *volatile u8 = @ptrFromInt(UART_BUF_REG_ADDR);

//TODO: figure out the linker script fuckups
pub fn _start() linksection("boot") callconv(.Naked) noreturn {
    asm volatile ("la sp, _sstack"); // set stack pointer
    memset(__bss, 0, __bss_end - __bss);
    for ("Hello world\n") |b| {
        uart_buf_reg.* = b;
    }
    syscon.* = 0x5555;
    while (true) {}
}

pub fn memset(buf: *anyopaque, c: u8, n: usize) void {
    var i = n;
    var b: []u8 = @ptrCast(buf);
    while (i > 0) : (i -= 1) {
        b[i] = c;
    }
    //return b;
} // ab
