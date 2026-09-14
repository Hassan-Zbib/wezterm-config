// Prints the percentage of physical RAM in use, e.g. `48`, and nothing else.
//
// Why this exists at all.
//
// `update-status` (see events/right-status.lua) is synchronous: WezTerm
// schedules the next tick only once the handler returns, so every millisecond
// spent in there delays *all* of the segments -- workspace, date, battery,
// overlay opacity -- not just the RAM readout. Windows has no cheap way to ask
// for a memory figure from Lua:
//
//   * `wmic` was the usual answer and is gone; Microsoft removed it in 24H2.
//   * `Get-CimInstance Win32_OperatingSystem` works but pays PowerShell's
//     startup cost every single call -- measured at ~220ms on this machine.
//   * `fastfetch -s Memory` is ~125ms and would couple the status bar to
//     fastfetch's output format.
//
// Calling GlobalMemoryStatusEx directly costs ~6ms, which is ~35x cheaper than
// the PowerShell round trip and small enough that the cache in right-status.lua
// exists for tidiness rather than necessity.
//
// `dwMemoryLoad` is already "percent of physical memory in use", so there is no
// arithmetic here to drift out of sync with what Task Manager reports.
//
// Build (no dependencies, no Cargo project needed):
//   rustc -O --edition 2021 scripts/ramload.rs -o bin/ramload.exe

#[repr(C)]
struct MemoryStatusEx {
    dw_length: u32,
    dw_memory_load: u32,
    ull_total_phys: u64,
    ull_avail_phys: u64,
    ull_total_page_file: u64,
    ull_avail_page_file: u64,
    ull_total_virtual: u64,
    ull_avail_virtual: u64,
    ull_avail_extended_virtual: u64,
}

#[link(name = "kernel32")]
extern "system" {
    fn GlobalMemoryStatusEx(buffer: *mut MemoryStatusEx) -> i32;
}

fn main() {
    let mut status: MemoryStatusEx = unsafe { std::mem::zeroed() };
    // GlobalMemoryStatusEx rejects the call unless dwLength is set up front.
    status.dw_length = std::mem::size_of::<MemoryStatusEx>() as u32;

    unsafe {
        if GlobalMemoryStatusEx(&mut status) == 0 {
            // Exit non-zero and print nothing; the caller falls back to
            // PowerShell rather than rendering a bogus number.
            std::process::exit(1);
        }
        println!("{}", status.dw_memory_load);
    }
}
