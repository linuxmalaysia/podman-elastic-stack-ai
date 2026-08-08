# Changelog - Podman Elastic Stack

All notable changes to this project will be documented in this file.

## [Unreleased] - 2025-04-10

### Added
- Comprehensive Windows 11 WSL2 deployment guide for Ubuntu 26.04 and AlmaLinux 10.
- Executing Ansible playbooks directly from Windows PowerShell using the native `wsl` command structure.
- Dedicated `HISTORY.md` detailing project milestones and the transition from bash to Ansible.
- Dedicated `CHANGELOG.md` file.

### Changed
- Default Elastic Stack version upgraded from `8.17.4` to `9.4.4` across all shell scripts, playbooks, and variable files.
- Refactored `Install EPEL release via dnf` task in `ansible/setup_elasticsearch.yml` with `ignore_errors: true` to prevent playbook failures on modern RPM distributions (such as AlmaLinux 10) where the EPEL repository structure may vary.
- Updated documentation in `README.md` and `INSTALL.md` to reference version 9.4.4 and the new Windows 11 WSL2 command workflow.
