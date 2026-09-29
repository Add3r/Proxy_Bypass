import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("proxy_bypass", ROOT / "Python/proxy_bypass.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CurlSecurityTests(unittest.TestCase):
    def test_no_shell_and_explicit_proxy(self):
        with patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "204")) as run:
            self.assertEqual(module.UserAgentTester.run_curl("localhost:8080", "$(id); 'quoted'", "example.test"), "204")
            command = run.call_args.args[0]
            self.assertEqual(command[:2], ["curl", "-q"])
            self.assertEqual(command[command.index("--noproxy") + 1], "")
            self.assertEqual(command[-2:], ["--url", "https://example.test"])
            self.assertEqual(command[command.index("--user-agent") + 1], "$(id); 'quoted'")
            self.assertNotIn("shell", run.call_args.kwargs)

    def test_injection_and_non_http_targets_rejected(self):
        with patch.object(module.subprocess, "run") as run:
            for ua in ["UA\r\nInjected: true", "UA\x00", "UA\x7f"]:
                self.assertEqual(module.UserAgentTester.run_curl("localhost:8080", ua, "https://example.test"), "")
            for target in ["--config=/tmp/config", "file:///etc/passwd", "ftp://example.test", "https://example.test/\n"]:
                self.assertEqual(module.UserAgentTester.run_curl("localhost:8080", "UA", target), "")
            run.assert_not_called()

    def test_failure_status_is_not_success(self):
        with patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 60, "200")):
            self.assertEqual(module.UserAgentTester.run_curl("localhost:8080", "UA", "example.test"), "")

    def test_only_final_2xx_is_success(self):
        tester = module.UserAgentTester(str(ROOT / "Python/user_agents.json"))
        for status in ["403", "HTTP/1.1 200 Connection established\r\nHTTP/2 403", "204"]:
            with patch.object(tester, "run_curl", return_value=status):
                tester.test_user_agent("localhost:8080", {"user-agent": "UA"})
        self.assertEqual((tester.success_count, tester.denied_count), (1, 2))


if __name__ == "__main__":
    unittest.main()
