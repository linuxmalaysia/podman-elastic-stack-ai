#!/usr/bin/env bats
#
# Regression tests for documentation content added in README.md and
# INSTALL.md regarding Ubuntu 24.04 / Podman 5+ support and the
# apt-get/dnf OS-detection behavior of the setup scripts. These guard
# against accidental reverts or drift between the documented behavior
# and the actual install scripts.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
README="${REPO_ROOT}/README.md"
INSTALL_DOC="${REPO_ROOT}/docs/INSTALL.md"

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
WSL_3NODE_GUIDE="${REPO_ROOT}/docs/WSL-3NODE-CLUSTER-GUIDE.md"

@test "WSL-3NODE-CLUSTER-GUIDE.md exists and is readable" {
  [ -f "${WSL_3NODE_GUIDE}" ]
  [ -r "${WSL_3NODE_GUIDE}" ]
}

@test "WSL-3NODE-CLUSTER-GUIDE.md contains expected OKF metadata" {
  grep -q 'okf_version: 0.1' "${WSL_3NODE_GUIDE}"
  grep -q 'title: "WSL-3NODE-CLUSTER-GUIDE.md"' "${WSL_3NODE_GUIDE}"
  grep -q 'resource: file:///docs/WSL-3NODE-CLUSTER-GUIDE.md' "${WSL_3NODE_GUIDE}"
}

@test "WSL-3NODE-CLUSTER-GUIDE.md documents prerequisites and kernel tuning" {
  grep -q '# 🐧 WSL 3-Node Guide' "${WSL_3NODE_GUIDE}" || grep -q '# 🐧 WSL 3-Node Cluster Guide' "${WSL_3NODE_GUIDE}"
  grep -q 'vm.max_map_count' "${WSL_3NODE_GUIDE}"
  grep -q 'Podman' "${WSL_3NODE_GUIDE}"
  grep -q 'Ansible' "${WSL_3NODE_GUIDE}"
  grep -q 'Python3' "${WSL_3NODE_GUIDE}"
  grep -q 'apt-get install' "${WSL_3NODE_GUIDE}"
  grep -q 'dnf install' "${WSL_3NODE_GUIDE}"
  grep -q 'podman-compose' "${WSL_3NODE_GUIDE}"
}

@test "WSL-3NODE-CLUSTER-GUIDE.md documents deployment and verification" {
  grep -q 'ansible-playbook -i inventory/hosts.wsl.3node.yml site.yml' "${WSL_3NODE_GUIDE}"
  grep -q 'dsom-persistence-es-node-01' "${WSL_3NODE_GUIDE}"
  grep -q 'elk-wolfi/certs/http_ca.crt' "${WSL_3NODE_GUIDE}"
}

@test "README.md documents the new docs/ directory Documentation section" {
  grep -qF '## 📖 Documentation' "${README}"
  grep -qF '[Installation Guide](docs/INSTALL.md)' "${README}"
  grep -qF '[Playbook Structure & Telemetry](docs/PLAYBOOKS.md)' "${README}"
  grep -qF '[Local Development & Feedback Guide](docs/LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md)' "${README}"
  grep -qF '[Sovereign Gitea Deployment & Security Operations Guide](docs/GITEA_GUIDE.md)' "${README}"
  grep -qF '[WSL 3-Node Cluster Guide](docs/WSL-3NODE-CLUSTER-GUIDE.md)' "${README}"
  grep -qF '[Developer Matrix Telemetry](docs/DOCS_MATRIX_TELEMETRY.md)' "${README}"
  grep -qF '[Project History](HISTORY.md)' "${README}"
  grep -qF '[Changelog](CHANGELOG.md)' "${README}"
}

@test "README.md references the WSL 3-Node Cluster Guide under docs/ in both the option summary and the WSL2 walkthrough section" {
  local count
  count="$(grep -cF 'docs/WSL-3NODE-CLUSTER-GUIDE.md' "${README}")"
  [ "${count}" -ge 2 ]
}

@test "README.md no longer links to guide docs at the repository root (post-relocation regression guard)" {
  # Regression guard: prior to this PR, README linked to
  # "WSL-3NODE-CLUSTER-GUIDE.md" without the docs/ prefix. Ensure the
  # outdated root-relative link form is gone.
  run grep -F '(WSL-3NODE-CLUSTER-GUIDE.md)' "${README}"
  [ "${status}" -ne 0 ]
}

