---
okf_version: 0.2
type: documentation
title: "Google Jules Turndown & Historical Archive for Google Antigravity"
timestamp: "2026-10-31T17:15:00Z"
topics: ["dsom", "jules", "antigravity", "changelog", "archive", "brain"]
description: "Historical documentation of Google Jules wind-down, export mechanics, API endpoints, and transition roadmap to Google Antigravity."
resource: "file:///.agents/brain/jules_history.md"
sources:
  - url: "https://jules.google/"
    description: "Google Jules Platform & Changelog"
  - url: "https://linuxmalaysia.github.io/deep-state-of-mind-for-my-ai/START-HERE/"
    description: "Deep State of Mind (DSOM) AI Protocol"
generated: false
verified: true
status: "active"
stale_after: "2027-10-31T17:15:00Z"
---
# Google Jules Turndown & Historical Archive for Google Antigravity

## 1. Executive Summary & Turndown Timeline

On October 29, 2026, Google announced the official wind-down schedule for Google Jules as part of unifying agentic coding efforts into Google's next-generation agent-first platform, **Google Antigravity**:

- **October 29, 2026:** Wind-down announcement and release of export tooling (`@google/jules` CLI tool).
- **November 11, 2026:** Final deadline for interactive session completions. Jules transitions into **read-only** mode until the end of the year.
- **December 31, 2026:** Complete decommission and shutdown of Google Jules.
- **Successor:** All agentic coding learnings, workflows, and spatial memory protocols transition into **Google Antigravity**.

```
[October 29, 2026] ────> [November 11, 2026] ────> [December 31, 2026]
   Turndown Notice           Read-Only Mode             Full Sunset
   Export Tools Live        Session Finishing        Transition to Antigravity
```

---

## 2. Jules Platform Heritage & DSOM Alignment

Google Jules served as an experiment in asynchronous coding agents to help developers tackle backlogs, plan multi-step implementations, and ship code directly into GitHub pull requests.

Under the **Deep State of Mind (DSOM)** sovereign architecture (defined in `.agents/AGENTS.md` Rule 25: *Jules & Antigravity Collaborative Knowledge & Sync Mandate*):
1. **Repository Sovereignty:** All source code, branches, and pull requests reside on GitHub (`linuxmalaysia/podman-elastic-stack-ai`).
2. **Spatial Memory Sovereignty:** Memory files in `.agents/brain/` (`task.md`, `walkthrough.md`, `palace_registry.md`, `active_context_manifest.md`) are git-tracked and agent-agnostic. They are designed to reanimate cleanly across Google Jules, Google Antigravity, Claude Code, and GitHub Copilot.
3. **No External Lock-In:** Core knowledge, Diátaxis documentation, Quadlet manifests, and Ansible playbooks remain self-contained within this repository.

---

## 3. Jules Data Export Specifications & Tooling

### 3.1. Official Tooling
- **Package:** `@google/jules` (installed globally via `npm install -g @google/jules`).
- **Binary:** `jules` (Go-compiled CLI wrapped in Node.js npm package).
- **Authentication:** OAuth2 PKCE browser flow (`jules login`) or headless URL entry (`jules login --no-launch-browser`).
- **Credential Storage:**
  - macOS: Keychain (`service: jules-cli`, `account: default`, encoded as `go-keyring-base64:<base64-json>`).
  - Linux: FreeDesktop Secret Service (`secret-tool lookup service jules-cli username default`).
  - File Fallback: `~/.jules/cache/oauth_creds.json` containing `access_token`, `refresh_token`, and expiry.

### 3.2. Discovered API Endpoints & Status (as of 2026-10-31)

| Subsystem | Endpoint / Method | Protocol | Status / Observation |
|:---|:---|:---|:---|
| **Sessions** | `GET https://aida.googleapis.com/v1/swebot/tasks` | REST | Functional (200 OK, paginated). Returns tasks list with task status, suggestedTitle, and createdAt. |
| **Session Detail** | `GET https://aida.googleapis.com/v1/swebot/tasks/{id}` | REST | Functional (200 OK). Returns full task definition, description/prompt, and outputs. |
| **Activity Log** | `GET https://aida.googleapis.com/v1/swebot/tasks/{id}/activities` | REST | Functional (200 OK). Returns detailed step-by-step actor activity steps and tool executions. |
| **Repositories** | `GET https://aida.googleapis.com/v1/swebot/sources` | REST | Functional (200 OK). Returns all connected GitHub sources, default branches, and lifecycle states. |
| **User Settings** | `POST https://aida.googleapis.com/$rpc/.../GetUserSettings` | RPC | Deprecated / 404 Not Found on `$rpc`. |
| **Env Variables** | `POST https://aida.googleapis.com/$rpc/.../ListEnvironmentVariables` | RPC | Deprecated / 404 Not Found on `$rpc`. |
| **Scheduled Tasks** | `POST https://aida.googleapis.com/$rpc/.../ListScheduledTasks` | RPC | Deprecated / 404 Not Found on `$rpc`. |
| **Memories** | `POST https://aida.googleapis.com/$rpc/.../ListMemories` | RPC | Deprecated / 404 Not Found on `$rpc`. |

---

## 4. Antigravity Handover & Continuity Protocol

For **Google Antigravity** and collaborating AI agents:
1. **Spatial Memory Reanimation:** Antigravity should immediately read `.agents/AGENTS.md` and `.agents/brain/active_context_manifest.md` upon session start.
2. **Task Ledger:** Check `.agents/brain/task.md` for active and completed task states.
3. **Session Walkthroughs:** Review `.agents/brain/walkthrough.md` for historic anchors, design decisions, and previous pull requests.
4. **Palace Registry:** Consult `.agents/brain/palace_registry.md` for structural room mapping across `docs/`, `ansible/`, `test-scripts/`, and Quadlet `.kube` manifests.

---
*Deep State of Mind (DSOM) For My AI Protocol | Harisfazillah Jamel (LinuxMalaysia) | 2026-10-31*
*Standard: UK English | DBP-standard Bahasa Melayu Malaysia (Piawai) | GNU General Public License v3.0*
