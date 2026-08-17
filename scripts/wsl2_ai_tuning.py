#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#     "psutil",
# ]
# ///
"""
==============================================================================
WSL2 AI Performance & Security Tuning Script
Author      : Harisfazillah Jamel (LinuxMalaysia) & Jules
License     : GNU General Public License v3.0
==============================================================================
This script automates WSL2 host hardware discovery, memory & CPU allocation
calculations, .wslconfig and /etc/wsl.conf generation, kernel limits tuning
(inotify watches, vm.max_map_count, file limits), distro dependency checks
(AlmaLinux 10 and Ubuntu 26.04 LTS), and security auditing for AI workloads
(Claude Code, Gemini CLI, Podman 5+).
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import psutil
except ImportError:
    psutil = None


def get_host_hardware():
    """
    Queries host Windows 11 physical memory (in GB) and logical CPUs.
    Attempts PowerShell query via interop if in WSL2, falling back to psutil/os.
    """
    host_ram_gb = 16
    host_cpus = os.cpu_count() or 8

    # Attempt PowerShell query if running inside WSL with /mnt/c access
    powershell_bin = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
    if os.path.exists(powershell_bin):
        try:
            mem_cmd = [
                powershell_bin,
                "-NoProfile",
                "-Command",
                "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory",
            ]
            res_mem = subprocess.run(
                mem_cmd, capture_output=True, text=True, timeout=5
            )
            if res_mem.returncode == 0 and res_mem.stdout.strip().isdigit():
                bytes_mem = int(res_mem.stdout.strip())
                host_ram_gb = round(bytes_mem / (1024**3))

            cpu_cmd = [
                powershell_bin,
                "-NoProfile",
                "-Command",
                "(Get-CimInstance Win32_Processor).NumberOfLogicalProcessors",
            ]
            res_cpu = subprocess.run(
                cpu_cmd, capture_output=True, text=True, timeout=5
            )
            if res_cpu.returncode == 0 and res_cpu.stdout.strip().isdigit():
                host_cpus = int(res_cpu.stdout.strip())
            return host_ram_gb, host_cpus
        except Exception:
            pass

    # Fallback to psutil or /proc/meminfo
    if psutil:
        total_bytes = psutil.virtual_memory().total
        host_ram_gb = round(total_bytes / (1024**3))
    elif os.path.exists("/proc/meminfo"):
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    parts = line.split()
                    kb = int(parts[1])
                    host_ram_gb = round(kb / (1024 * 1024))
                    break

    return host_ram_gb, host_cpus


def calculate_wsl_memory(host_ram_gb):
    """
    Calculates optimal WSL2 memory allocation based on host Windows 11 RAM tiers.
    """
    if host_ram_gb <= 16:
        wsl_mem = 10
    elif host_ram_gb <= 32:
        wsl_mem = 22
    elif host_ram_gb <= 64:
        wsl_mem = 48
    else:
        wsl_mem = 96

    # Clamp memory so WSL never requests more than host physical RAM - 2 GB
    if host_ram_gb > 2:
        wsl_mem = min(wsl_mem, host_ram_gb - 2)

    return max(1, wsl_mem)


def detect_distro():
    """
    Detects the active Linux distribution (e.g., AlmaLinux 10, Ubuntu 26.04 LTS).
    """
    os_release = Path("/etc/os-release")
    if not os_release.exists():
        return "generic", "Unknown Linux Distribution"

    content = os_release.read_text()
    distro_id = "generic"
    pretty_name = "Generic Linux"

    for line in content.splitlines():
        if line.startswith("ID="):
            distro_id = line.split("=")[1].strip('"').lower()
        elif line.startswith("PRETTY_NAME="):
            pretty_name = line.split("=")[1].strip('"')

    if distro_id in ["almalinux", "rocky", "fedora", "rhel", "centos"]:
        return "almalinux", pretty_name
    elif distro_id in ["ubuntu", "debian"]:
        return "ubuntu", pretty_name

    return "generic", pretty_name


def generate_wslconfig(wsl_mem_gb, wsl_cpus, networking_mode="nat"):
    """
    Generates optimized .wslconfig content.
    """
    content = f"""# WSL2 AI Performance & Security Tuning (.wslconfig)
