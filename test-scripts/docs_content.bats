#!/usr/bin/env bats
#
# Regression tests for documentation content added in README.md and
# INSTALL.md regarding Ubuntu 24.04 / Podman 5+ support and the
# apt-get/dnf OS-detection behavior of the setup scripts. These guard
# against accidental reverts or drift between the documented behavior
# and the actual install scripts.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
README="${REPO_ROOT}/README.md"
INSTALL_DOC="${REPO_ROOT}/INSTALL.md"

@test "README.md exists and is readable" {
  [ -f "${README}" ]
  [ -r "${README}" ]
}

@test "INSTALL.md exists and is readable" {
  [ -f "${INSTALL_DOC}" ]
  [ -r "${INSTALL_DOC}" ]
}

@test "README.md documents apt-get based install for Debian/Ubuntu" {
  grep -qF 'On Debian and Ubuntu systems (including Ubuntu 26.04), it uses standard `apt-get`' "${README}"
}

@test "README.md documents dnf based install for RPM-based systems" {
  grep -qF 'On RPM-based systems (like Fedora, CentOS, etc.), it installs them using `dnf`.' "${README}"
}

@test "README.md documents the Podman 5+ on Ubuntu 24.04/26.04 caveat" {
  grep -qF '**Note on Podman 5+ on Ubuntu 24.04/26.04:**' "${README}"
}

@test "README.md documents Ubuntu 26.04 and AlmaLinux 10 WSL install" {
  grep -qF 'wsl --install -d Ubuntu-26.04' "${README}"
  grep -qF 'wsl --install -d AlmaLinux-10' "${README}"
}

@test "README.md documents wsl playbook execution commands" {
  grep -qF 'wsl -d Ubuntu-26.04 bash -c "cd /home/jules/podman-elastic-stack && ./run_playbooks.sh"' "${README}"
  grep -qF 'wsl -d AlmaLinux-10 bash -c "cd /home/jules/podman-elastic-stack && ./run_playbooks.sh"' "${README}"
}

@test "INSTALL.md documents Ubuntu and Podman 5+ as fully supported" {
  grep -q 'It fully supports Ubuntu' "${INSTALL_DOC}"
}

@test "INSTALL.md documents apt-get based install for Debian/Ubuntu" {
  grep -q 'the script automatically installs `podman` and `podman-compose` using standard `apt-get`' "${INSTALL_DOC}"
}

@test "INSTALL.md documents the Podman 5+ on Ubuntu caveat" {
  grep -q 'Podman 5+ on Ubuntu' "${INSTALL_DOC}"
}

@test "INSTALL.md and README.md do not claim exclusive dnf-only support anymore" {
  # Regression guard: prior to this PR, both docs stated dnf was used
  # unconditionally. Ensure that outdated, now-inaccurate phrasing is gone.
  run grep -F 'the script attempts to install Podman and Podman Compose using `dnf` (for Fedora, CentOS, etc.) if they are not already installed.' "${INSTALL_DOC}"
  [ "${status}" -ne 0 ]

  run grep -F 'the script attempts to install Podman and Podman Compose using `dnf` (for Fedora, CentOS, etc.).' "${README}"
  [ "${status}" -ne 0 ]
}