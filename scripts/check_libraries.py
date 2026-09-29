#!/usr/bin/env python3
"""Validate library schema and byte parity across every distribution."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = ["Python/user_agents.json", "Powershell/user_agents.json", "Rust/src/user_agents.json",
         "Burp-extension/user_agents.json", "Browser-extensions/chrome-user-agent-switcher/user_agents.json",
         "Browser-extensions/firefox-user-agent-switcher/user_agents.json"]

def main():
    canonical = (ROOT / FILES[0]).read_bytes()
    entries = json.loads(canonical)
    ids = set()
    for entry in entries:
        for key in ("id", "platform", "group", "user-agent"):
            if not isinstance(entry.get(key), str) or not entry[key]:
                raise SystemExit(f"Invalid {key}: {entry}")
        if entry["id"] in ids:
            raise SystemExit("Duplicate library ID")
        ids.add(entry["id"])
        if len(entry["user-agent"]) > 8192 or any(not 32 <= ord(ch) <= 126 for ch in entry["user-agent"]):
            raise SystemExit(f"Invalid header: {entry['id']}")
    for filename in FILES:
        if (ROOT / filename).read_bytes() != canonical:
            raise SystemExit(f"Library mismatch: {filename}")
    print(f"{len(entries)} records; {sum(e['platform'] == 'AI' for e in entries)} AI; all six copies identical")
    print("Library SHA256:", hashlib.sha256(canonical).hexdigest())

if __name__ == "__main__":
    main()
