#!/usr/bin/env bats
#
# Tests for the new "Step 0 - WSL2 Tuning and Optimization" hook added to
# ansible/setup_elasticsearch.yml and the new ansible/tasks/wsl_tuning.yml
# task file it includes (kernel tuning, .wslconfig generation, and
# /etc/wsl.conf / limits.conf adjustments for the WSL2 deployment option).
#
# These are split into two groups:
#   1. Pure content/regression tests (grep/awk based, no ansible required)
#      that guard the exact structure, values, and ordering of the new
#      tasks against accidental drift or reverts.
#   2. Logic tests that extract the verbatim Jinja/set_fact expressions
#      introduced by this file (memory-tier calculation, username
#      fallback-chain resolution, and sysctl-value integer parsing) and
#      evaluate them for real via `ansible-playbook`, so the exact
#      conditional logic is exercised rather than a reimplementation of
#      it. These are skipped automatically if ansible-playbook is not
#      available on PATH.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SETUP_ES_PLAYBOOK="${REPO_ROOT}/ansible/setup_elasticsearch.yml"
WSL_TUNING_TASK="${REPO_ROOT}/ansible/tasks/wsl_tuning.yml"
REFERENCE_TUNING_DOC="${REPO_ROOT}/docs/REFERENCE_TUNING.md"

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  # Discover the real, fully-resolved python executable so ansible-playbook
  # (which needs a python interpreter on the "remote" side, even for
  # connection=local) doesn't get tripped up by pyenv shims, mirroring the
  # approach already used in test-scripts/setup_step1_install.bats.
  REAL_PYTHON="$(python3 -c 'import sys, os; print(os.path.realpath(sys.executable))' 2>/dev/null || command -v python3 || command -v python)"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

# ------------------------------------------------------------------------
# Basic existence checks
# ------------------------------------------------------------------------

@test "ansible/tasks/wsl_tuning.yml exists and is readable" {
  [ -f "${WSL_TUNING_TASK}" ]
  [ -r "${WSL_TUNING_TASK}" ]
}

@test "ansible/setup_elasticsearch.yml exists and is readable" {
  [ -f "${SETUP_ES_PLAYBOOK}" ]
  [ -r "${SETUP_ES_PLAYBOOK}" ]
}

# ------------------------------------------------------------------------
# setup_elasticsearch.yml: "Step 0 - WSL2 Tuning and Optimization" hook
# ------------------------------------------------------------------------

@test "setup_elasticsearch.yml declares Step 0 to include the WSL2 tuning tasks" {
  grep -qF '"Step 0 - WSL2 Tuning and Optimization"' "${SETUP_ES_PLAYBOOK}"
  grep -qF 'include_tasks: tasks/wsl_tuning.yml' "${SETUP_ES_PLAYBOOK}"
}

@test "setup_elasticsearch.yml only includes the WSL2 tuning tasks for the wsl2 deployment option" {
  # The "when" gate must immediately follow the include_tasks line so it
  # actually applies to Step 0, not some later task.
  local next_line
  next_line="$(grep -A1 -F 'include_tasks: tasks/wsl_tuning.yml' "${SETUP_ES_PLAYBOOK}" | tail -n1 | sed -E 's/^[[:space:]]*//')"
  [ "${next_line}" = "when: deployment_option == 'wsl2'" ]
}

@test "setup_elasticsearch.yml runs Step 0 before Step 1 and after loading group_vars" {
  local vars_line step0_line step1_line
  vars_line="$(grep -n -F 'include_vars:' "${SETUP_ES_PLAYBOOK}" | head -1 | cut -d: -f1)"
  step0_line="$(grep -n -F '"Step 0 - WSL2 Tuning and Optimization"' "${SETUP_ES_PLAYBOOK}" | head -1 | cut -d: -f1)"
  step1_line="$(grep -n -F '"Step 1 - Check and Install Podman and Podman Compose"' "${SETUP_ES_PLAYBOOK}" | head -1 | cut -d: -f1)"

  [ -n "${vars_line}" ]
  [ -n "${step0_line}" ]
  [ -n "${step1_line}" ]
  [ "${vars_line}" -lt "${step0_line}" ]
  [ "${step0_line}" -lt "${step1_line}" ]
}

