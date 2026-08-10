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

# Regression tests for WSL-3NODE-CLUSTER-GUIDE.md
WSL_3NODE_GUIDE="${REPO_ROOT}/WSL-3NODE-CLUSTER-GUIDE.md"

@test "WSL-3NODE-CLUSTER-GUIDE.md exists and is readable" {
  [ -f "${WSL_3NODE_GUIDE}" ]
  [ -r "${WSL_3NODE_GUIDE}" ]
}

@test "WSL-3NODE-CLUSTER-GUIDE.md contains expected OKF metadata" {
  grep -q 'okf_version: 0.1' "${WSL_3NODE_GUIDE}"
  grep -q 'title: "WSL-3NODE-CLUSTER-GUIDE.md"' "${WSL_3NODE_GUIDE}"
  grep -q 'resource: file:///WSL-3NODE-CLUSTER-GUIDE.md' "${WSL_3NODE_GUIDE}"
}

@test "WSL-3NODE-CLUSTER-GUIDE.md documents prerequisites and kernel tuning" {
  grep -q '# 🐧 WSL 3-Node Guide' "${WSL_3NODE_GUIDE}" || grep -q '# 🐧 WSL 3-Node Cluster Guide' "${WSL_3NODE_GUIDE}"
  grep -q 'vm.max_map_count' "${WSL_3NODE_GUIDE}"
}

@test "WSL-3NODE-CLUSTER-GUIDE.md documents deployment and verification" {
  grep -q 'ansible-playbook -i inventory/hosts.wsl.3node.yml site.yml' "${WSL_3NODE_GUIDE}"
  grep -q 'dsom-persistence-es-node-01' "${WSL_3NODE_GUIDE}"
}

@test "README.md documents the WSL 3-Node Cluster Guide link under Option 1" {
  grep -qF -- '- **Detailed Guide:** See [WSL 3-Node Cluster Guide](WSL-3NODE-CLUSTER-GUIDE.md) for a step-by-step walkthrough.' "${README}"
}

@test "README.md references the WSL 3-Node Cluster Guide from the WSL2 deployment steps intro" {
  grep -qF 'Below are the steps to deploy WSL2 and execute the playbooks or shell scripts (representing Option 1). For a dedicated multi-node simulated production architecture on WSL2, refer to the [WSL 3-Node Cluster Guide](WSL-3NODE-CLUSTER-GUIDE.md).' "${README}"
}

@test "WSL-3NODE-CLUSTER-GUIDE.md lists all four expected containers in the verification step" {
  grep -qF 'dsom-persistence-es-node-02' "${WSL_3NODE_GUIDE}"
  grep -qF 'dsom-persistence-es-node-03' "${WSL_3NODE_GUIDE}"
  grep -qF 'dsom-kibana-kibana-local' "${WSL_3NODE_GUIDE}"
}

@test "WSL-3NODE-CLUSTER-GUIDE.md documents teardown removing all four containers" {
  grep -qF 'podman rm -f dsom-persistence-es-node-01 dsom-persistence-es-node-02 dsom-persistence-es-node-03 dsom-kibana-kibana-local' "${WSL_3NODE_GUIDE}"
}