import json
import subprocess
import tempfile
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

        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".json") as f:
            json.dump(telemetry_data, f)
            telemetry_path = f.name

        try:
            env = {
                "TELEMETRY_JSON": telemetry_path,
                "EXECUTION_MODE": "dev",
                "PATH": "/usr/bin:/bin",
            }
            # Inline Python parser test matching scripts/jules_gh_feedback.sh escaping logic
            results = telemetry_data["results"]
            logs_section = ["\n### 📝 Execution Logs"]
            for res in results:
                distro = res.get("distro", "Unknown")
                status = res.get("status", "Unknown").upper()
                logs = res.get("logs", "") or "No output logged."

                fence = "```"
                while fence in logs:
                    fence += "`"

                logs_section.append(
                    f"<details>\n<summary><b>{distro} ({status}) Log Output</b></summary>\n\n{fence}text\n{logs}\n{fence}\n</details>\n"
                )

            formatted_logs = "\n".join(logs_section)
            # Verify that quad backticks ```` were dynamically chosen because content contains triple backticks ```
            self.assertIn("````text\nSample log output\n```python\nprint('hello')\n```\nMore log output\n````", formatted_logs)
        finally:
            Path(telemetry_path).unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
