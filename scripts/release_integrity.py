#!/usr/bin/env python3
"""Detect stale release binaries. Manifests are local checks, not signatures."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GROUPS = {
    "rust": (
        ["Rust/Cargo.toml", "Rust/Cargo.lock", "Rust/src/main.rs", "Rust/src/user_agents.json",
         "Rust/build_targets.sh"],
        ["Rust/dist/proxy_bypass_" + target for target in (
            "aarch64-apple-darwin", "x86_64-apple-darwin", "x86_64-unknown-linux-gnu",
            "aarch64-unknown-linux-gnu", "x86_64-pc-windows-gnu.exe")],
        "Rust/dist/build-manifest.json"),
    "burp": (
        ["Burp-extension/UserAgentFuzzer.java", "Burp-extension/user_agents.json",
         "Burp-extension/gson-2.14.0.jar", "Burp-extension/montoya-api-2025.10.jar",
         "Burp-extension/GSON-LICENSE", "Burp-extension/README.md", "LICENSE", "scripts/build_burp.py"],
        ["Burp-extension/UserAgentFuzzer.jar"], "Burp-extension/build-manifest.json"),
}

def snapshot(group):
    sources, artifacts, _ = GROUPS[group]
    return {kind: {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                   for name in names} for kind, names in (("sources", sources), ("artifacts", artifacts))}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["record", "verify"])
    parser.add_argument("group", choices=list(GROUPS) + ["all"])
    args = parser.parse_args()
    for group in GROUPS if args.group == "all" else [args.group]:
        manifest = ROOT / GROUPS[group][2]
        actual = snapshot(group)
        if args.action == "record":
            manifest.write_text(json.dumps(actual, indent=2) + "\n", encoding="utf-8")
        elif json.loads(manifest.read_text(encoding="utf-8")) != actual:
            raise SystemExit(f"Stale or modified {group} build. Rebuild before packaging.")
        print(f"{group}: {args.action} passed")

if __name__ == "__main__":
    main()
