import json
import os
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FEEDBACK_SCRIPT = REPO_ROOT / "scripts" / "jules_gh_feedback.sh"


class TestJulesGhFeedback(unittest.TestCase):
    def test_logs_with_triple_backticks_escaping(self):
        telemetry_data = {
            "overall_status": "passed",
            "execution_mode": "dev",
            "pr_id": "99",
            "timestamp": "2026-08-14T12:00:00Z",
            "host_info": {
                "os_family": "Linux",
                "kernel_version": "6.6",
                "podman_version": "5.2",
            },
            "results": [
                {
                    "distro": "ubuntu",
                    "image": "ubuntu:latest",
                    "status": "passed",
                    "exit_code": 0,
                    "cpu_percentage": "1.0%",
                    "memory_usage_bytes": 1024,
                    "error_summary": "",
                    "logs": "Sample log output\n```python\nprint('hello')\n```\nMore log output",
                }
            ],
        }

        telemetry_path = "/tmp/test_jules_telemetry.json"
        with open(telemetry_path, "w") as f:
            json.dump(telemetry_data, f)

        try:
            env = {
                "TELEMETRY_JSON": telemetry_path,
                "EXECUTION_MODE": "dev",
                "KEEP_REPORT": "1",
                "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            }
            res = subprocess.run(
                [str(FEEDBACK_SCRIPT)],
                env=env,
                capture_output=True,
                text=True,
                check=True,
            )
            output = res.stdout + res.stderr
            report_line = [
                line for line in output.splitlines() if "Markdown report generated at" in line
            ][0]
            report_path = report_line.split("'")[1]

            with open(report_path, "r") as rf:
                content = rf.read()

            self.assertIn("````text\nSample log output\n```python\nprint('hello')\n```\nMore log output\n````", content)
        finally:
            if os.path.exists(telemetry_path):
                os.remove(telemetry_path)


if __name__ == "__main__":
    unittest.main()