@test "setup_elasticsearch.yml Step 1 task name is unchanged by the Step 0 insertion" {
  grep -qF '"Step 1 - Check and Install Podman and Podman Compose"' "${SETUP_ES_PLAYBOOK}"
}

# ------------------------------------------------------------------------
# wsl_tuning.yml: header / provenance comments
# ------------------------------------------------------------------------

@test "wsl_tuning.yml documents its source references in header comments" {
  grep -qF 'https://www.thetributary.ai/blog/optimizing-wsl2-claude-code-performance-guide/' "${WSL_TUNING_TASK}"
  grep -qF 'https://linuxmalaysia.github.io/podman-elastic-stack-ai/WSL-3NODE-CLUSTER-GUIDE/' "${WSL_TUNING_TASK}"
}

@test "wsl_tuning.yml's referenced source URLs match those documented in docs/REFERENCE_TUNING.md" {
  [ -f "${REFERENCE_TUNING_DOC}" ]
  grep -qF 'https://www.thetributary.ai/blog/optimizing-wsl2-claude-code-performance-guide/' "${REFERENCE_TUNING_DOC}"
  grep -qF 'https://linuxmalaysia.github.io/podman-elastic-stack-ai/WSL-3NODE-CLUSTER-GUIDE/' "${REFERENCE_TUNING_DOC}"
}

# ------------------------------------------------------------------------
# Part A - Username Update (Dynamic Inventory & Variable Patching)
# ------------------------------------------------------------------------

@test "wsl_tuning.yml Part A detects the active username via whoami and id -un, tolerating failure" {
  grep -qF '"Part A - Username Update (Dynamic Inventory & Variable Patching)"' "${WSL_TUNING_TASK}"
  grep -qF 'command: whoami' "${WSL_TUNING_TASK}"
  grep -qF "command: id -un" "${WSL_TUNING_TASK}"
  # Both detection commands must be read-only / never fail the play.
  grep -A3 -F 'command: whoami' "${WSL_TUNING_TASK}" | grep -qF 'changed_when: false'
  grep -A4 -F 'command: whoami' "${WSL_TUNING_TASK}" | grep -qF 'failed_when: false'
}

@test "wsl_tuning.yml Part A falls back to the literal 'your_username' placeholder when detection fails" {
  grep -qF "else 'your_username'" "${WSL_TUNING_TASK}"
}

@test "wsl_tuning.yml Part A patches hosts.wsl.3node.yml's quoted your_username placeholder" {
  grep -qF 'path: "{{ elk_base_dir }}/inventory/hosts.wsl.3node.yml"' "${WSL_TUNING_TASK}"
  grep -qF "regexp: '\"your_username\"'" "${WSL_TUNING_TASK}"
  grep -qF "replace: '\"{{ resolved_username }}\"'" "${WSL_TUNING_TASK}"
  grep -qF 'delegate_to: localhost' "${WSL_TUNING_TASK}"
  grep -qF "when: resolved_username != 'your_username'" "${WSL_TUNING_TASK}"
}

@test "wsl_tuning.yml Part A overrides ansible_user/dsom_group only when they are still the placeholder" {
  grep -qF "ansible_user: \"{{ resolved_username }}\"" "${WSL_TUNING_TASK}"
  grep -qF "dsom_group: \"{{ resolved_username }}\"" "${WSL_TUNING_TASK}"
  grep -qF "when: ansible_user == 'your_username' or dsom_group == 'your_username'" "${WSL_TUNING_TASK}"
}

# ------------------------------------------------------------------------
# Part B - vm.max_map_count kernel tuning
# ------------------------------------------------------------------------

@test "wsl_tuning.yml Part B checks and tunes vm.max_map_count to at least 262144" {
  grep -qF '"Part B - Kernel Tuning check for vm.max_map_count"' "${WSL_TUNING_TASK}"
  grep -qF 'command: sysctl -n vm.max_map_count' "${WSL_TUNING_TASK}"
  grep -qF 'name: vm.max_map_count' "${WSL_TUNING_TASK}"
  grep -qF 'value: "262144"' "${WSL_TUNING_TASK}"
  grep -qF 'max_map_count_val | int < 262144' "${WSL_TUNING_TASK}"
}

