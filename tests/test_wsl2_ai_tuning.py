#!/usr/bin/env python3
"""
Unit tests for scripts/wsl2_ai_tuning.py, the WSL2 AI Performance & Security
Tuning utility introduced alongside docs/WSL2_AI_PERFORMANCE_TUNING.md.

Covers:
  - calculate_wsl_memory(): RAM-tier thresholds and the "never exceed
    host RAM - 2GB" clamp (including the low-RAM edge cases where the
    clamp itself is skipped).
  - detect_distro(): /etc/os-release ID mapping to the almalinux/ubuntu/
    generic family buckets, and the missing-file fallback.
  - generate_wslconfig() / generate_wsl_conf(): static content generation.
  - check_security(): environment-variable presence reporting, hardcoded
    API key detection in ~/.claude/settings.json, and sensitive dotfile
    permission reporting.
  - get_sysctl_val(): sysctl output parsing and failure handling.
  - get_host_hardware(): PowerShell-interop / psutil / /proc/meminfo
    fallback chain.
  - apply_tuning(): both the non-root (no-op/warning) path and the
    root path, with all real filesystem writes redirected into a
    temporary directory so no actual system files are touched.
  - main(): CLI argument validation (--mode/--distro choices) and the
    --check/--apply default-to-check behavior, invoked as a subprocess.
"""
import importlib.util
import io
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest import mock

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "scripts" / "wsl2_ai_tuning.py"


def _load_script_module():
    spec = importlib.util.spec_from_file_location("wsl2_ai_tuning", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


wsl2_ai_tuning = _load_script_module()


def _make_fake_path_class(mapping=None, home=None):
    """
    Builds a drop-in replacement for pathlib.Path that redirects specific
    hardcoded absolute-path strings (used verbatim as the sole constructor
    argument in the script under test) to real, test-controlled pathlib.Path
    instances, and optionally overrides Path.home(). Any other construction
    call falls through to the genuine pathlib.Path implementation.
    """
    mapping = mapping or {}
    real_path_cls = pathlib.Path

    class FakePath:
        def __new__(cls, *args, **kwargs):
            if args and str(args[0]) in mapping:
                return mapping[str(args[0])]
            return real_path_cls(*args, **kwargs)

        @classmethod
        def home(cls):
            return home if home is not None else real_path_cls.home()

    return FakePath


class CalculateWslMemoryTests(unittest.TestCase):
    """Tests for calculate_wsl_memory()."""

    def test_lower_boundary_16gb_resolves_to_10gb(self):
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(16), 10)

    def test_just_above_16gb_is_clamped_below_the_22gb_tier(self):
        # Tier says 22GB, but the "never exceed host RAM - 2GB" clamp caps
        # it at 17 - 2 = 15GB.
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(17), 15)

    def test_exactly_32gb_resolves_to_22gb(self):
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(32), 22)

    def test_just_above_32gb_is_clamped_below_the_48gb_tier(self):
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(33), 31)

    def test_exactly_64gb_resolves_to_48gb(self):
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(64), 48)

    def test_just_above_64gb_is_clamped_below_the_96gb_tier(self):
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(65), 63)

    def test_large_host_128gb_resolves_to_96gb(self):
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(128), 96)

    def test_very_large_host_still_caps_at_96gb_tier(self):
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(256), 96)

    def test_low_ram_host_at_or_below_2gb_skips_the_clamp_entirely(self):
        # host_ram_gb > 2 is False for both of these, so the RAM-minus-2
        # clamp never applies and the raw 10GB tier value is returned
        # even though it exceeds physical RAM.
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(1), 10)
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(2), 10)

    def test_just_above_2gb_clamp_floors_result_at_1gb(self):
        self.assertEqual(wsl2_ai_tuning.calculate_wsl_memory(3), 1)

    def test_return_type_is_int(self):
        self.assertIsInstance(wsl2_ai_tuning.calculate_wsl_memory(32), int)


