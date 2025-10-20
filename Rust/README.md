# Proxy_Bypass → Rust Client

This directory contains the Rust rewrite of the **proxy_bypass** utility. It mirrors the Python feature set—loading user‑agents. In addition, the Rust project adds:

- A self‑contained binary that runs anywhere (no interpreter required).
- Cross‑compiled artifacts for macOS, Linux, and Windows inside `dist/`.

## Dist binaries

`dist/` is populated by the build script and contains stripped release binaries named `proxy_bypass_<target>` (or `.exe` for Windows). The macOS arm64 build will run natively on M‑series machines; x86_64 builds target Intel macOS and 64‑bit Linux. Copy `user_agents.json` alongside the binary when redistributing.

Example:

```
dist/
├── proxy_bypass_aarch64-apple-darwin
├── proxy_bypass_x86_64-apple-darwin
├── proxy_bypass_x86_64-unknown-linux-gnu
├── proxy_bypass_aarch64-unknown-linux-gnu
└── proxy_bypass_x86_64-pc-windows-gnu.exe
```