@test "wsl_tuning.yml Part B's sysctl module task escalates privileges and reloads" {
  grep -A6 -F 'name: vm.max_map_count' "${WSL_TUNING_TASK}" | grep -qF 'state: present'
  grep -A6 -F 'name: vm.max_map_count' "${WSL_TUNING_TASK}" | grep -qF 'reload: yes'
  grep -A6 -F 'name: vm.max_map_count' "${WSL_TUNING_TASK}" | grep -qF 'become: true'
}

# ------------------------------------------------------------------------
# Part C - CPU/Memory calculation and .wslconfig generation
# ------------------------------------------------------------------------

@test "wsl_tuning.yml Part C computes wsl_processors from ansible_processor_vcpus with a default of 8" {
  grep -qF '"Part C - CPU and Memory Calculation suitable for host system"' "${WSL_TUNING_TASK}"
  grep -qF 'wsl_processors: "{{ ansible_processor_vcpus | default(8) }}"' "${WSL_TUNING_TASK}"
}

@test "wsl_tuning.yml Part C's wsl_memory_gb tiers use the documented RAM thresholds and GB values" {
  grep -qF 'set ram_mb = ansible_memtotal_mb | default(16384) | int' "${WSL_TUNING_TASK}"
  grep -qF 'if ram_mb <= 16384' "${WSL_TUNING_TASK}"
  grep -qF 'elif ram_mb <= 32768' "${WSL_TUNING_TASK}"
  grep -qF 'elif ram_mb <= 65536' "${WSL_TUNING_TASK}"
  # Each tier's chosen GB value must appear as its own line inside the block.
  grep -qE '^[[:space:]]+10[[:space:]]*$' "${WSL_TUNING_TASK}"
  grep -qE '^[[:space:]]+22[[:space:]]*$' "${WSL_TUNING_TASK}"
  grep -qE '^[[:space:]]+48[[:space:]]*$' "${WSL_TUNING_TASK}"
  grep -qE '^[[:space:]]+96[[:space:]]*$' "${WSL_TUNING_TASK}"
}

@test "wsl_tuning.yml Part C's recommended .wslconfig block contains the documented performance settings" {
  grep -qF 'memory={{ wsl_memory_gb }}GB' "${WSL_TUNING_TASK}"
  grep -qF 'processors={{ wsl_processors }}' "${WSL_TUNING_TASK}"
  grep -qF 'swap=16GB' "${WSL_TUNING_TASK}"
  grep -qF 'networkingMode=mirrored' "${WSL_TUNING_TASK}"
  grep -qF 'dnsTunneling=true' "${WSL_TUNING_TASK}"
  grep -qF 'autoProxy=true' "${WSL_TUNING_TASK}"
  grep -qF 'autoMemoryReclaim=gradual' "${WSL_TUNING_TASK}"
  grep -qF 'sparseVhd=true' "${WSL_TUNING_TASK}"
}

@test "wsl_tuning.yml Part C persists the tuned .wslconfig under /opt/dsom-persistence without failing the play" {
  grep -qF 'path: "/opt/dsom-persistence"' "${WSL_TUNING_TASK}"
  grep -qF 'dest: "/opt/dsom-persistence/wsl2_tuned.wslconfig"' "${WSL_TUNING_TASK}"
  # Best-effort persistence: must not abort the whole playbook if it fails.
  grep -A6 -F 'dest: "/opt/dsom-persistence/wsl2_tuned.wslconfig"' "${WSL_TUNING_TASK}" | grep -qF 'failed_when: false'
}

@test "wsl_tuning.yml Part C discovers Windows user profile directories, excluding shared/system profiles" {
  grep -qF "find /mnt/c/Users -mindepth 1 -maxdepth 1 -type d" "${WSL_TUNING_TASK}"
  grep -qF '! -name "Public"' "${WSL_TUNING_TASK}"
  grep -qF '! -name "Default"' "${WSL_TUNING_TASK}"
  grep -qF '! -name "Default User"' "${WSL_TUNING_TASK}"
  grep -qF '! -name "All Users"' "${WSL_TUNING_TASK}"
}