@test "relocated guide documentation files exist under docs/ and no longer at the repository root" {
  for doc in INSTALL.md PLAYBOOKS.md LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md GITEA_GUIDE.md WSL-3NODE-CLUSTER-GUIDE.md DOCS_MATRIX_TELEMETRY.md; do
    [ -f "${REPO_ROOT}/docs/${doc}" ]
    [ ! -f "${REPO_ROOT}/${doc}" ]
  done
}

@test "README.md, HISTORY.md, and CHANGELOG.md remain at the repository root after the docs/ reorganization" {
  [ -f "${REPO_ROOT}/README.md" ]
  [ -f "${REPO_ROOT}/HISTORY.md" ]
  [ -f "${REPO_ROOT}/CHANGELOG.md" ]
}

# Regression tests for the Jekyll {% raw %}/{% endraw %} wrapping applied
# to GITEA_GUIDE.md, and LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md, guarding
# against the GitHub Pages Jekyll build failing on embedded Ansible/Jinja2
# Liquid-like syntax.
GITEA_DOC="${REPO_ROOT}/docs/GITEA_GUIDE.md"
FEEDBACK_DOC="${REPO_ROOT}/docs/LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md"
MATRIX_TELEMETRY_DOC="${REPO_ROOT}/docs/DOCS_MATRIX_TELEMETRY.md"

@test "both raw/endraw-wrapped docs still contain their Ansible Liquid-like double-curly-brace syntax inside the raw block" {
  for doc in "${GITEA_DOC}" "${FEEDBACK_DOC}"; do
    raw_line="$(grep -nF -- '{% raw %}' "${doc}" | head -1 | cut -d: -f1)"
    endraw_line="$(grep -nF -- '{% endraw %}' "${doc}" | head -1 | cut -d: -f1)"
    liquid_line="$(grep -nF -- '{{' "${doc}" | head -1 | cut -d: -f1)"
    [ -n "${liquid_line}" ]
    [ "${liquid_line}" -gt "${raw_line}" ]
    [ "${liquid_line}" -lt "${endraw_line}" ]
  done
}

# Regression tests for the markdownlint directive in DOCS_MATRIX_TELEMETRY.md
# being moved onto its own line (as `markdownlint-disable-file MD041`)
# instead of being fused onto the same physical line as the opening
# `{% raw %}` Jekyll tag (which previously read
# `<!-- markdownlint-disable MD041 -->{% raw %}` on line 1).

@test "DOCS_MATRIX_TELEMETRY.md no longer fuses the markdownlint directive onto the opening {% raw %} line" {
  run grep -F '<!-- markdownlint-disable MD041 -->{% raw %}' "${MATRIX_TELEMETRY_DOC}"
  [ "${status}" -ne 0 ]
}

@test "DOCS_MATRIX_TELEMETRY.md declares markdownlint-disable-file MD041 on its own line after the title" {
  grep -qF -- '<!-- markdownlint-disable-file MD041 -->' "${MATRIX_TELEMETRY_DOC}"

  local directive_line title_line author_line
  title_line="$(grep -n -F '# SYSTEM ARCHITECTURE & BLUEPRINT DIRECTIVE: MATRIX TELEMETRY & FEEDBACK PIPELINE' "${MATRIX_TELEMETRY_DOC}" | head -1 | cut -d: -f1)"
  directive_line="$(grep -n -F -- '<!-- markdownlint-disable-file MD041 -->' "${MATRIX_TELEMETRY_DOC}" | head -1 | cut -d: -f1)"
  author_line="$(grep -n -F '**Author:** Senior Principal Systems & Automation Architect' "${MATRIX_TELEMETRY_DOC}" | head -1 | cut -d: -f1)"

  [ -n "${title_line}" ]
  [ -n "${directive_line}" ]
  [ -n "${author_line}" ]
  [ "${title_line}" -lt "${directive_line}" ]
  [ "${directive_line}" -lt "${author_line}" ]
}

@test "DOCS_MATRIX_TELEMETRY.md's opening {% raw %} tag is still the very first line (bare, unfused)" {
  first_line="$(head -n 1 "${MATRIX_TELEMETRY_DOC}")"
  [ "${first_line}" = '{% raw %}' ]
}

# Regression tests for the new docs/DOCS_MATRIX_TELEMETRY.md Jekyll
# {% raw %}/{% endraw %} wrapping. The document contains embedded Ansible
# Jinja2 double-curly-brace syntax (e.g. `{{ ansible_failed_result.msg }}`)
# which would otherwise break GitHub Pages' Jekyll Liquid engine, so the
# entire document body is wrapped in raw/endraw tags, mirroring the
# wrapping already applied to GITEA_GUIDE.md and
# LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md.