class DetectDistroTests(unittest.TestCase):
    """Tests for detect_distro()."""

    def _run_with_os_release(self, content):
        with tempfile.TemporaryDirectory() as tmp:
            os_release = pathlib.Path(tmp) / "os-release"
            os_release.write_text(content)
            fake_path = _make_fake_path_class({"/etc/os-release": os_release})
            with mock.patch.object(wsl2_ai_tuning, "Path", fake_path):
                return wsl2_ai_tuning.detect_distro()

    def test_almalinux_id_maps_to_almalinux_family(self):
        family, pretty = self._run_with_os_release(
            'ID="almalinux"\nPRETTY_NAME="AlmaLinux 10 (Purple Lion)"\n'
        )
        self.assertEqual(family, "almalinux")
        self.assertEqual(pretty, "AlmaLinux 10 (Purple Lion)")

    def test_rocky_fedora_rhel_centos_also_map_to_almalinux_family(self):
        for distro_id in ["rocky", "fedora", "rhel", "centos"]:
            with self.subTest(distro_id=distro_id):
                family, _ = self._run_with_os_release(f'ID="{distro_id}"\n')
                self.assertEqual(family, "almalinux")

    def test_ubuntu_id_maps_to_ubuntu_family(self):
        family, pretty = self._run_with_os_release(
            'ID=ubuntu\nPRETTY_NAME="Ubuntu 26.04 LTS"\n'
        )
        self.assertEqual(family, "ubuntu")
        self.assertEqual(pretty, "Ubuntu 26.04 LTS")

    def test_debian_id_also_maps_to_ubuntu_family(self):
        family, _ = self._run_with_os_release('ID=debian\n')
        self.assertEqual(family, "ubuntu")

    def test_unrecognized_id_maps_to_generic_family(self):
        family, pretty = self._run_with_os_release(
            'ID=arch\nPRETTY_NAME="Arch Linux"\n'
        )
        self.assertEqual(family, "generic")
        self.assertEqual(pretty, "Arch Linux")

    def test_id_is_lowercased_before_matching(self):
        family, _ = self._run_with_os_release('ID="Ubuntu"\n')
        self.assertEqual(family, "ubuntu")

    def test_missing_os_release_file_returns_generic_unknown(self):
        fake_path = _make_fake_path_class(
            {"/etc/os-release": pathlib.Path("/nonexistent/os-release-for-test")}
        )
        with mock.patch.object(wsl2_ai_tuning, "Path", fake_path):
            family, pretty = wsl2_ai_tuning.detect_distro()
        self.assertEqual(family, "generic")
        self.assertEqual(pretty, "Unknown Linux Distribution")

    def test_missing_pretty_name_defaults_to_generic_linux_label(self):
        family, pretty = self._run_with_os_release('ID=ubuntu\n')
        self.assertEqual(family, "ubuntu")
        self.assertEqual(pretty, "Generic Linux")


class GenerateWslConfigContentTests(unittest.TestCase):
    """Tests for generate_wslconfig()."""

    def test_default_networking_mode_is_nat(self):
        content = wsl2_ai_tuning.generate_wslconfig(48, 20)
        self.assertIn("networkingMode=nat", content)

    def test_mirrored_mode_is_honored_when_specified(self):
        content = wsl2_ai_tuning.generate_wslconfig(10, 8, "mirrored")
        self.assertIn("networkingMode=mirrored", content)

    def test_memory_and_processor_values_are_interpolated(self):
        content = wsl2_ai_tuning.generate_wslconfig(22, 16, "nat")
        self.assertIn("memory=22GB", content)
        self.assertIn("processors=16", content)

    def test_contains_all_required_wsl2_and_experimental_settings(self):
        content = wsl2_ai_tuning.generate_wslconfig(10, 8)
        for expected in [
            "[wsl2]",
            "swap=16GB",
            "dnsTunneling=true",
            "autoProxy=true",
            "[experimental]",
            "autoMemoryReclaim=gradual",
            "sparseVhd=true",
        ]:
            self.assertIn(expected, content)

    def test_return_type_is_str(self):
        self.assertIsInstance(wsl2_ai_tuning.generate_wslconfig(10, 8), str)


class GenerateWslConfTests(unittest.TestCase):
    """Tests for generate_wsl_conf()."""

    def test_contains_all_required_sections_and_directives(self):
        content = wsl2_ai_tuning.generate_wsl_conf()
        for expected in [
            "[boot]",
            "systemd=true",
            "[automount]",
            "options=metadata,umask=22,fmask=11",
            "[network]",
            "generateHosts=true",
            "generateResolvConf=true",
            "[interop]",
            "appendWindowsPath=true",
            "[gpu]",
            "enabled=true",
            "[time]",
            "useWindowsTimezone=true",
        ]:
            self.assertIn(expected, content)

    def test_output_is_deterministic_across_calls(self):
        self.assertEqual(wsl2_ai_tuning.generate_wsl_conf(), wsl2_ai_tuning.generate_wsl_conf())


