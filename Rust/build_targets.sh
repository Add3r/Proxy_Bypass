#!/usr/bin/env bash
#
# Build release binaries for multiple targets and copy them into ./dist
# with descriptive filenames (e.g. proxy_bypass_x86_64-unknown-linux-gnu).
# Cross builds require the appropriate toolchains (see README).

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

# Configure cross-compilers if they are installed via Homebrew.
export CC_x86_64_unknown_linux_gnu="${CC_x86_64_unknown_linux_gnu:-/opt/homebrew/opt/x86_64-unknown-linux-gnu/bin/x86_64-unknown-linux-gnu-gcc}"
export AR_x86_64_unknown_linux_gnu="${AR_x86_64_unknown_linux_gnu:-/opt/homebrew/opt/x86_64-unknown-linux-gnu/bin/x86_64-unknown-linux-gnu-ar}"
export STRIP_x86_64_unknown_linux_gnu="${STRIP_x86_64_unknown_linux_gnu:-/opt/homebrew/opt/x86_64-unknown-linux-gnu/bin/x86_64-unknown-linux-gnu-strip}"
export CC_aarch64_unknown_linux_gnu="${CC_aarch64_unknown_linux_gnu:-/opt/homebrew/opt/aarch64-unknown-linux-gnu/bin/aarch64-unknown-linux-gnu-gcc}"
export AR_aarch64_unknown_linux_gnu="${AR_aarch64_unknown_linux_gnu:-/opt/homebrew/opt/aarch64-unknown-linux-gnu/bin/aarch64-unknown-linux-gnu-ar}"
export STRIP_aarch64_unknown_linux_gnu="${STRIP_aarch64_unknown_linux_gnu:-/opt/homebrew/opt/aarch64-unknown-linux-gnu/bin/aarch64-unknown-linux-gnu-strip}"
export CC_x86_64_pc_windows_gnu="${CC_x86_64_pc_windows_gnu:-/opt/homebrew/opt/mingw-w64/bin/x86_64-w64-mingw32-gcc}"
export AR_x86_64_pc_windows_gnu="${AR_x86_64_pc_windows_gnu:-/opt/homebrew/opt/mingw-w64/bin/x86_64-w64-mingw32-ar}"
export STRIP_x86_64_pc_windows_gnu="${STRIP_x86_64_pc_windows_gnu:-/opt/homebrew/opt/mingw-w64/bin/x86_64-w64-mingw32-strip}"

export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="$CC_x86_64_unknown_linux_gnu"
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_AR="$AR_x86_64_unknown_linux_gnu"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="$CC_aarch64_unknown_linux_gnu"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_AR="$AR_aarch64_unknown_linux_gnu"
export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="$CC_x86_64_pc_windows_gnu"
export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_AR="$AR_x86_64_pc_windows_gnu"

# Add or remove targets as needed.
TARGETS=(
  "aarch64-apple-darwin"
  "x86_64-apple-darwin"
  "x86_64-unknown-linux-gnu"
  "aarch64-unknown-linux-gnu"
  "x86_64-pc-windows-gnu"
)

for TARGET in "${TARGETS[@]}"; do
  echo
  echo "==> Building for ${TARGET}"
  rustup target add "${TARGET}"

  cargo build --locked --release --target "${TARGET}"

  if [[ "${TARGET}" == *windows* ]]; then
    BIN_SRC="target/${TARGET}/release/proxy_bypass.exe"
    BIN_DEST="${DIST_DIR}/proxy_bypass_${TARGET}.exe"
    if [[ -f "${BIN_SRC}" ]]; then
      if command -v "${STRIP_x86_64_pc_windows_gnu}" >/dev/null 2>&1; then
        "${STRIP_x86_64_pc_windows_gnu}" "${BIN_SRC}" || true
      fi
      cp "${BIN_SRC}" "${BIN_DEST}"
      echo "[INFO] Copied ${BIN_SRC} -> ${BIN_DEST}"
    else
      echo "[WARN] Expected binary ${BIN_SRC} not found."
    fi
  else
    BIN_SRC="target/${TARGET}/release/proxy_bypass"
    BIN_DEST="${DIST_DIR}/proxy_bypass_${TARGET}"
    if [[ -f "${BIN_SRC}" ]]; then
      case "${TARGET}" in
        x86_64-unknown-linux-gnu)
          if command -v "${STRIP_x86_64_unknown_linux_gnu}" >/dev/null 2>&1; then
            "${STRIP_x86_64_unknown_linux_gnu}" "${BIN_SRC}" || true
          fi
          ;;
        aarch64-unknown-linux-gnu)
          if command -v "${STRIP_aarch64_unknown_linux_gnu}" >/dev/null 2>&1; then
            "${STRIP_aarch64_unknown_linux_gnu}" "${BIN_SRC}" || true
          fi
          ;;
        *)
          if command -v strip >/dev/null 2>&1; then
            strip "${BIN_SRC}" || true
          fi
          ;;
      esac
      cp "${BIN_SRC}" "${BIN_DEST}"
      echo "[INFO] Copied ${BIN_SRC} -> ${BIN_DEST}"
    else
      echo "[WARN] Expected binary ${BIN_SRC} not found."
    fi
  fi
done

echo
python3 ../scripts/release_integrity.py record rust
echo "[INFO] Finished. Binaries are in ${DIST_DIR}/"