@test "wsl_tuning.yml Part C generates a per-user .wslconfig.recommended for each discovered Windows profile" {
  grep -qF 'dest: "{{ item }}/.wslconfig.recommended"' "${WSL_TUNING_TASK}"
  grep -qF 'loop: "{{ windows_users.stdout_lines | default([]) }}"' "${WSL_TUNING_TASK}"
  grep -qF 'ignore_errors: true' "${WSL_TUNING_TASK}"
}

# ------------------------------------------------------------------------
# Part D - /etc/wsl.conf optimizations
# ------------------------------------------------------------------------

@test "wsl_tuning.yml Part D writes the expected /etc/wsl.conf sections" {
  grep -qF '"Part D - Adopt /etc/wsl.conf optimizations inside WSL"' "${WSL_TUNING_TASK}"
  grep -qF 'path: /etc/wsl.conf' "${WSL_TUNING_TASK}"
  grep -qF 'systemd=true' "${WSL_TUNING_TASK}"
  grep -qF 'options=metadata,umask=22,fmask=11' "${WSL_TUNING_TASK}"
  grep -qF 'generateHosts=true' "${WSL_TUNING_TASK}"
  grep -qF 'generateResolvConf=true' "${WSL_TUNING_TASK}"
  grep -qF 'appendWindowsPath=true' "${WSL_TUNING_TASK}"
  grep -qF '[gpu]' "${WSL_TUNING_TASK}"
  grep -qF 'useWindowsTimezone=true' "${WSL_TUNING_TASK}"
}

@test "wsl_tuning.yml Part D's /etc/wsl.conf task escalates privileges and creates the file if missing" {
  grep -A25 -F 'path: /etc/wsl.conf' "${WSL_TUNING_TASK}" | grep -qF 'create: yes'
  grep -A25 -F 'path: /etc/wsl.conf' "${WSL_TUNING_TASK}" | grep -qF 'become: true'
}

# ------------------------------------------------------------------------
# Part E - fs.inotify.max_user_watches tuning
# ------------------------------------------------------------------------

@test "wsl_tuning.yml Part E checks and tunes fs.inotify.max_user_watches to at least 524288" {
  grep -qF '"Part E - Adopt fs.inotify.max_user_watches tuning"' "${WSL_TUNING_TASK}"
  grep -qF 'command: sysctl -n fs.inotify.max_user_watches' "${WSL_TUNING_TASK}"
  grep -qF 'name: fs.inotify.max_user_watches' "${WSL_TUNING_TASK}"
  grep -qF 'value: "524288"' "${WSL_TUNING_TASK}"
  grep -qF 'inotify_watches_val | int < 524288' "${WSL_TUNING_TASK}"
}

# ------------------------------------------------------------------------
# Part F - file descriptor limits
# ------------------------------------------------------------------------

@test "wsl_tuning.yml Part F raises nofile soft/hard limits to 65535 in limits.conf" {
  grep -qF '"Part F - Adopt file descriptor limits optimization"' "${WSL_TUNING_TASK}"
  grep -qF 'path: /etc/security/limits.conf' "${WSL_TUNING_TASK}"
  grep -qF '*  soft  nofile  65535' "${WSL_TUNING_TASK}"
  grep -qF '*  hard  nofile  65535' "${WSL_TUNING_TASK}"
}

@test "wsl_tuning.yml Part F is unconditional (no 'when' guard) and always escalates privileges" {
  # Extract from the Part F marker to end-of-file and confirm there is no
  # "when:" clause gating it (unlike Parts B/E, which are conditional on
  # their current sysctl value), while it still uses become: true.
  local part_f_block
  part_f_block="$(awk '/"Part F - Adopt file descriptor limits optimization"/{capture=1} capture{print}' "${WSL_TUNING_TASK}")"
  [[ "${part_f_block}" == *"become: true"* ]]
  [[ "${part_f_block}" != *"when:"* ]]
}

# ------------------------------------------------------------------------
# Standalone syntax validation (skipped if ansible-playbook is unavailable)
# ------------------------------------------------------------------------

@test "wsl_tuning.yml has valid Ansible task-list syntax when wrapped in a minimal play" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  local wrapper="${TEST_TMPDIR}/wrapper.yml"
  cat > "${wrapper}" <<EOF
