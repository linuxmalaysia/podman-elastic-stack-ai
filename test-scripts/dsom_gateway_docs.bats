#!/usr/bin/env bats
#
# Regression tests for the Deep State of Mind (DSOM) governance and gateway
# documentation adopted in this PR:
#   - .agents/AGENTS.md               (Sovereign AI Constitution, 29 rules)
#   - AGENTS.md                       (root Agent Registry & DSOM Gateway)
#   - .agents/brain/*.md              (spatial memory: task, walkthrough,
#                                       palace_registry, active_context_manifest)
#   - .cursorrules, CLAUDE.md,
#     .github/copilot-instructions.md (Universal Gateway Matrix quick-refs)
#
# These tests verify OKF frontmatter structure/metadata for the fully
# OKF-compliant documents, and the expected content/cross-references for
# every file introduced by this PR.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

AGENTS_CONSTITUTION="${REPO_ROOT}/.agents/AGENTS.md"
AGENTS_GATEWAY="${REPO_ROOT}/AGENTS.md"
BRAIN_ACTIVE_CONTEXT="${REPO_ROOT}/.agents/brain/active_context_manifest.md"
BRAIN_PALACE_REGISTRY="${REPO_ROOT}/.agents/brain/palace_registry.md"
BRAIN_TASK="${REPO_ROOT}/.agents/brain/task.md"
BRAIN_WALKTHROUGH="${REPO_ROOT}/.agents/brain/walkthrough.md"
CURSORRULES="${REPO_ROOT}/.cursorrules"
COPILOT_INSTRUCTIONS="${REPO_ROOT}/.github/copilot-instructions.md"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"

# The six documents that carry full OKF YAML frontmatter.
OKF_DOCS=(
  ".agents/AGENTS.md"
  "AGENTS.md"
  ".agents/brain/active_context_manifest.md"
  ".agents/brain/palace_registry.md"
  ".agents/brain/task.md"
  ".agents/brain/walkthrough.md"
)

# All nine files introduced by this PR.
ALL_DSOM_FILES=(
  ".agents/AGENTS.md"
  "AGENTS.md"
  ".agents/brain/active_context_manifest.md"
  ".agents/brain/palace_registry.md"
  ".agents/brain/task.md"
  ".agents/brain/walkthrough.md"
  ".cursorrules"
  ".github/copilot-instructions.md"
  "CLAUDE.md"
)

extract_frontmatter() {
  awk 'BEGIN {show=0; count=0} /^---$/ {count++; if(count==1) {show=1; next} if(count==2) {show=0; exit}} show {print}' "$1"
}

# ---------------------------------------------------------------------------
# Existence / readability
# ---------------------------------------------------------------------------

@test "all DSOM governance and gateway documentation files exist and are readable" {
  for doc in "${ALL_DSOM_FILES[@]}"; do
    [ -f "${REPO_ROOT}/${doc}" ]
    [ -r "${REPO_ROOT}/${doc}" ]
  done
}

# ---------------------------------------------------------------------------
# Shared OKF frontmatter structural checks (the six OKF-compliant documents)
# ---------------------------------------------------------------------------

@test "all OKF-compliant DSOM documents open on line 1 with a YAML frontmatter marker" {
  for doc in "${OKF_DOCS[@]}"; do
    first_line="$(head -n 1 "${REPO_ROOT}/${doc}")"
    [ "${first_line}" = "---" ]
  done
}

@test "all OKF-compliant DSOM documents declare okf_version 0.1 and a matching quoted resource path" {
  for doc in "${OKF_DOCS[@]}"; do
    frontmatter="$(extract_frontmatter "${REPO_ROOT}/${doc}")"
    echo "${frontmatter}" | grep -Fxq 'okf_version: 0.1'
    echo "${frontmatter}" | grep -Fxq "resource: \"file:///${doc}\""
  done
}

@test "all OKF-compliant DSOM documents declare a valid quoted ISO-8601 UTC timestamp" {
  for doc in "${OKF_DOCS[@]}"; do
    frontmatter="$(extract_frontmatter "${REPO_ROOT}/${doc}")"
    echo "${frontmatter}" | grep -qE '^timestamp: "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"$'
  done
}

@test "all OKF-compliant DSOM documents declare a non-empty quoted title, description, and topics list" {
  for doc in "${OKF_DOCS[@]}"; do
    frontmatter="$(extract_frontmatter "${REPO_ROOT}/${doc}")"
    echo "${frontmatter}" | grep -qE '^title: ".+"$'
    echo "${frontmatter}" | grep -qE '^description: ".+"$'
    echo "${frontmatter}" | grep -qE '^topics: \[.+\]$'
  done
}

