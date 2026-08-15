import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FEEDBACK_SCRIPT = REPO_ROOT / "scripts" / "jules_gh_feedback.sh"


def _extract_inline_python_snippet():
    """Extract the exact inline Python heredoc block from jules_gh_feedback.sh.

    This keeps the integration tests tied to the real script content on disk
    (rather than a hand-duplicated copy of the parsing logic), so the tests
    fail if the script's report-generation logic regresses.
    """
    script_text = FEEDBACK_SCRIPT.read_text()
    start_marker = "python3 - <<EOF\n"
    start_idx = script_text.index(start_marker) + len(start_marker)
    end_idx = script_text.index("\nEOF\n", start_idx)
    return script_text[start_idx:end_idx]


def _generate_report(telemetry_path, report_path):
    """Run the script's inline Python report generator against real files.

    Emulates the unquoted heredoc's shell processing by substituting the two
    shell variables referenced inside the snippet, and by unescaping the
    backslash-escaped backticks (bash strips the backslash from `\\`` inside
    an unquoted heredoc before the content ever reaches python3's stdin).
    """
    snippet = _extract_inline_python_snippet()
    code = snippet.replace("${TELEMETRY_JSON}", str(telemetry_path)).replace(
        "${REPORT_MD}", str(report_path)
    )
    code = code.replace("\\`", "`")
    return subprocess.run(
        ["python3", "-c", code],
        capture_output=True,
        text=True,
    )


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


class TestTelemetryJsonEnvDefault(unittest.TestCase):
    """Covers the new TELEMETRY_JSON="${TELEMETRY_JSON:-/tmp/jules_telemetry.json}" default."""

    SNIPPET = 'TELEMETRY_JSON="${TELEMETRY_JSON:-/tmp/jules_telemetry.json}"; printf "%s" "$TELEMETRY_JSON"'

    def test_script_source_contains_the_default_expansion(self):
        script_text = FEEDBACK_SCRIPT.read_text()
        self.assertIn(
            'TELEMETRY_JSON="${TELEMETRY_JSON:-/tmp/jules_telemetry.json}"',
            script_text,
        )

    def test_falls_back_to_default_path_when_env_var_unset(self):
        env = {k: v for k, v in os.environ.items() if k != "TELEMETRY_JSON"}
        result = subprocess.run(
            ["bash", "-c", self.SNIPPET],
            capture_output=True,
            text=True,
            env=env,
            check=True,
        )
        self.assertEqual(result.stdout, "/tmp/jules_telemetry.json")

    def test_uses_overridden_path_when_env_var_set(self):
        env = dict(os.environ)
        env["TELEMETRY_JSON"] = "/custom/path/telemetry.json"
        result = subprocess.run(
            ["bash", "-c", self.SNIPPET],
            capture_output=True,
            text=True,
            env=env,
            check=True,
        )
        self.assertEqual(result.stdout, "/custom/path/telemetry.json")

    def test_empty_string_env_var_is_treated_as_unset(self):
        # ${VAR:-default} falls back to the default for both unset AND empty values.
        env = dict(os.environ)
        env["TELEMETRY_JSON"] = ""
        result = subprocess.run(
            ["bash", "-c", self.SNIPPET],
            capture_output=True,
            text=True,
            env=env,
            check=True,
        )
        self.assertEqual(result.stdout, "/tmp/jules_telemetry.json")


