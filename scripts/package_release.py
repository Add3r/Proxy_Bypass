#!/usr/bin/env python3
"""Package explicit release inputs; never collect arbitrary untracked files."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def archive(destination, members):
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as output:
        for name, path in sorted(members.items()):
            if path.is_symlink() or not path.is_file():
                raise SystemExit(f"Missing or symlinked release input: {path}")
            output.write(path, name)
    with zipfile.ZipFile(destination) as check:
        if check.testzip():
            raise SystemExit(f"Invalid archive: {destination}")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("output", nargs="?", default=str(ROOT / "release"))
    args = parser.parse_args()
    if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", args.version):
        parser.error("Version must be vMAJOR.MINOR.PATCH")
    for script, extra in (("check_libraries.py", []), ("release_integrity.py", ["verify", "all"])):
        subprocess.run(["python3", str(ROOT / "scripts" / script), *extra], check=True)
    version = args.version[1:]
    cargo = (ROOT / "Rust/Cargo.toml").read_text()
    if not re.search(r'^version = "' + re.escape(version) + '"$', cargo, re.M):
        parser.error("Rust version does not match release tag")
    for browser in ("chrome", "firefox"):
        manifest = ROOT / f"Browser-extensions/{browser}-user-agent-switcher/manifest.json"
        if json.loads(manifest.read_text())["version"] != version:
            parser.error("Browser version does not match release tag")
    out = Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        parser.error("Output directory must be empty")
    prefix = f"proxy-bypass-{args.version}"
    common = {name: ROOT / name for name in ("LICENSE", "SECURITY_REVIEW.md")}
    targets = {
        "macos-arm64": "aarch64-apple-darwin", "macos-x64": "x86_64-apple-darwin",
        "linux-x64": "x86_64-unknown-linux-gnu", "linux-arm64": "aarch64-unknown-linux-gnu",
        "windows-x64": "x86_64-pc-windows-gnu.exe",
    }
    for platform, target in targets.items():
        name = "proxy_bypass_" + target
        archive(out / f"{prefix}-{platform}.zip",
                {**common, name: ROOT / "Rust/dist" / name, "README.md": ROOT / "Rust/README.md"})
    for language, files in {
        "powershell": ["proxy_bypass.ps1", "ProxyBypass.psm1", "user_agents.json", "README.md"],
        "python": ["proxy_bypass.py", "user_agents.json", "README.md"],
    }.items():
        folder = "Powershell" if language == "powershell" else "Python"
        archive(out / f"{prefix}-{language}.zip",
                {**common, **{name: ROOT / folder / name for name in files}})
    shutil.copyfile(ROOT / "Burp-extension/UserAgentFuzzer.jar", out / f"{prefix}-burp.jar")
    for browser, suffix in (("chrome", "chrome-edge.zip"), ("firefox", "firefox.xpi")):
        folder = ROOT / f"Browser-extensions/{browser}-user-agent-switcher"
        files = ("manifest.json", "popup.html", "popup.css", "popup.js", "service-worker.js",
                 "user_agents.json", "README.md")
        archive(out / f"{prefix}-{suffix}", {**common, **{name: folder / name for name in files}})
    source = {name: ROOT / name for name in (
        ".gitignore", "LICENSE", "README.md", "SECURITY.md", "SECURITY_REVIEW.md",
        "RELEASE_NOTES.md", "RELEASING.md", "Rust/Cargo.toml", "Rust/Cargo.lock",
        "Rust/build_targets.sh", "Burp-extension/GSON-LICENSE", "Burp-extension/MONTOYA-LICENSE",
        "Burp-extension/gson-2.14.0.jar", "Burp-extension/montoya-api-2025.10.jar")}
    patterns = {
        "Python": ["*.py", "*.json", "*.md"], "Powershell": ["*.ps1", "*.psm1", "*.json", "*.md"],
        "Rust": ["README.md", "src/*.rs", "src/*.json"],
        "Burp-extension": ["*.java", "user_agents.json", "README.md"],
        "Browser-extensions": ["README.md", "*/*.js", "*/*.json", "*/*.html", "*/*.css", "*/*.md"],
        "scripts": ["*.py", "*.sh"], "tests": ["*.py", "*.cjs", "*.ps1", "*.java"],
        ".github/workflows": ["*.yml"], "images": ["*.png", "*.gif"],
    }
    for directory, globs in patterns.items():
        for glob in globs:
            for path in (ROOT / directory).glob(glob):
                source[path.relative_to(ROOT).as_posix()] = path
    archive(out / f"{prefix}-source.zip", source)
    for name in ("RELEASE_NOTES.md", "SECURITY_REVIEW.md"):
        shutil.copyfile(ROOT / name, out / name)
    checksums = [f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n"
                 for path in sorted(out.iterdir())]
    (out / "SHA256SUMS.txt").write_text("".join(checksums), encoding="utf-8")
    print(f"Release assets created in {out}")

if __name__ == "__main__":
    main()