@test "the frontmatter closing marker is immediately followed by a level-1 Markdown heading for every OKF-compliant DSOM document" {
  for doc in "${OKF_DOCS[@]}"; do
    marker2_line="$(grep -n '^---$' "${REPO_ROOT}/${doc}" | sed -n '2p' | cut -d: -f1)"
    [ -n "${marker2_line}" ]
    next_line_num=$((marker2_line + 1))
    next_line="$(sed -n "${next_line_num}p" "${REPO_ROOT}/${doc}")"
    [[ "${next_line}" == "# "* ]]
  done
}

# ---------------------------------------------------------------------------
# Per-document OKF "type" and "title" checks
# ---------------------------------------------------------------------------

@test ".agents/AGENTS.md declares type documentation and title 'The Core AI Rulebook (DSOM)'" {
  frontmatter="$(extract_frontmatter "${AGENTS_CONSTITUTION}")"
  echo "${frontmatter}" | grep -Fxq 'type: documentation'
  echo "${frontmatter}" | grep -Fxq 'title: "The Core AI Rulebook (DSOM)"'
}

@test "AGENTS.md (root gateway) declares type documentation and title 'The Agent Registry & DSOM Gateway'" {
  frontmatter="$(extract_frontmatter "${AGENTS_GATEWAY}")"
  echo "${frontmatter}" | grep -Fxq 'type: documentation'
  echo "${frontmatter}" | grep -Fxq 'title: "The Agent Registry & DSOM Gateway"'
}

@test ".agents/brain/active_context_manifest.md declares type context_manifest" {
  frontmatter="$(extract_frontmatter "${BRAIN_ACTIVE_CONTEXT}")"
  echo "${frontmatter}" | grep -Fxq 'type: context_manifest'
}

@test ".agents/brain/palace_registry.md declares type palace_index" {
  frontmatter="$(extract_frontmatter "${BRAIN_PALACE_REGISTRY}")"
  echo "${frontmatter}" | grep -Fxq 'type: palace_index'
}

@test ".agents/brain/task.md declares type task_ledger" {
  frontmatter="$(extract_frontmatter "${BRAIN_TASK}")"
  echo "${frontmatter}" | grep -Fxq 'type: task_ledger'
}

@test ".agents/brain/walkthrough.md declares type session_walkthrough" {
  frontmatter="$(extract_frontmatter "${BRAIN_WALKTHROUGH}")"
  echo "${frontmatter}" | grep -Fxq 'type: session_walkthrough'
}

# ---------------------------------------------------------------------------
# .agents/AGENTS.md (Sovereign AI Constitution) content checks
# ---------------------------------------------------------------------------

@test ".agents/AGENTS.md Core Rules section enumerates exactly 29 numbered rules" {
  core_rules_block="$(awk '/^## Core Rules:$/{flag=1; next} /^## /{flag=0} flag' "${AGENTS_CONSTITUTION}")"
  rule_count="$(echo "${core_rules_block}" | grep -cE '^[0-9]+\. \*\*')"
  [ "${rule_count}" -eq 29 ]
}

@test ".agents/AGENTS.md numbers its Core Rules sequentially from 1 to 29 without gaps or duplicates" {
  core_rules_block="$(awk '/^## Core Rules:$/{flag=1; next} /^## /{flag=0} flag' "${AGENTS_CONSTITUTION}")"
  number_list="$(echo "${core_rules_block}" | grep -oE '^[0-9]+\.' | tr -d '.')"
  mapfile -t numbers <<< "${number_list}"
  [ "${#numbers[@]}" -eq 29 ]
  for i in "${!numbers[@]}"; do
    expected=$((i + 1))
    [ "${numbers[$i]}" -eq "${expected}" ]
  done
}

@test ".agents/AGENTS.md Rule 23 documents the Dual Agent Registry (Root Gateway) mandate" {
  grep -qF '23. **Dual Agent Registry (Root Gateway Mandate):** Every DSOM project must maintain two synchronized `AGENTS.md` files' "${AGENTS_CONSTITUTION}"
}

@test ".agents/AGENTS.md Rule 28 documents the Downstream Asymmetry & Universal Gateway Matrix mandate" {
  grep -qF '28. **Downstream Asymmetry & Cross-Agent Honor Mandate:**' "${AGENTS_CONSTITUTION}"
  grep -qF '`.cursorrules`, `CLAUDE.md`, `.github/copilot-instructions.md`, `AGENTS.md`' "${AGENTS_CONSTITUTION}"
}