---
- hosts: localhost
  connection: local
  gather_facts: false
  vars:
    elk_base_dir: "${TEST_TMPDIR}"
  tasks:
    - include_tasks: ${WSL_TUNING_TASK}
EOF
  run ansible-playbook --syntax-check "${wrapper}"
  [ "${status}" -eq 0 ]
}

# ------------------------------------------------------------------------
# Logic tests: extract the verbatim expressions and evaluate them for real
# via ansible-playbook. Each test writes the computed value to a plain file
# with a "copy" task so we don't have to parse callback output formatting.
# ------------------------------------------------------------------------

# Extracts the wsl_memory_gb folded-scalar block verbatim (key line through
# the closing {%- endif -%} tag, inclusive), preserving its exact original
# indentation so YAML folding behaves identically once re-embedded.
_extract_memory_gb_block() {
  awk '
    /wsl_memory_gb: >-/ {capture=1}
    capture {print}
    /\{%- endif -%\}/ {if (capture) exit}
  ' "${WSL_TUNING_TASK}"
}

_run_memory_gb_harness() {
  local ram_mb="$1"
  local block result_file harness
  block="$(_extract_memory_gb_block)"
  result_file="${TEST_TMPDIR}/mem_result_$$_${RANDOM}.txt"
  harness="${TEST_TMPDIR}/mem_harness_$$_${RANDOM}.yml"
  {
    echo '---'
    echo '- hosts: localhost'
    echo '  connection: local'
    echo '  gather_facts: false'
    echo '  tasks:'
    echo '    - name: compute'
    echo '      set_fact:'
    echo "${block}"
    echo '    - name: write result'
    echo '      copy:'
    echo "        content: \"{{ wsl_memory_gb }}\""
    echo "        dest: \"${result_file}\""
  } > "${harness}"

  ansible-playbook -i localhost, -c local "${harness}" \
    -e "ansible_memtotal_mb=${ram_mb}" \
    -e "ansible_python_interpreter=${REAL_PYTHON}" >/dev/null

  cat "${result_file}"
}

@test "wsl_tuning.yml memory tier: exactly 16384MB (lower boundary) resolves to 10GB" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_memory_gb_harness 16384)"
  [ "${result}" = "10" ]
}

@test "wsl_tuning.yml memory tier: 16385MB (just above lower boundary) resolves to 22GB" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_memory_gb_harness 16385)"
  [ "${result}" = "22" ]
}

@test "wsl_tuning.yml memory tier: exactly 32768MB resolves to 22GB" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_memory_gb_harness 32768)"
  [ "${result}" = "22" ]
}

@test "wsl_tuning.yml memory tier: 32769MB (just above 32GB boundary) resolves to 48GB" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_memory_gb_harness 32769)"
  [ "${result}" = "48" ]
}

@test "wsl_tuning.yml memory tier: exactly 65536MB resolves to 48GB" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_memory_gb_harness 65536)"
  [ "${result}" = "48" ]
}

@test "wsl_tuning.yml memory tier: 65537MB (just above 64GB boundary) resolves to 96GB" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_memory_gb_harness 65537)"
  [ "${result}" = "96" ]
}

@test "wsl_tuning.yml memory tier: a very large host (e.g. 131072MB) still resolves to the top 96GB tier" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_memory_gb_harness 131072)"
  [ "${result}" = "96" ]
}

# Extracts and evaluates the resolved_username fallback-chain expression
# (whoami -> id -un -> literal 'your_username') for real, given fabricated
# rc/stdout values for each detection command.
_run_username_harness() {
  local who_rc="$1" who_stdout="$2" id_rc="$3" id_stdout="$4"
  local expr result_file harness
  expr="$(grep -F 'resolved_username:' "${WSL_TUNING_TASK}" | sed -E 's/^[[:space:]]*resolved_username:[[:space:]]*//')"
  result_file="${TEST_TMPDIR}/user_result_$$_${RANDOM}.txt"
  harness="${TEST_TMPDIR}/user_harness_$$_${RANDOM}.yml"
  cat > "${harness}" <<EOF
---
- hosts: localhost
  connection: local
  gather_facts: false
  vars:
    whoami_out:
      rc: ${who_rc}
      stdout: "${who_stdout}"
    id_out:
      rc: ${id_rc}
      stdout: "${id_stdout}"
  tasks:
    - name: compute
      set_fact:
        resolved_username: ${expr}
    - name: write result
      copy:
        content: "{{ resolved_username }}"
        dest: "${result_file}"
EOF

  ansible-playbook -i localhost, -c local "${harness}" \
    -e "ansible_python_interpreter=${REAL_PYTHON}" >/dev/null

  cat "${result_file}"
}

