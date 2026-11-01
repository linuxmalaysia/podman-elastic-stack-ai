---
okf_version: "0.2"
type: procedural_skill
title: "Universal Multi-Subsystem Unit & Integration Test Generator Skill"
timestamp: "2026-10-31T17:30:00Z"
topics: ["dsom", "skills", "testing", "pytest", "bats", "ansible", "playwright"]
description: "Procedural skill to author automated unit and integration tests across Python pytest, BATS, Ansible Quadlet schemas, and Playwright E2E suites."
resource: "file:///.agents/skills/unit-test-generator/SKILL.md"
sources:
  - id: "pytest-docs"
    title: "pytest: helps you write better programs"
    resource: "https://docs.pytest.org/"
    type: "specification"
  - id: "bats-core"
    title: "Bash Automated Testing System - Core"
    resource: "https://github.com/bats-core/bats-core"
    type: "specification"
generated: false
verified: true
status: "active"
stale_after: "2027-10-31T17:30:00Z"
---
# Unit Test Generator Skill

## When to Use This Skill
Use this skill when introducing or modifying Python scripts, Ansible playbooks, Podman Quadlet configurations, Markdown palaces, or frontend UI workflows.

## Execution Matrix
1. **Python Unit Tests:**
   - Author tests in `tests/test_*.py` using PyTest fixtures, parameterized inputs, and error assertions.
   - Run tests strictly using `uv run --with pyyaml --with pytest pytest tests/`.
2. **Markdown & OKF v0.2 Tests:**
   - Author BATS tests in `test-scripts/*.bats` checking line 1 YAML delimiters (`---`), `okf_version: "0.2"`, trust signals, and footer clauses.
3. **Ansible Playbook & Podman Manifests:**
   - Validate YAML syntax, FQCN compliance, and Quadlet `.kube` / Pod specification boundaries.
4. **Playwright E2E Tests:**
   - Validate browser interactions, role permissions, and session cookie lifecycle states.

---
*Deep State of Mind (DSOM) Protocol | Harisfazillah Jamel (LinuxMalaysia) | 2026-10-31*