@test ".agents/AGENTS.md documents the Mechanical Boot Sequence and 5-Step Discovery Flow" {
  grep -qF '### 1. The Mechanical Boot Sequence' "${AGENTS_CONSTITUTION}"
  grep -qF '### 2. The 5-Step Local Knowledge-First Discovery Flow' "${AGENTS_CONSTITUTION}"
  grep -qF '5. **Physical Execution:** Execute terminal commands only after discovery is complete.' "${AGENTS_CONSTITUTION}"
}

@test ".agents/AGENTS.md documents the LinuxMalaysia Cognitive Twin Persona Profile" {
  grep -qF '## Cognitive Twin Persona Profile (LinuxMalaysia)' "${AGENTS_CONSTITUTION}"
  grep -qF 'Harisfazillah Jamel (Handle: LinuxMalaysia), Senior ICT Consultant, COO, FOSS Advocate.' "${AGENTS_CONSTITUTION}"
}

# ---------------------------------------------------------------------------
# Root AGENTS.md (gateway) content checks
# ---------------------------------------------------------------------------

@test "AGENTS.md (root gateway) points AI agents to the full rulebook at .agents/AGENTS.md" {
  grep -qF '[`.agents/AGENTS.md`](.agents/AGENTS.md)' "${AGENTS_GATEWAY}"
  grep -qF 'all 29 detailed rules governing this project.' "${AGENTS_GATEWAY}"
}

@test "AGENTS.md (root gateway) enumerates all four spatial memory brain files" {
  grep -qF '`task.md` — Active and completed task list (present state).' "${AGENTS_GATEWAY}"
  grep -qF '`walkthrough.md` — Session history and Mental Anchors (past state).' "${AGENTS_GATEWAY}"
  grep -qF '`palace_registry.md` — The Sovereign Markdown Palace spatial index.' "${AGENTS_GATEWAY}"
  grep -qF '`active_context_manifest.md` — Live list of files currently in scope.' "${AGENTS_GATEWAY}"
}

@test "AGENTS.md (root gateway) documents the Deep State of Mind Core Principles table" {
  grep -qF '## Deep State of Mind (DSOM) Core Principles' "${AGENTS_GATEWAY}"
  grep -qF '| Principle | Description |' "${AGENTS_GATEWAY}"
  grep -qF '**Zero-Global / Spatial Memory**' "${AGENTS_GATEWAY}"
  grep -qF '**Downstream Asymmetry & Cross-Agent Honor**' "${AGENTS_GATEWAY}"
}

# ---------------------------------------------------------------------------
# .agents/brain/ spatial memory content checks
# ---------------------------------------------------------------------------

@test ".agents/brain/task.md lists exactly two completed checklist items and five pending checklist items" {
  completed_count="$(grep -cE '^\- \[x\]' "${BRAIN_TASK}")"
  pending_count="$(grep -cE '^\- \[ \]' "${BRAIN_TASK}")"
  [ "${completed_count}" -eq 2 ]
  [ "${pending_count}" -eq 5 ]
}

@test ".agents/brain/task.md marks DSOM adoption and dual gateway establishment as complete" {
  grep -qF -- '- [x] Adopt Deep State of Mind (DSOM) framework for the AI workspace' "${BRAIN_TASK}"
  grep -qF -- '- [x] Establish root gateway `AGENTS.md` and sovereign constitution `.agents/AGENTS.md`' "${BRAIN_TASK}"
}

@test ".agents/brain/task.md includes a Completed Tasks section" {
  grep -qF '## Completed Tasks' "${BRAIN_TASK}"
  grep -qF 'Initial exploration of DSOM framework entry points and site content.' "${BRAIN_TASK}"
}

@test ".agents/brain/walkthrough.md records the DSOM Adoption session anchor and references Rule 23" {
  grep -qF '## Session Anchor: 2026-08-22 - DSOM Adoption' "${BRAIN_WALKTHROUGH}"
  grep -qF 'Dual Agent Registry mandate (Rule 23)' "${BRAIN_WALKTHROUGH}"
}

@test ".agents/brain/walkthrough.md records configuration of the Universal Gateway Matrix files" {
  grep -qF '`.cursorrules`, `CLAUDE.md`, `.github/copilot-instructions.md`' "${BRAIN_WALKTHROUGH}"
}

@test ".agents/brain/palace_registry.md maps all seven documented rooms with an access level" {
  row_count="$(grep -cE '^\| `.*` \|.*\|.*\|$' "${BRAIN_PALACE_REGISTRY}")"
  [ "${row_count}" -eq 7 ]
  grep -qF '| `AGENTS.md` | Root Agent Gateway | Public / Entry |' "${BRAIN_PALACE_REGISTRY}"
  grep -qF '| `.agents/AGENTS.md` | Full Sovereign AI Constitution | Core Governance |' "${BRAIN_PALACE_REGISTRY}"
  grep -qF '| `test-scripts/` | BATS Test Suites | Verification Gate |' "${BRAIN_PALACE_REGISTRY}"
}