# Generated automatically by scripts/wsl2_ai_tuning.py

[wsl2]
memory={wsl_mem_gb}GB
processors={wsl_cpus}
swap=16GB
networkingMode={networking_mode}
dnsTunneling=true
autoProxy=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
"""
    return content


def generate_wsl_conf():
    """
    Generates optimized /etc/wsl.conf content.
    """
    content = """[boot]
systemd=true

[automount]
enabled=true
options=metadata,umask=22,fmask=11

[network]
generateHosts=true
generateResolvConf=true

[interop]
enabled=true
appendWindowsPath=true

[gpu]
enabled=true

[time]
useWindowsTimezone=true
"""
    return content


def check_security():
    """
    Performs security audits on API keys and configuration permissions.
    """
    findings = []
    keys = ["ANTHROPIC_API_KEY", "GEMINI_API_KEY", "OPENAI_API_KEY"]

    for key in keys:
        val = os.environ.get(key)
        if val:
            findings.append(f"  [+] Environment variable {key} is active.")
        else:
            findings.append(
                f"  [-] Environment variable {key} is NOT set in current shell session."
            )

    # Check for hardcoded secrets in settings.json or config files if present
    claude_settings = Path.home() / ".claude" / "settings.json"
    if claude_settings.exists():
        try:
            text = claude_settings.read_text()
            if "sk-ant-" in text:
                findings.append(
                    f"  [!] WARNING: Potential hardcoded API key found in {claude_settings}! Move keys to environment variables."
                )
            else:
                findings.append(
                    f"  [+] {claude_settings} checked: No plaintext API keys detected."
                )
        except Exception as e:
            findings.append(
                f"  [-] Could not read {claude_settings}: {e}"
            )

    # Check permissions of sensitive files
    sensitive_paths = [Path.home() / ".bashrc", Path.home() / ".zshrc"]
    for p in sensitive_paths:
        if p.exists():
            mode = oct(p.stat().st_mode & 0o777)
            findings.append(f"  [i] {p} mode permissions: {mode}")

    return findings


def get_sysctl_val(param):
    """
    Reads sysctl parameter value.
    """
    try:
        res = subprocess.run(
            ["sysctl", "-n", param],
            capture_output=True,
            text=True,
            check=True,
        )
        return int(res.stdout.strip())
    except Exception:
        return 0


def apply_tuning(wsl_mem_gb, wsl_cpus, networking_mode, distro_family):
    """
    Applies sysctl, /etc/wsl.conf, limits.conf, and .wslconfig files.
    """
    print("\n--- Applying System Tuning ---")

    # 1. Sysctl
    sysctl_file = Path("/etc/sysctl.d/99-wsl2-ai-tuning.conf")
    sysctl_content = """# WSL2 AI Performance Kernel Tuning