@test "DOCS_MATRIX_TELEMETRY.md is wrapped in Jekyll {% raw %}/{% endraw %} tags, with {% endraw %} as the last line" {
  first_line="$(head -n 1 "${MATRIX_TELEMETRY_DOC}")"
  last_line="$(tail -n 1 "${MATRIX_TELEMETRY_DOC}")"
  [ "${first_line}" = '{% raw %}' ]
  [ "${last_line}" = '{% endraw %}' ]
}

@test "DOCS_MATRIX_TELEMETRY.md has exactly one raw/endraw tag pair (no duplicates or stray tags)" {
  raw_count="$(grep -cF -- '{% raw %}' "${MATRIX_TELEMETRY_DOC}")"
  endraw_count="$(grep -cF -- '{% endraw %}' "${MATRIX_TELEMETRY_DOC}")"
  [ "${raw_count}" -eq 1 ]
  [ "${endraw_count}" -eq 1 ]
}

@test "DOCS_MATRIX_TELEMETRY.md's Ansible Jinja2 double-curly-brace syntax is enclosed within the raw block" {
  raw_line="$(grep -nF -- '{% raw %}' "${MATRIX_TELEMETRY_DOC}" | head -1 | cut -d: -f1)"
  endraw_line="$(grep -nF -- '{% endraw %}' "${MATRIX_TELEMETRY_DOC}" | head -1 | cut -d: -f1)"
  liquid_line="$(grep -nF -- '{{ ansible_failed_result.msg' "${MATRIX_TELEMETRY_DOC}" | head -1 | cut -d: -f1)"
  [ -n "${liquid_line}" ]
  [ "${liquid_line}" -gt "${raw_line}" ]
  [ "${liquid_line}" -lt "${endraw_line}" ]
}

@test "DOCS_MATRIX_TELEMETRY.md's closing footer line appears immediately before the closing {% endraw %} tag" {
  # Regression guard: ensures {% endraw %} was appended after the existing
  # final content rather than replacing or truncating it.
  mapfile -t last_lines < <(tail -n 2 "${MATRIX_TELEMETRY_DOC}")
  [ "${last_lines[0]}" = '*This document serves as the master architectural specification for local multi-OS telemetry extraction and bidirectional agent-human orchestration loops.*' ]
  [ "${last_lines[1]}" = '{% endraw %}' ]
}

# Regression tests for the new docs/legal-notice.md document, which
# provides the Legal Notice, Privacy Policy, Critical Assumptions, and
# Assumption of Risk / Liability Disclaimer referenced from the mkdocs.yml
# footer copyright and linked from llms.txt and the sitemaps.
LEGAL_NOTICE_DOC="${REPO_ROOT}/docs/legal-notice.md"

@test "legal-notice.md exists and is readable" {
  [ -f "${LEGAL_NOTICE_DOC}" ]
  [ -r "${LEGAL_NOTICE_DOC}" ]
}

@test "legal-notice.md declares the expected OKF front-matter metadata" {
  grep -qF 'okf_version: 0.1' "${LEGAL_NOTICE_DOC}"
  grep -qF 'type: documentation' "${LEGAL_NOTICE_DOC}"
  grep -qF 'title: "legal-notice.md"' "${LEGAL_NOTICE_DOC}"
  grep -qF 'resource: file:///docs/legal-notice.md' "${LEGAL_NOTICE_DOC}"
}

@test "legal-notice.md's front matter is delimited by --- markers, closed before the title heading" {
  local first_line closing_line title_line
  first_line="$(sed -n '1p' "${LEGAL_NOTICE_DOC}")"
  [ "${first_line}" = '---' ]
  closing_line="$(grep -n -F -- '---' "${LEGAL_NOTICE_DOC}" | sed -n '2p' | cut -d: -f1)"
  title_line="$(grep -n -F -- '# ⚖️ Legal Notice & Disclaimer' "${LEGAL_NOTICE_DOC}" | head -1 | cut -d: -f1)"
  [ -n "${closing_line}" ]
  [ -n "${title_line}" ]
  [ "${closing_line}" -lt "${title_line}" ]
}

@test "legal-notice.md has the expected title heading" {
  grep -qF -- '# ⚖️ Legal Notice & Disclaimer' "${LEGAL_NOTICE_DOC}"
}