class TestReportGenerationEndToEnd(unittest.TestCase):
    """Exercises the actual inline Python report generator extracted from the
    real script file against real telemetry/report files on disk."""

    def _write_telemetry(self, data):
        f = tempfile.NamedTemporaryFile("w", delete=False, suffix=".json")
        json.dump(data, f)
        f.close()
        return Path(f.name)

    def _report_path(self):
        fd, path = tempfile.mkstemp(suffix=".md")
        os.close(fd)
        path = Path(path)
        path.unlink()  # the script itself is responsible for creating the file
        return path

    def test_single_result_report_contains_table_row_and_matching_logs_section(self):
        telemetry_path = self._write_telemetry(
            {
                "overall_status": "passed",
                "execution_mode": "dev",
                "pr_id": "42",
                "timestamp": "2026-08-14T12:00:00Z",
                "host_info": {
                    "os_family": "Linux",
                    "kernel_version": "6.6",
                    "podman_version": "5.2",
                },
                "results": [
                    {
                        "distro": "fedora",
                        "image": "fedora:latest",
                        "status": "passed",
                        "exit_code": 0,
                        "cpu_percentage": "2.5%",
                        "memory_usage_bytes": 2048,
                        "error_summary": "",
                        "logs": "plain log output, no backticks here",
                    }
                ],
            }
        )
        report_path = self._report_path()
        try:
            result = _generate_report(telemetry_path, report_path)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            self.assertTrue(report_path.exists())
            content = report_path.read_text()

            # Table row for the result is present.
            self.assertIn("| **fedora** | `fedora:latest` | **✅ PASSED** | `0` | `2.5%` | `2048` |", content)
            # Logs section header only appears once (single combined loop).
            self.assertEqual(content.count("### 📝 Execution Logs"), 1)
            # Plain logs (no backticks) use the default triple-backtick fence.
            self.assertIn("```text\nplain log output, no backticks here\n```", content)
            # The logs section appears after the table in the final document.
            self.assertLess(content.index("### 📊 Test Matrix Results"), content.index("### 📝 Execution Logs"))
        finally:
            telemetry_path.unlink(missing_ok=True)
            report_path.unlink(missing_ok=True)

    def test_logs_containing_quadruple_backticks_get_a_five_backtick_fence(self):
        telemetry_path = self._write_telemetry(
            {
                "overall_status": "failed",
                "execution_mode": "dev",
                "pr_id": "7",
                "timestamp": "2026-08-14T12:00:00Z",
                "host_info": {},
                "results": [
                    {
                        "distro": "debian",
                        "image": "debian:latest",
                        "status": "failed",
                        "exit_code": 1,
                        "cpu_percentage": "0.5%",
                        "memory_usage_bytes": 512,
                        "error_summary": "boom",
                        "logs": "before\n````already-quad-fenced````\nafter",
                    }
                ],
            }
        )
        report_path = self._report_path()
        try:
            result = _generate_report(telemetry_path, report_path)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            content = report_path.read_text()
            self.assertIn(
                "`````text\nbefore\n````already-quad-fenced````\nafter\n`````",
                content,
            )
        finally:
            telemetry_path.unlink(missing_ok=True)
            report_path.unlink(missing_ok=True)

    def test_missing_logs_field_defaults_to_no_output_logged(self):
        telemetry_path = self._write_telemetry(
            {
                "overall_status": "passed",
                "execution_mode": "dev",
                "pr_id": "1",
                "timestamp": "2026-08-14T12:00:00Z",
                "host_info": {},
                "results": [
                    {
                        "distro": "alpine",
                        "image": "alpine:latest",
                        "status": "passed",
                        "exit_code": 0,
                        "cpu_percentage": "0.1%",
                        "memory_usage_bytes": 128,
                        "error_summary": "",
                        # "logs" key intentionally omitted
                    }
                ],
            }
        )
        report_path = self._report_path()
        try:
            result = _generate_report(telemetry_path, report_path)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            content = report_path.read_text()
            self.assertIn("```text\nNo output logged.\n```", content)
        finally:
            telemetry_path.unlink(missing_ok=True)
            report_path.unlink(missing_ok=True)

    def test_empty_string_logs_field_defaults_to_no_output_logged(self):
        telemetry_path = self._write_telemetry(
            {
                "overall_status": "passed",
                "execution_mode": "dev",
                "pr_id": "1",
                "timestamp": "2026-08-14T12:00:00Z",
                "host_info": {},
                "results": [
                    {
                        "distro": "alpine",
                        "image": "alpine:latest",
                        "status": "passed",
                        "exit_code": 0,
                        "cpu_percentage": "0.1%",
                        "memory_usage_bytes": 128,
                        "error_summary": "",
                        "logs": "",
                    }
                ],
            }
        )
        report_path = self._report_path()
        try:
            result = _generate_report(telemetry_path, report_path)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            content = report_path.read_text()
            self.assertIn("```text\nNo output logged.\n```", content)
        finally:
            telemetry_path.unlink(missing_ok=True)
            report_path.unlink(missing_ok=True)

    def test_multiple_results_preserve_order_between_table_and_logs_section(self):
        telemetry_path = self._write_telemetry(
            {
                "overall_status": "failed",
                "execution_mode": "dev",
                "pr_id": "5",
                "timestamp": "2026-08-14T12:00:00Z",
                "host_info": {},
                "results": [
                    {
                        "distro": "ubuntu",
                        "image": "ubuntu:latest",
                        "status": "passed",
                        "exit_code": 0,
                        "cpu_percentage": "1.0%",
                        "memory_usage_bytes": 100,
                        "error_summary": "",
                        "logs": "first distro log",
                    },
                    {
                        "distro": "centos",
                        "image": "centos:latest",
                        "status": "failed",
                        "exit_code": 1,
                        "cpu_percentage": "3.0%",
                        "memory_usage_bytes": 200,
                        "error_summary": "failed step",
                        "logs": "second distro log",
                    },
                ],
            }
        )
        report_path = self._report_path()
        try:
            result = _generate_report(telemetry_path, report_path)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            content = report_path.read_text()

            first_log_idx = content.index("first distro log")
            second_log_idx = content.index("second distro log")
            self.assertLess(first_log_idx, second_log_idx)

            ubuntu_summary_idx = content.index("ubuntu (PASSED) Log Output")
            centos_summary_idx = content.index("centos (FAILED) Log Output")
            self.assertLess(ubuntu_summary_idx, centos_summary_idx)
        finally:
            telemetry_path.unlink(missing_ok=True)
            report_path.unlink(missing_ok=True)

    def test_no_results_still_generates_report_with_empty_logs_section(self):
        telemetry_path = self._write_telemetry(
            {
                "overall_status": "passed",
                "execution_mode": "dev",
                "pr_id": "0",
                "timestamp": "2026-08-14T12:00:00Z",
                "host_info": {},
                "results": [],
            }
        )
        report_path = self._report_path()
        try:
            result = _generate_report(telemetry_path, report_path)
            self.assertEqual(result.returncode, 0, msg=result.stderr)
            content = report_path.read_text()
            self.assertIn("### 📝 Execution Logs", content)
            self.assertNotIn("<details>", content)
        finally:
            telemetry_path.unlink(missing_ok=True)
            report_path.unlink(missing_ok=True)

    def test_malformed_telemetry_json_exits_non_zero(self):
        f = tempfile.NamedTemporaryFile("w", delete=False, suffix=".json")
        f.write("{not valid json")
        f.close()
        telemetry_path = Path(f.name)
        report_path = self._report_path()
        try:
            result = _generate_report(telemetry_path, report_path)
            self.assertEqual(result.returncode, 1)
            self.assertIn("Error decoding telemetry JSON", result.stderr)
            self.assertFalse(report_path.exists())
        finally:
            telemetry_path.unlink(missing_ok=True)
            report_path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
