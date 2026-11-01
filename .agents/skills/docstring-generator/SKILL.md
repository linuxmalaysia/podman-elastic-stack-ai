---
okf_version: "0.2"
type: procedural_skill
title: "Google-Style PEP-257 Docstring & JSDoc Generator Skill"
timestamp: "2026-10-31T17:30:00Z"
topics: ["dsom", "skills", "docstrings", "pep257", "jsdoc"]
description: "Procedural skill to inspect, generate, and standardize Google-style PEP-257 docstrings and JSDoc annotations across Python and Node.js codebases."
resource: "file:///.agents/skills/docstring-generator/SKILL.md"
sources:
  - id: "pep-257"
    title: "PEP 257 – Docstring Conventions"
    resource: "https://peps.python.org/pep-0257/"
    type: "specification"
  - id: "google-python-style"
    title: "Google Python Style Guide"
    resource: "https://google.github.io/styleguide/pyguide.html"
    type: "specification"
generated: false
verified: true
status: "active"
stale_after: "2027-10-31T17:30:00Z"
---
# Docstring Generator Skill

## When to Use This Skill
Use this skill when auditing or refactoring Python modules, Node.js scripts, and Bash utilities to enforce PEP-257, Google-style docstrings, and comprehensive JSDoc comments.

## Execution Instructions
1. **Python Functions & Modules:**
   - Add a high-level module docstring summarizing package purpose.
   - For every public/internal function, declare Args, Returns, and Raises sections.
2. **Node.js Scripts:**
   - Annotate all functions with `@param`, `@returns`, and `@throws` JSDoc blocks.
3. **Bash Utility Scripts:**
   - Add top-of-file header defining script purpose, prerequisites, usage, and argument specifications.

---
*Deep State of Mind (DSOM) Protocol | Harisfazillah Jamel (LinuxMalaysia) | 2026-10-31*
