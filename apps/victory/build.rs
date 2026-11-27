//! Link settings for the Windows executable.

fn main() {
    // Threads created without a stack size take the executable's default.
    // Host graphics drivers compiling the title's large shaders on such
    // threads overflow the linker's 1 MiB default: reserve 16 MiB instead,
    // and export D3D12 Agility SDK symbols for Windows 10 19041+.
    if std::env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc") {
        println!("cargo:rustc-link-arg-bins=/STACK:16777216");
        println!("cargo:rustc-link-arg-bin=victory=/EXPORT:D3D12SDKVersion,DATA");
        println!("cargo:rustc-link-arg-bin=victory=/EXPORT:D3D12SDKPath,DATA");
    }
}