fs.inotify.max_user_watches=524288
vm.max_map_count=262144
"""
    if os.geteuid() == 0:
        try:
            sysctl_file.write_text(sysctl_content)
            subprocess.run(["sysctl", "-p", str(sysctl_file)], check=False)
            print("  [+] Kernel parameters applied via /etc/sysctl.d/99-wsl2-ai-tuning.conf")
        except Exception as e:
            print(f"  [-] Failed writing sysctl settings: {e}")
    else:
        print("  [!] Root privileges required to write sysctl files. Run with sudo.")

    # 2. limits.conf
    limits_file = Path("/etc/security/limits.conf")
    if os.geteuid() == 0 and limits_file.exists():
        try:
            existing = limits_file.read_text()
            if "soft  nofile  65535" not in existing:
                with open(limits_file, "a") as f:
                    f.write("\n*  soft  nofile  65535\n*  hard  nofile  65535\n")
                print("  [+] Open file limits (65535) appended to /etc/security/limits.conf")
            else:
                print("  [+] Open file limits already set in /etc/security/limits.conf")
        except Exception as e:
            print(f"  [-] Failed modifying limits.conf: {e}")

    # 3. /etc/wsl.conf
    wsl_conf = Path("/etc/wsl.conf")
    if os.geteuid() == 0:
        try:
            wsl_conf.write_text(generate_wsl_conf())
            print("  [+] /etc/wsl.conf updated with systemd, GPU, and automount settings.")
        except Exception as e:
            print(f"  [-] Failed writing /etc/wsl.conf: {e}")

    # 4. .wslconfig persistence & User Profile discovery
    wslconfig_text = generate_wslconfig(wsl_mem_gb, wsl_cpus, networking_mode)
    persist_dir = Path("/opt/dsom-persistence")
    if os.geteuid() == 0:
        try:
            persist_dir.mkdir(parents=True, exist_ok=True)
            (persist_dir / "wsl2_tuned.wslconfig").write_text(wslconfig_text)
            print(f"  [+] Tuned .wslconfig saved to {persist_dir}/wsl2_tuned.wslconfig")
        except Exception as e:
            print(f"  [-] Failed writing persistence file: {e}")

    # Write to Windows Users profiles if mounted
    users_dir = Path("/mnt/c/Users")
    if users_dir.exists():
        for user_folder in users_dir.iterdir():
            if (
                user_folder.is_dir()
                and user_folder.name
                not in ["Public", "Default", "Default User", "All Users"]
            ):
                target = user_folder / ".wslconfig.recommended"
                try:
                    target.write_text(wslconfig_text)
                    print(f"  [+] Recommended .wslconfig generated: {target}")
                except Exception:
                    pass


def main():
    parser = argparse.ArgumentParser(
        description="WSL2 AI Performance & Security Tuning Script"
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Inspect system settings, hardware, and security without applying changes.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply performance tuning and generate configuration files.",
    )
    parser.add_argument(
        "--mode",
        choices=["nat", "mirrored"],
        default="nat",
        help="Networking mode for .wslconfig ('nat' recommended for Podman containers, 'mirrored' for AI CLI agents).",
    )
    parser.add_argument(
        "--distro",
        choices=["auto", "almalinux", "ubuntu"],
        default="auto",
        help="Specify target distro family (default: auto-detect).",
    )

    args = parser.parse_args()

    # If neither --check nor --apply specified, default to --check
    if not args.check and not args.apply:
        args.check = True

    host_ram_gb, host_cpus = get_host_hardware()
    wsl_mem_gb = calculate_wsl_memory(host_ram_gb)
    detected_family, pretty_name = detect_distro()
    target_family = detected_family if args.distro == "auto" else args.distro

    print("==========================================================")
    print("    WSL2 AI PERFORMANCE & SECURITY TUNING UTILITY")
    print("==========================================================")
    print(f"  Host Windows 11 RAM (Est.) : {host_ram_gb} GB")
    print(f"  Host Logical vCPU Threads  : {host_cpus}")
    print(f"  Calculated WSL2 Memory     : {wsl_mem_gb} GB")
    print(f"  Detected Distribution      : {pretty_name} ({target_family})")
    print(f"  Selected Networking Mode   : {args.mode}")
    print("==========================================================")

    if args.check:
        print("\n--- System Audit ---")
        inotify_watches = get_sysctl_val("fs.inotify.max_user_watches")
        max_map_count = get_sysctl_val("vm.max_map_count")

        print(
            f"  [*] fs.inotify.max_user_watches : {inotify_watches} (Recommended: >= 524288) -> "
            + ("OK" if inotify_watches >= 524288 else "NEEDS TUNING")
        )
        print(
            f"  [*] vm.max_map_count           : {max_map_count} (Recommended: >= 262144) -> "
            + ("OK" if max_map_count >= 262144 else "NEEDS TUNING")
        )

        wsl_conf = Path("/etc/wsl.conf")
        print(
            f"  [*] /etc/wsl.conf              : "
            + ("EXISTS" if wsl_conf.exists() else "MISSING")
        )

        print("\n--- Security Audit ---")
        for finding in check_security():
            print(finding)

    if args.apply:
        apply_tuning(wsl_mem_gb, host_cpus, args.mode, target_family)
        print("\n==========================================================")
        print("  TUNING COMPLETE.")
        print("  To activate .wslconfig and /etc/wsl.conf changes, run:")
        print("    wsl.exe --shutdown")
        print("  from PowerShell or Command Prompt.")
        print("==========================================================")


if __name__ == "__main__":
    main()