@test "legal-notice.md documents all four numbered sections in order" {
  headers=(
    '## 1. Educational and Training Purpose'
    '## 2. Reliance on Critical Assumptions'
    '## 3. Privacy Statement & Data Protection'
    '## 4. Assumption of Risk & Liability Disclaimer'
  )
  local prev_line=0
  for header in "${headers[@]}"; do
    line="$(grep -n -F -- "${header}" "${LEGAL_NOTICE_DOC}" | head -1 | cut -d: -f1)"
    [ -n "${line}" ]
    [ "${line}" -gt "${prev_line}" ]
    prev_line="${line}"
  done
}

@test "legal-notice.md's educational/training purpose section covers Ansible playbooks and Wolfi images" {
  grep -qF -- 'training, educational, and planning proposal purposes only' "${LEGAL_NOTICE_DOC}"
  grep -qF -- 'Podman and hardened Wolfi images' "${LEGAL_NOTICE_DOC}"
}

@test "legal-notice.md's critical assumptions section documents infrastructure, cost, and capacity caveats" {
  grep -qF -- '**Infrastructure Design:**' "${LEGAL_NOTICE_DOC}"
  grep -qF -- '**Cost Estimations:**' "${LEGAL_NOTICE_DOC}"
  grep -qF -- '**System Capacity & Units:**' "${LEGAL_NOTICE_DOC}"
}

@test "legal-notice.md's privacy section documents anonymised metadata and zero real-world PII storage" {
  grep -qF -- '**Anonymised Metadata:**' "${LEGAL_NOTICE_DOC}"
  grep -qF -- '**Zero Real-World Storage:**' "${LEGAL_NOTICE_DOC}"
  grep -qF -- 'personal identifying information (PII)' "${LEGAL_NOTICE_DOC}"
}

@test "legal-notice.md's disclaimer section documents as-is basis, liability disclaimer, and user responsibility" {
  grep -qF -- '**As-Is Basis:**' "${LEGAL_NOTICE_DOC}"
  grep -qF -- '**Disclaimer:**' "${LEGAL_NOTICE_DOC}"
  grep -qF -- '**User Responsibility:**' "${LEGAL_NOTICE_DOC}"
}

@test "legal-notice.md ends with the REGULATION/PURPOSE/RISK footer banner" {
  last_line="$(tail -n 1 "${LEGAL_NOTICE_DOC}")"
  [ "${last_line}" = '[ REGULATION: DISCLAIMER ] | [ PURPOSE: TRAINING ] | [ RISK: ASSUMED ]' ]
}

@test "legal-notice.md's front-matter timestamp uses ISO-8601 UTC format" {
  grep -qE -- 'timestamp: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' "${LEGAL_NOTICE_DOC}"
}

@test "legal-notice.md is not wrapped in Jekyll {% raw %}/{% endraw %} tags (no Liquid-conflicting syntax present)" {
  # Unlike GITEA_GUIDE.md, LOCAL_DEVELOPMENT_FEEDBACK_GUIDE.md, and
  # DOCS_MATRIX_TELEMETRY.md, legal-notice.md contains no Ansible/Jinja2
  # double-curly-brace syntax, so it should not need raw/endraw wrapping.
  run grep -qF -- '{{' "${LEGAL_NOTICE_DOC}"
  [ "${status}" -ne 0 ]
  run grep -qF -- '{% raw %}' "${LEGAL_NOTICE_DOC}"
  [ "${status}" -ne 0 ]
}

# Regression tests for the new docs/REFERENCE_TUNING.md reference document,
# which compiles the tuning-guide URLs and the specific kernel/OS-level and
# .wslconfig values integrated by ansible/tasks/wsl_tuning.yml.
REFERENCE_TUNING_DOC="${REPO_ROOT}/docs/REFERENCE_TUNING.md"
WSL_TUNING_TASK_FILE="${REPO_ROOT}/ansible/tasks/wsl_tuning.yml"

@test "REFERENCE_TUNING.md exists and is readable" {
  [ -f "${REFERENCE_TUNING_DOC}" ]
  [ -r "${REFERENCE_TUNING_DOC}" ]
}

@test "REFERENCE_TUNING.md contains expected OKF front-matter metadata" {
  grep -q 'okf_version: 0.1' "${REFERENCE_TUNING_DOC}"
  grep -q 'type: documentation' "${REFERENCE_TUNING_DOC}"
  grep -q 'title: "REFERENCE_TUNING.md"' "${REFERENCE_TUNING_DOC}"
  grep -q 'resource: file:///docs/REFERENCE_TUNING.md' "${REFERENCE_TUNING_DOC}"
}