@test "wsl_tuning.yml username resolution: uses trimmed whoami output when whoami succeeds" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_username_harness 0 "  alice  " 1 "")"
  [ "${result}" = "alice" ]
}

@test "wsl_tuning.yml username resolution: falls back to trimmed 'id -un' output when whoami fails" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_username_harness 1 "" 0 "  bob  ")"
  [ "${result}" = "bob" ]
}

@test "wsl_tuning.yml username resolution: falls back to the literal 'your_username' when both detections fail" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_username_harness 1 "" 1 "")"
  [ "${result}" = "your_username" ]
}

@test "wsl_tuning.yml username resolution: prefers whoami over id -un when both succeed" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_username_harness 0 "carol" 0 "someone-else")"
  [ "${result}" = "carol" ]
}

# Extracts and evaluates the max_map_count_val / inotify_watches_val
# integer-parsing expressions (rc==0 AND stdout matches ^[0-9]+$ -> int,
# else 0) for real, given fabricated rc/stdout sysctl-check results.
_run_int_parse_harness() {
  local var_name="$1" reg_name="$2" cmd_rc="$3" cmd_stdout="$4"
  local expr result_file harness
  expr="$(grep -F "${var_name}:" "${WSL_TUNING_TASK}" | sed -E "s/^[[:space:]]*${var_name}:[[:space:]]*//")"
  result_file="${TEST_TMPDIR}/int_result_$$_${RANDOM}.txt"
  harness="${TEST_TMPDIR}/int_harness_$$_${RANDOM}.yml"
  cat > "${harness}" <<EOF
---
- hosts: localhost
  connection: local
  gather_facts: false
  vars:
    ${reg_name}:
      rc: ${cmd_rc}
      stdout: "${cmd_stdout}"
  tasks:
    - name: compute
      set_fact:
        ${var_name}: ${expr}
    - name: write result
      copy:
        content: "{{ ${var_name} }}"
        dest: "${result_file}"
EOF

  ansible-playbook -i localhost, -c local "${harness}" \
    -e "ansible_python_interpreter=${REAL_PYTHON}" >/dev/null

  cat "${result_file}"
}

@test "wsl_tuning.yml max_map_count_val: parses a valid numeric sysctl reading as an integer" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_int_parse_harness max_map_count_val current_max_map_count 0 "65530")"
  [ "${result}" = "65530" ]
}

@test "wsl_tuning.yml max_map_count_val: trims surrounding whitespace before parsing" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_int_parse_harness max_map_count_val current_max_map_count 0 "  262144  ")"
  [ "${result}" = "262144" ]
}

@test "wsl_tuning.yml max_map_count_val: falls back to 0 when the sysctl command fails" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_int_parse_harness max_map_count_val current_max_map_count 1 "")"
  [ "${result}" = "0" ]
}

@test "wsl_tuning.yml max_map_count_val: falls back to 0 when stdout is not purely numeric" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_int_parse_harness max_map_count_val current_max_map_count 0 "not-a-number")"
  [ "${result}" = "0" ]
}

@test "wsl_tuning.yml inotify_watches_val: parses a valid numeric sysctl reading as an integer" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_int_parse_harness inotify_watches_val current_inotify_watches 0 "524288")"
  [ "${result}" = "524288" ]
}

@test "wsl_tuning.yml inotify_watches_val: falls back to 0 when the sysctl command fails" {
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    skip "ansible-playbook is not available"
  fi
  result="$(_run_int_parse_harness inotify_watches_val current_inotify_watches 1 "")"
  [ "${result}" = "0" ]
}