// idk if its even remotely compilable. Should first figure out build.zig

//var stack_bytes: [128 * 1024]u8 align(16) linksection(".bss") = undefined;
extern const __bss: [*]u8;
extern const __bss_end: [*]u8;
extern const __stack_top: [*]u8;

pub fn kernel_main() linksection(".text.boot") callconv(.Naked) noreturn {
    //asm volatile ("la sp, _sstack"); // set stack pointer
    memset(__bss, 0, __bss_end - __bss);
}

pub fn memset(buf: *anyopaque, c: u8, n: usize) void {
    var i = n;
    var b: []u8 = @ptrCast(buf);
    while (i > 0) : (i -= 1) {
        b[i] = c;
    }
    //return b;
}