class CheckSecurityTests(unittest.TestCase):
    """Tests for check_security()."""

    def _run_with_home(self, home_path, env=None):
        fake_path = _make_fake_path_class(home=home_path)
        env = env or {}
        with mock.patch.dict(os.environ, env, clear=True):
            with mock.patch.object(wsl2_ai_tuning, "Path", fake_path):
                return wsl2_ai_tuning.check_security()

    def test_reports_active_environment_variables(self):
        with tempfile.TemporaryDirectory() as tmp:
            findings = self._run_with_home(
                pathlib.Path(tmp), env={"ANTHROPIC_API_KEY": "sk-ant-fake"}
            )
        joined = "\n".join(findings)
        self.assertIn("ANTHROPIC_API_KEY is active", joined)
        self.assertIn("GEMINI_API_KEY is NOT set", joined)
        self.assertIn("OPENAI_API_KEY is NOT set", joined)

    def test_reports_all_keys_missing_when_env_is_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            findings = self._run_with_home(pathlib.Path(tmp), env={})
        joined = "\n".join(findings)
        self.assertIn("ANTHROPIC_API_KEY is NOT set", joined)
        self.assertIn("GEMINI_API_KEY is NOT set", joined)
        self.assertIn("OPENAI_API_KEY is NOT set", joined)

    def test_warns_on_hardcoded_api_key_in_claude_settings(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            claude_dir = home / ".claude"
            claude_dir.mkdir(parents=True)
            (claude_dir / "settings.json").write_text('{"apiKey": "sk-ant-hardcoded123"}')
            findings = self._run_with_home(home)
        joined = "\n".join(findings)
        self.assertIn("WARNING: Potential hardcoded API key found", joined)

    def test_no_warning_when_claude_settings_has_no_plaintext_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            claude_dir = home / ".claude"
            claude_dir.mkdir(parents=True)
            (claude_dir / "settings.json").write_text('{"theme": "dark"}')
            findings = self._run_with_home(home)
        joined = "\n".join(findings)
        self.assertIn("No plaintext API keys detected", joined)
        self.assertNotIn("WARNING", joined)

    def test_no_claude_settings_finding_when_file_is_absent(self):
        with tempfile.TemporaryDirectory() as tmp:
            findings = self._run_with_home(pathlib.Path(tmp))
        joined = "\n".join(findings)
        self.assertNotIn("settings.json", joined)

    def test_reports_permissions_of_existing_sensitive_dotfiles(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            bashrc = home / ".bashrc"
            bashrc.write_text("export PATH=$PATH")
            os.chmod(bashrc, 0o600)
            findings = self._run_with_home(home)
        joined = "\n".join(findings)
        self.assertIn(str(bashrc), joined)
        self.assertIn("0o600", joined)

    def test_no_permission_finding_when_dotfile_is_absent(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            findings = self._run_with_home(home)
        joined = "\n".join(findings)
        self.assertNotIn(".bashrc", joined)
        self.assertNotIn(".zshrc", joined)

    def test_return_type_is_list_of_strings(self):
        with tempfile.TemporaryDirectory() as tmp:
            findings = self._run_with_home(pathlib.Path(tmp))
        self.assertIsInstance(findings, list)
        self.assertTrue(all(isinstance(f, str) for f in findings))


class GetSysctlValTests(unittest.TestCase):
    """Tests for get_sysctl_val()."""

    def test_parses_valid_numeric_output(self):
        completed = subprocess.CompletedProcess(args=[], returncode=0, stdout="262144\n")
        with mock.patch.object(wsl2_ai_tuning.subprocess, "run", return_value=completed):
            self.assertEqual(wsl2_ai_tuning.get_sysctl_val("vm.max_map_count"), 262144)

    def test_returns_zero_when_command_raises_called_process_error(self):
        with mock.patch.object(
            wsl2_ai_tuning.subprocess,
            "run",
            side_effect=subprocess.CalledProcessError(1, ["sysctl"]),
        ):
            self.assertEqual(wsl2_ai_tuning.get_sysctl_val("vm.max_map_count"), 0)

    def test_returns_zero_when_sysctl_binary_is_missing(self):
        with mock.patch.object(
            wsl2_ai_tuning.subprocess, "run", side_effect=FileNotFoundError()
        ):
            self.assertEqual(wsl2_ai_tuning.get_sysctl_val("vm.max_map_count"), 0)

    def test_returns_zero_when_output_is_not_numeric(self):
        completed = subprocess.CompletedProcess(args=[], returncode=0, stdout="not-a-number\n")
        with mock.patch.object(wsl2_ai_tuning.subprocess, "run", return_value=completed):
            self.assertEqual(wsl2_ai_tuning.get_sysctl_val("vm.max_map_count"), 0)


class GetHostHardwareTests(unittest.TestCase):
    """Tests for get_host_hardware()'s PowerShell / psutil / /proc/meminfo chain."""

    POWERSHELL_BIN = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

    def test_uses_powershell_output_when_available_and_valid(self):
        def exists_side_effect(path):
            return path == self.POWERSHELL_BIN

        def run_side_effect(cmd, **kwargs):
            if "TotalPhysicalMemory" in cmd[-1]:
                return subprocess.CompletedProcess(cmd, 0, stdout=str(64 * 1024**3))
            if "NumberOfLogicalProcessors" in cmd[-1]:
                return subprocess.CompletedProcess(cmd, 0, stdout="20")
            raise AssertionError(f"unexpected command: {cmd}")

        with mock.patch.object(wsl2_ai_tuning.os.path, "exists", side_effect=exists_side_effect), \
             mock.patch.object(wsl2_ai_tuning.subprocess, "run", side_effect=run_side_effect):
            ram_gb, cpus = wsl2_ai_tuning.get_host_hardware()

        self.assertEqual(ram_gb, 64)
        self.assertEqual(cpus, 20)

    def test_falls_back_to_defaults_for_fields_powershell_fails_to_parse(self):
        def exists_side_effect(path):
            return path == self.POWERSHELL_BIN

        def run_side_effect(cmd, **kwargs):
            if "TotalPhysicalMemory" in cmd[-1]:
                return subprocess.CompletedProcess(cmd, 1, stdout="")
            if "NumberOfLogicalProcessors" in cmd[-1]:
                return subprocess.CompletedProcess(cmd, 0, stdout="12")
            raise AssertionError(f"unexpected command: {cmd}")

        with mock.patch.object(wsl2_ai_tuning.os.path, "exists", side_effect=exists_side_effect), \
             mock.patch.object(wsl2_ai_tuning.subprocess, "run", side_effect=run_side_effect):
            ram_gb, cpus = wsl2_ai_tuning.get_host_hardware()

        # mem query failed -> stays at the hardcoded default of 16.
        self.assertEqual(ram_gb, 16)
        self.assertEqual(cpus, 12)

    def test_falls_through_to_fallback_chain_when_powershell_invocation_raises(self):
        def exists_side_effect(path):
            return path == self.POWERSHELL_BIN

        fake_psutil = mock.Mock()
        fake_psutil.virtual_memory.return_value = mock.Mock(total=32 * 1024**3)

        with mock.patch.object(wsl2_ai_tuning.os.path, "exists", side_effect=exists_side_effect), \
             mock.patch.object(
                 wsl2_ai_tuning.subprocess, "run", side_effect=subprocess.TimeoutExpired("ps", 5)
             ), \
             mock.patch.object(wsl2_ai_tuning, "psutil", fake_psutil):
            ram_gb, cpus = wsl2_ai_tuning.get_host_hardware()

        self.assertEqual(ram_gb, 32)
        self.assertEqual(cpus, wsl2_ai_tuning.os.cpu_count() or 8)

    def test_uses_psutil_when_powershell_is_unavailable(self):
        fake_psutil = mock.Mock()
        fake_psutil.virtual_memory.return_value = mock.Mock(total=16 * 1024**3)

        with mock.patch.object(wsl2_ai_tuning.os.path, "exists", return_value=False), \
             mock.patch.object(wsl2_ai_tuning, "psutil", fake_psutil):
            ram_gb, cpus = wsl2_ai_tuning.get_host_hardware()

        self.assertEqual(ram_gb, 16)
        self.assertEqual(cpus, wsl2_ai_tuning.os.cpu_count() or 8)

    def test_falls_back_to_proc_meminfo_when_psutil_and_powershell_are_unavailable(self):
        meminfo_content = (
            "MemTotal:       16777216 kB\n"
            "MemFree:         1048576 kB\n"
        )

        def exists_side_effect(path):
            return path == "/proc/meminfo"

        with mock.patch.object(wsl2_ai_tuning.os.path, "exists", side_effect=exists_side_effect), \
             mock.patch.object(wsl2_ai_tuning, "psutil", None), \
             mock.patch("builtins.open", mock.mock_open(read_data=meminfo_content)):
            ram_gb, cpus = wsl2_ai_tuning.get_host_hardware()

        # 16777216 kB -> 16 GiB
        self.assertEqual(ram_gb, 16)
        self.assertEqual(cpus, wsl2_ai_tuning.os.cpu_count() or 8)

    def test_returns_hardcoded_defaults_when_no_detection_method_is_available(self):
        with mock.patch.object(wsl2_ai_tuning.os.path, "exists", return_value=False), \
             mock.patch.object(wsl2_ai_tuning, "psutil", None):
            ram_gb, cpus = wsl2_ai_tuning.get_host_hardware()

        self.assertEqual(ram_gb, 16)
        self.assertEqual(cpus, wsl2_ai_tuning.os.cpu_count() or 8)


class ApplyTuningTests(unittest.TestCase):
    """Tests for apply_tuning(), with every real filesystem write redirected
    into a temporary directory so no actual system files are ever touched."""

    def test_non_root_execution_skips_all_privileged_writes_without_raising(self):
        with tempfile.TemporaryDirectory() as tmp:
            # Point the unconditional /mnt/c/Users scan at an empty,
            # non-mounted directory so it is a deterministic no-op.
            users_dir = pathlib.Path(tmp) / "mnt_users"
            fake_path = _make_fake_path_class({"/mnt/c/Users": users_dir})
            buf = io.StringIO()
            with mock.patch.object(wsl2_ai_tuning.os, "geteuid", return_value=1000), \
                 mock.patch.object(wsl2_ai_tuning, "Path", fake_path), \
                 redirect_stdout(buf):
                wsl2_ai_tuning.apply_tuning(10, 8, "nat", "ubuntu")

        output = buf.getvalue()
        self.assertIn("Root privileges required to write sysctl files. Run with sudo.", output)

    def test_root_execution_writes_all_expected_files_into_redirected_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            sysctl_file = tmp_path / "99-wsl2-ai-tuning.conf"
            limits_file = tmp_path / "limits.conf"
            wsl_conf = tmp_path / "wsl.conf"
            persist_dir = tmp_path / "dsom-persistence"
            users_dir = tmp_path / "mnt_users"

            # Pre-seed limits.conf without the target line so the
            # "append if missing" branch is exercised.
            limits_file.write_text("# existing limits\n")

            # Seed one real "Windows user" profile plus the excluded
            # shared/system profile names, to verify filtering.
            (users_dir / "Alice").mkdir(parents=True)
            (users_dir / "Public").mkdir(parents=True)
            (users_dir / "Default").mkdir(parents=True)

            mapping = {
                "/etc/sysctl.d/99-wsl2-ai-tuning.conf": sysctl_file,
                "/etc/security/limits.conf": limits_file,
                "/etc/wsl.conf": wsl_conf,
                "/opt/dsom-persistence": persist_dir,
                "/mnt/c/Users": users_dir,
            }
            fake_path = _make_fake_path_class(mapping)

            buf = io.StringIO()
            with mock.patch.object(wsl2_ai_tuning.os, "geteuid", return_value=0), \
                 mock.patch.object(wsl2_ai_tuning.subprocess, "run") as mock_run, \
                 mock.patch.object(wsl2_ai_tuning, "Path", fake_path), \
                 redirect_stdout(buf):
                wsl2_ai_tuning.apply_tuning(48, 20, "mirrored", "almalinux")

            # 1. sysctl file written with the expected kernel parameters.
            self.assertTrue(sysctl_file.exists())
            sysctl_content = sysctl_file.read_text()
            self.assertIn("fs.inotify.max_user_watches=524288", sysctl_content)
            self.assertIn("vm.max_map_count=262144", sysctl_content)
            mock_run.assert_called_once()
            self.assertEqual(mock_run.call_args[0][0][:2], ["sysctl", "-p"])

            # 2. limits.conf appended (not overwritten).
            limits_content = limits_file.read_text()
            self.assertIn("# existing limits", limits_content)
            self.assertIn("*  soft  nofile  65535", limits_content)
            self.assertIn("*  hard  nofile  65535", limits_content)

            # 3. /etc/wsl.conf written with the standard directives.
            self.assertIn("systemd=true", wsl_conf.read_text())

            # 4. Tuned .wslconfig persisted with the given mem/cpu/mode.
            persisted = persist_dir / "wsl2_tuned.wslconfig"
            self.assertTrue(persisted.exists())
            persisted_content = persisted.read_text()
            self.assertIn("memory=48GB", persisted_content)
            self.assertIn("processors=20", persisted_content)
            self.assertIn("networkingMode=mirrored", persisted_content)

            # 5. Only the real (non-excluded) Windows user profile receives
            # a recommended .wslconfig; shared/system profiles do not.
            self.assertTrue((users_dir / "Alice" / ".wslconfig.recommended").exists())
            self.assertFalse((users_dir / "Public" / ".wslconfig.recommended").exists())
            self.assertFalse((users_dir / "Default" / ".wslconfig.recommended").exists())

        output = buf.getvalue()
        self.assertIn("Kernel parameters applied", output)
        self.assertIn("Open file limits (65535) appended", output)
        self.assertIn("/etc/wsl.conf updated", output)
        self.assertIn("Tuned .wslconfig saved", output)
        self.assertIn("Recommended .wslconfig generated", output)

    def test_root_execution_skips_appending_limits_when_already_present(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = pathlib.Path(tmp)
            sysctl_file = tmp_path / "99-wsl2-ai-tuning.conf"
            limits_file = tmp_path / "limits.conf"
            wsl_conf = tmp_path / "wsl.conf"
            persist_dir = tmp_path / "dsom-persistence"
            users_dir = tmp_path / "mnt_users"

            limits_file.write_text("*  soft  nofile  65535\n*  hard  nofile  65535\n")

            mapping = {
                "/etc/sysctl.d/99-wsl2-ai-tuning.conf": sysctl_file,
                "/etc/security/limits.conf": limits_file,
                "/etc/wsl.conf": wsl_conf,
                "/opt/dsom-persistence": persist_dir,
                "/mnt/c/Users": users_dir,
            }
            fake_path = _make_fake_path_class(mapping)

            buf = io.StringIO()
            with mock.patch.object(wsl2_ai_tuning.os, "geteuid", return_value=0), \
                 mock.patch.object(wsl2_ai_tuning.subprocess, "run"), \
                 mock.patch.object(wsl2_ai_tuning, "Path", fake_path), \
                 redirect_stdout(buf):
                wsl2_ai_tuning.apply_tuning(10, 8, "nat", "ubuntu")

        self.assertIn("Open file limits already set", buf.getvalue())


class MainCliTests(unittest.TestCase):
    """CLI-level tests for main(), invoked as a subprocess so argparse's
    SystemExit / usage-error behavior is exercised exactly as end users
    would experience it."""

    def _run(self, *args):
        return subprocess.run(
            [sys.executable, str(SCRIPT_PATH), *args],
            capture_output=True,
            text=True,
        )

    def test_invalid_mode_choice_is_rejected_with_nonzero_exit(self):
        result = self._run("--check", "--mode=invalid")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid choice", result.stderr)

    def test_invalid_distro_choice_is_rejected_with_nonzero_exit(self):
        result = self._run("--check", "--distro=windows")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid choice", result.stderr)

    def test_no_flags_defaults_to_check_mode_only(self):
        result = self._run()
        self.assertEqual(result.returncode, 0)
        self.assertIn("System Audit", result.stdout)
        self.assertNotIn("Applying System Tuning", result.stdout)

    def test_apply_flag_runs_the_tuning_routine(self):
        result = self._run("--apply")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Applying System Tuning", result.stdout)
        self.assertIn("TUNING COMPLETE", result.stdout)
        # Without --check, the audit section should not be printed.
        self.assertNotIn("System Audit", result.stdout)

    def test_check_and_apply_together_run_both_routines(self):
        result = self._run("--check", "--apply")
        self.assertEqual(result.returncode, 0)
        self.assertIn("System Audit", result.stdout)
        self.assertIn("Applying System Tuning", result.stdout)

    def test_help_flag_documents_check_and_apply_options(self):
        result = self._run("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("--check", result.stdout)
        self.assertIn("--apply", result.stdout)
        self.assertIn("--mode", result.stdout)
        self.assertIn("--distro", result.stdout)


if __name__ == "__main__":
    unittest.main()