@test ".agents/brain/active_context_manifest.md lists exactly the nine active-scope files introduced by this PR" {
  entry_count="$(grep -cE '^\- `.*`$' "${BRAIN_ACTIVE_CONTEXT}")"
  [ "${entry_count}" -eq 9 ]
  for doc in "${ALL_DSOM_FILES[@]}"; do
    grep -qF "\`${doc}\`" "${BRAIN_ACTIVE_CONTEXT}"
  done
}

# ---------------------------------------------------------------------------
# Universal Gateway Matrix quick-reference files
# ---------------------------------------------------------------------------

@test ".cursorrules directs Cursor to read the 29 Constitutional AI Laws before processing requests" {
  grep -qF 'read `.agents/AGENTS.md` to load the 29 Constitutional AI Laws' "${CURSORRULES}"
}

@test ".cursorrules enumerates exactly five mandatory protocols" {
  protocol_count="$(grep -cE '^[0-9]+\. \*\*' "${CURSORRULES}")"
  [ "${protocol_count}" -eq 5 ]
}

@test ".cursorrules enumerates the four spatial memory brain files and mandates uv-based Python execution" {
  grep -qF '`task.md`, `walkthrough.md`, `palace_registry.md`, `active_context_manifest.md`' "${CURSORRULES}"
  grep -qF 'Use `uv run` for Python executions. Do not use raw `pip` or global `python`.' "${CURSORRULES}"
}

@test ".cursorrules mandates granular atomic commits and forbids blanket git commit -am" {
  grep -qF 'Never use blanket `git commit -am` commands.' "${CURSORRULES}"
}

@test ".github/copilot-instructions.md directs Copilot to follow both AGENTS.md files and use OKF frontmatter" {
  grep -qF 'Follow `.agents/AGENTS.md` and `AGENTS.md` at all times.' "${COPILOT_INSTRUCTIONS}"
  grep -qF 'Ensure all `.md` files contain valid OKF (v0.1/v0.2) YAML frontmatter.' "${COPILOT_INSTRUCTIONS}"
}

@test ".github/copilot-instructions.md mandates uv-based Python execution and .agents/brain/ as operational state" {
  grep -qF 'Operational state resides in `.agents/brain/`.' "${COPILOT_INSTRUCTIONS}"
  grep -qF 'Strictly use `uv run` for Python script executions.' "${COPILOT_INSTRUCTIONS}"
}

@test "CLAUDE.md instructs Claude to read the full constitution immediately upon initialization" {
  grep -qF 'Read `.agents/AGENTS.md` immediately upon initialization to establish operational identity, laws, and the LinuxMalaysia persona.' "${CLAUDE_MD}"
}

@test "CLAUDE.md enumerates exactly four mandatory instructions covering memory, discovery, and environment constraints" {
  instruction_count="$(grep -cE '^[0-9]+\. \*\*' "${CLAUDE_MD}")"
  [ "${instruction_count}" -eq 4 ]
  grep -qF 'Search local OKF frontmatter in `.agents/brain/` and `docs/` before executing terminal commands.' "${CLAUDE_MD}"
  grep -qF 'Always use `uv run` for Python execution. Follow strict atomic commit rules.' "${CLAUDE_MD}"
}

# ---------------------------------------------------------------------------
# Regression / boundary checks
# ---------------------------------------------------------------------------

@test "Universal Gateway Matrix quick-reference files (.cursorrules, CLAUDE.md, copilot-instructions.md) remain plain Markdown without OKF frontmatter" {
  for doc in ".cursorrules" "CLAUDE.md" ".github/copilot-instructions.md"; do
    first_line="$(head -n 1 "${REPO_ROOT}/${doc}")"
    [ "${first_line}" != "---" ]
  done
}

@test "Dual Agent Registry Mandate: both AGENTS.md gateway files exist and the root gateway links to the full constitution" {
  [ -f "${AGENTS_GATEWAY}" ]
  [ -f "${AGENTS_CONSTITUTION}" ]
  grep -qF '.agents/AGENTS.md' "${AGENTS_GATEWAY}"
}

@test "Universal Gateway Matrix: all four cross-platform gateway files referenced by Rule 28 exist on disk" {
  [ -f "${CURSORRULES}" ]
  [ -f "${CLAUDE_MD}" ]
  [ -f "${COPILOT_INSTRUCTIONS}" ]
  [ -f "${AGENTS_GATEWAY}" ]
}