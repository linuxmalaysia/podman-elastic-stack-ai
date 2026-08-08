# Project History - Podman Elastic Stack Deployment

## Early Milestones
- **Initial Setup Scripts (March 2025)**: Conceived and written to simplify setting up isolated Elasticsearch and Kibana instances using Podman with hardened Wolfi-based images. This offered enhanced security boundaries compared to standard base images.
- **Support for Multi-Distribution (April 2025)**: Enhanced scripts to detect RedHat/CentOS/AlmaLinux and Debian/Ubuntu host systems automatically, aligning system dependencies dynamically.

## Transition to Ansible
- **Playbook Implementation (April 2025)**: Migrated shell script configurations into reusable, enterprise-grade Ansible Playbooks (`setup_elasticsearch.yml`, `setup_kibana.yml`, `setup_fleet_server.yml`). This ensured declarative state management, proper credential obfuscation (`no_log`), and idempotent executions.
- **Hardened Secure File Permissions**: Implemented secure modes such as `0600` for generated compose configs to secure embedded service tokens and passwords.

## Local WSL2 & Latest Elastic Stack Focus
- **Elastic Stack 9.4.4+ Integration**: Shifted baseline stack version to 9.4.4+ to leverage the latest security patches, performance improvements, and feature capabilities.
- **Windows 11 WSL2 Support**: Added official documentation and native support for deploying strictly onto localhost WSL2 hosts, supporting both Ubuntu 26.04 and AlmaLinux 10 environments smoothly.
