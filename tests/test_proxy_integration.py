"""Loopback-only integration checks. Requires permission to bind localhost."""
import http.server
import os
import platform
from pathlib import Path
import subprocess
import threading
import tempfile
import unittest
from unittest.mock import patch
from test_security import module

ROOT = Path(__file__).resolve().parents[1]


class ProxyIntegrationTests(unittest.TestCase):
    def test_python_and_powershell_use_proxy_despite_no_proxy(self):
        requests = []

        class Proxy(http.server.BaseHTTPRequestHandler):
            def do_HEAD(self):
                requests.append((self.path, self.headers.get("User-Agent")))
                self.send_response(204)
                self.end_headers()

            def log_message(self, *args):
                pass

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        address = f"127.0.0.1:{server.server_port}"
        ua = 'Test "quoted" $(whoami); UA'
        try:
            with patch.dict(os.environ, {"NO_PROXY": "*", "no_proxy": "*"}):
                self.assertEqual(module.UserAgentTester.run_curl(address, ua, "http://example.invalid/"), "204")
                result = subprocess.run(["pwsh", "-NoProfile", "-Command",
                    "Import-Module ./Powershell/ProxyBypass.psm1 -Force; "
                    "& (Get-Module ProxyBypass) { "
                    "Invoke-UserAgentRequest -Proxy $env:TEST_PROXY -UserAgent $env:TEST_UA "
                    "-Target 'http://example.invalid/' }"],
                    cwd=ROOT, env={**os.environ, "TEST_PROXY": address, "TEST_UA": ua},
                    capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), "204", result.stderr)
            self.assertEqual(requests, [("http://example.invalid/", ua)] * 2)
            with tempfile.TemporaryDirectory(prefix="proxy-bypass-test-") as directory:
                commands = [
                    ["python3", "Python/proxy_bypass.py", "-s", "ua-11101", "-p", address,
                     "-T", "http://example.invalid/", "-O", str(Path(directory) / "python")],
                    ["pwsh", "-NoProfile", "-File", "Powershell/proxy_bypass.ps1",
                     "-s", "ua-11101", "-p", address, "-T", "http://example.invalid/",
                     "-O", str(Path(directory) / "powershell")],
                ]
                native_targets = {("Darwin", "arm64"): "aarch64-apple-darwin",
                                  ("Linux", "x86_64"): "x86_64-unknown-linux-gnu"}
                target = native_targets.get((platform.system(), platform.machine()))
                if target:
                    binary = ROOT / "Rust/dist" / ("proxy_bypass_" + target)
                    if binary.exists():
                        commands.append([str(binary), "-s", "ua-11101", "-p", address,
                            "-T", "http://example.invalid/", "-O", str(Path(directory) / "rust")])
                for command in commands:
                    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=30)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertTrue(Path(command[-1]).read_text().strip(), result.stdout)
                self.assertEqual(len(requests), 2 + len(commands))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