@test "REFERENCE_TUNING.md links to both primary tuning-guide resources" {
  grep -qF 'https://linuxmalaysia.github.io/podman-elastic-stack-ai/WSL-3NODE-CLUSTER-GUIDE/' "${REFERENCE_TUNING_DOC}"
  grep -qF 'https://www.thetributary.ai/blog/optimizing-wsl2-claude-code-performance-guide/' "${REFERENCE_TUNING_DOC}"
}

@test "REFERENCE_TUNING.md documents the exact kernel/OS-level tuning values applied by the playbook" {
  grep -qF '`vm.max_map_count`' "${REFERENCE_TUNING_DOC}"
  grep -qF '262144' "${REFERENCE_TUNING_DOC}"
  grep -qF '`fs.inotify.max_user_watches`' "${REFERENCE_TUNING_DOC}"
  grep -qF '524288' "${REFERENCE_TUNING_DOC}"
  grep -qF '65535' "${REFERENCE_TUNING_DOC}"
}

@test "REFERENCE_TUNING.md documents the /etc/wsl.conf and .wslconfig settings applied by the playbook" {
  grep -qF 'systemd=true' "${REFERENCE_TUNING_DOC}"
  grep -qF 'metadata,umask=22,fmask=11' "${REFERENCE_TUNING_DOC}"
  grep -qF 'generateHosts=true' "${REFERENCE_TUNING_DOC}"
  grep -qF 'generateResolvConf=true' "${REFERENCE_TUNING_DOC}"
  grep -qF 'autoMemoryReclaim=gradual' "${REFERENCE_TUNING_DOC}"
  grep -qF 'sparseVhd=true' "${REFERENCE_TUNING_DOC}"
  grep -qF 'networkingMode=mirrored' "${REFERENCE_TUNING_DOC}"
  grep -qF 'dnsTunneling=true' "${REFERENCE_TUNING_DOC}"
}

@test "REFERENCE_TUNING.md's documented memory-tier scaling matches the wsl_tuning.yml implementation" {
  grep -qF '10GB for <=16GB systems' "${REFERENCE_TUNING_DOC}"
  grep -qF '22GB for 32GB' "${REFERENCE_TUNING_DOC}"
  grep -qF '48GB for 64GB' "${REFERENCE_TUNING_DOC}"
  grep -qF '96GB for 128GB' "${REFERENCE_TUNING_DOC}"
}

@test "REFERENCE_TUNING.md's documented tuning values are not just aspirational but genuinely present in wsl_tuning.yml" {
  # Cross-file regression guard: ensures the documentation doesn't silently
  # drift from the actual Ansible implementation it describes.
  [ -f "${WSL_TUNING_TASK_FILE}" ]
  grep -qF 'value: "262144"' "${WSL_TUNING_TASK_FILE}"
  grep -qF 'value: "524288"' "${WSL_TUNING_TASK_FILE}"
  grep -qF 'nofile  65535' "${WSL_TUNING_TASK_FILE}"
}

@test "WSL-3NODE deployment contract validation" {
  # Inspect inventory/hosts.wsl.3node.yml
  [ -f "${REPO_ROOT}/inventory/hosts.wsl.3node.yml" ]
  grep -q 'es-node-01' "${REPO_ROOT}/inventory/hosts.wsl.3node.yml"
  grep -q 'es-node-02' "${REPO_ROOT}/inventory/hosts.wsl.3node.yml"
  grep -q 'es-node-03' "${REPO_ROOT}/inventory/hosts.wsl.3node.yml"
  grep -q '9200' "${REPO_ROOT}/inventory/hosts.wsl.3node.yml"
  grep -q '9201' "${REPO_ROOT}/inventory/hosts.wsl.3node.yml"
  grep -q '9202' "${REPO_ROOT}/inventory/hosts.wsl.3node.yml"
  grep -q '9300' "${REPO_ROOT}/inventory/hosts.wsl.3node.yml"
  grep -q '9301' "${REPO_ROOT}/inventory/hosts.wsl.3node.yml"
  grep -q '9302' "${REPO_ROOT}/inventory/hosts.wsl.3node.yml"
  grep -q '5601' "${REPO_ROOT}/inventory/hosts.wsl.3node.yml"

  # Inspect site.yml
  [ -f "${REPO_ROOT}/site.yml" ]
  grep -q 'setup_elasticsearch.yml' "${REPO_ROOT}/site.yml"
  grep -q 'setup_kibana.yml' "${REPO_ROOT}/site.yml"
  # Confirm site.yml does NOT import setup_fleet_server.yml to match the guide's component set
  ! grep -q 'setup_fleet_server.yml' "${REPO_ROOT}/site.yml"
}