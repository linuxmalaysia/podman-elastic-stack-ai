---
okf_version: 0.1
type: documentation
title: "SOP_KNOWLEDGE_FIRST_DISCOVERY.md"
description: "Local Knowledge-First Discovery and Context Preservation Protocol Guide."
topics: [sop, discovery, protocol, metadata, guidelines]
resource: file:///docs/SOP_KNOWLEDGE_FIRST_DISCOVERY.md
timestamp: 2026-07-12T10:00:00Z
---
{% raw %}
# 🔍 Local Knowledge-First Discovery & Context Preservation Protocol

This document establishes the official Local Knowledge-First SOP for agentic development sessions, aimed at preventing unnecessary filesystem searches, token window exhaustion, and context loss.

---

## 1. Executive Intent

To streamline operations and guarantee maximum execution reliability, AI agents must adhere strictly to the **Local Knowledge-First Protocol**. All project facts, architecture models, inventory maps, and execution guidelines are permanently indexed via **OKF v0.1 YAML Frontmatter** blocks located inside our `.md` documents under `docs/`.

---

## 2. The 5-Step Discovery Flow

AI agents are expected to navigate the following discovery sequence before executing commands or modifying code:

```
+-------------------------------------------------------------+
|             Step 1: Local Frontmatter & Metadata Search      |
| Query `topics:` and `description:` in local YAML blocks.    |
+-------------------------------------------------------------+
                              │
                              ▼
+-------------------------------------------------------------+
|             Step 2: Targeted File Viewing                   |
| Read specific file segments instead of dumping full files.   |
+-------------------------------------------------------------+
                              │
                              ▼
+-------------------------------------------------------------+
|             Step 3: Temporal Verification Gate              |
| Verify OKF frontmatter timestamp to prevent outdated action.|
+-------------------------------------------------------------+
                              │
                              ▼
+-------------------------------------------------------------+
|             Step 4: Human-in-the-Loop Validation            |
| Confirm update strategy with operator and update frontmatter.|
+-------------------------------------------------------------+
                              │
                              ▼
+-------------------------------------------------------------+
|             Step 5: Terminal Execution Gate                 |
| Execute updating commands or target playbook runs safely.   |
+-------------------------------------------------------------+
```

---

## 3. Mandatory OKF Frontmatter Rules

To ensure universal compatibility with metadata search tools, all documentation files (`.md` extension) situated inside the project must adhere to the following metadata rules:

1. **Rule 6 (YAML Frontmatter Placement)**: Every `.md` file must open exactly on line 1 with a YAML frontmatter block starting with `---` and closing with `---` before any Markdown header.
2. **Rule 12 (Metadata-First Search)**: Always search or check the `topics:` and `description:` attributes of local YAML headers before retrieving the rest of the text.
3. **Rule 29 (Local Knowledge Mandate)**: Consult existing guidelines in `docs/` or `.agents/brain/` locally before invoking system queries or running terminal probing scripts.
4. **Rule 30 (Temporal Validation)**: Check file `timestamp` fields (formatted as ISO-8601 UTC) and prompt the user if local configurations appear contextually outdated compared to the system state.

---
*DSOM Engineering | Local Knowledge-First Protocol v1.0*
{% endraw %}
