---
title: "Hardened Wolfi Images & Security Decisions"
description: "High-level review of security mechanisms, image audits, and telemetry boundaries."
nav_order: 41
---

# Hardened Wolfi Images & Security Decisions

This document details the critical security paradigms, base image choices, and operational auditing patterns implemented across the project.

---

## 🛡️ Zero-CVE Hardened Wolfi Images

Standard container deployments often include excess packages, compilation tools, and utilities that expand the service's attack vector.

Our architecture tackles this through **Wolfi-hardened base images**:
- **Minimal Footprint**: Wolfi containers do not contain diagnostic tools, shell environments (unless explicitly required), or unneeded binaries.
- **Dynamic vulnerability audits**: The images are continuously audited with `Snyk` to maintain a zero-CVE state.

---

## 🔑 Automated Secrets and Key Scopes

Hardcoded deployment configurations, default database tokens, and pre-baked SSH keys represent significant risks.

We mitigate these vulnerabilities by:
1. Sourcing high-entropy passwords dynamically using python standard random libs.
2. Isolating active tokens to un-tracked files (`*temp_credentials.txt`, `*gitea_credentials.txt`).
3. Configuring `.gitignore` patterns to prevent checking credentials into open git branches.
