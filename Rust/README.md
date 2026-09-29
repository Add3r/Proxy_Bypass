# Proxy_Bypass → Rust Client

This directory contains the Rust rewrite of the **proxy_bypass** utility. It mirrors the Python feature set, including browser-group, ID, unique-group, platform, batch, proxy, target, output, and custom-file options. The bundled 11,170-record library includes the `AI` platform:

```bash
cargo run -- -P ai
cargo run -- -B AI-Agents
```

In addition, the Rust project adds:

- A standalone executable for each listed target (no interpreter required; OS/runtime compatibility still applies).
- Release artifacts for macOS, Linux, and Windows inside `dist/`.

## Dist binaries

`dist/` is populated by the build script and contains stripped release binaries named `proxy_bypass_<target>` (or `.exe` for Windows). The macOS arm64 build will run natively on M‑series machines; x86_64 builds target Intel macOS and 64‑bit Linux. The canonical library is compiled into the binary as the default, so a copied binary works without an interpreter or adjacent JSON file. Supplying `--useragent-file` still overrides the embedded library.

Example:

```
dist/
├── proxy_bypass_aarch64-apple-darwin
├── proxy_bypass_x86_64-apple-darwin
├── proxy_bypass_x86_64-unknown-linux-gnu
├── proxy_bypass_aarch64-unknown-linux-gnu
└── proxy_bypass_x86_64-pc-windows-gnu.exe
```
