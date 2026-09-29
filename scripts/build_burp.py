#!/usr/bin/env python3
"""Build the extension against pinned APIs; never bundle Burp API stubs."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BURP = ROOT / "Burp-extension"
DEPENDENCIES = {
    "montoya-api-2025.10.jar": "1cf6624874c38b9b1d689b2019ffe71ad65468b63abbf98bbe5d235cda40fc04",
    "gson-2.14.0.jar": "2cbd119bf1961c28788310963dc80ba65f58cdeec1dd139c8bdb1240faa2c36f",
}

def main():
    for name, expected in DEPENDENCIES.items():
        actual = hashlib.sha256((BURP / name).read_bytes()).hexdigest()
        if actual != expected:
            raise SystemExit(f"Dependency checksum mismatch: {name}")
    with tempfile.TemporaryDirectory(prefix="proxy-bypass-burp-") as directory:
        classes = Path(directory)
        subprocess.run(["javac", "--release", "17", "-cp",
                        os.pathsep.join(str(BURP / name) for name in DEPENDENCIES),
                        "-d", directory, str(BURP / "UserAgentFuzzer.java")], check=True)
        with zipfile.ZipFile(BURP / "UserAgentFuzzer.jar", "w", zipfile.ZIP_DEFLATED) as output:
            for path in sorted(classes.glob("*.class")):
                output.write(path, path.name)
            output.write(BURP / "user_agents.json", "user_agents.json")
            output.write(ROOT / "LICENSE", "LICENSE")
            output.write(BURP / "GSON-LICENSE", "GSON-LICENSE")
            output.write(BURP / "README.md", "README.md")
            with zipfile.ZipFile(BURP / "gson-2.14.0.jar") as gson:
                for name in gson.namelist():
                    if name.startswith("com/google/gson/") and name.endswith(".class"):
                        output.writestr(name, gson.read(name))
    subprocess.run(["python3", str(ROOT / "scripts/release_integrity.py"), "record", "burp"], check=True)
    print("Built Java 17 UserAgentFuzzer.jar (Gson bundled, Montoya provided by Burp).")

if __name__ == "__main__":
    main()
