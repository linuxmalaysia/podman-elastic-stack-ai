#!/usr/bin/env bash
# ==============================================================================
# BIDIRECTIONAL TELEMETRY & FEEDBACK BRIDGE SCRIPT
# ==============================================================================
# Strict standards: UK English, set -euo pipefail, POSIX compliance, dynamic traps.
# Parses /tmp/jules_telemetry.json, constructs Markdown report, and posts to
# Google Jules CLI/API & GitHub Pull Request.
# ==============================================================================

set -euo pipefail

# Define Color Loggers
log_info()    { echo -e "\033[1;36m[INFO]\033[0m $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warn()    { echo -e "\033[1;33m[WARN]\033[0m $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error()   { echo -e "\033[1;31m[ERROR]\033[0m $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

# Establish variables
TELEMETRY_JSON="/tmp/jules_telemetry.json"
REPORT_MD=""

# Establish Trap for Cleanup and Exit Status Tracking on EXIT
cleanup() {
    local exit_code=$?
    if [ -n "${REPORT_MD}" ] && [ -f "${REPORT_MD}" ]; then
        rm -f "${REPORT_MD}"
    fi
    if [ "${exit_code}" -eq 0 ]; then
        log_success "Feedback bridge finished successfully."
    else
        log_error "Feedback bridge execution aborted or failed with status code ${exit_code}."
    fi
}
trap cleanup EXIT

# Separate traps for SIGINT and SIGTERM to terminate with non-zero exit statuses
trap 'log_warn "SIGINT received, aborting..."; exit 130' INT
trap 'log_warn "SIGTERM received, aborting..."; exit 143' TERM

# Ensure Telemetry Data Exists before checking mode
if [ ! -f "${TELEMETRY_JSON}" ]; then
    log_error "Telemetry data file '${TELEMETRY_JSON}' not found! Please run the matrix test playbook first."
    exit 1
fi

# Get EXECUTION_MODE from environment, or from /tmp/jules_telemetry.json fallback
MODE="${EXECUTION_MODE:-}"
if [ -z "${MODE}" ]; then
    MODE=$(python3 -c "import json; print(json.load(open('${TELEMETRY_JSON}')).get('execution_mode', 'user'))" 2>/dev/null || echo "user")
fi
MODE="${MODE:-user}"

# Early Developer-Mode Guard: return 0 before report generation or dispatch if mode is not dev
if [ "${MODE}" != "dev" ]; then
    log_info "Execution mode is '${MODE}' (not 'dev'). Bypassing report generation and feedback dispatch early."
    exit 0
fi

log_info "Parsing telemetry data and compiling Markdown report..."

# Replace predictable REPORT_MD creation with a mktemp-generated path enforcing mode 0600
REPORT_MD=$(mktemp /tmp/jules_telemetry_report.XXXXXX.md)
chmod 0600 "${REPORT_MD}"

# Inline Python parser for structured conversion of JSON to robust Markdown
python3 - <<EOF
import json
import sys

try:
    with open("${TELEMETRY_JSON}", "r") as f:
        data = json.load(f)
except Exception as e:
    print(f"Error decoding telemetry JSON: {e}", file=sys.stderr)
    sys.exit(1)

status_emoji = "✅" if data.get("overall_status") == "passed" else "❌"
pr_id = data.get("pr_id", "0")

md = []
md.append("# 🚀 Google Jules - Multi-OS Matrix Test Execution Report")
md.append(f"**Overall Status:** {data.get('overall_status', 'unknown').upper()} {status_emoji}")
md.append(f"**Execution Mode:** \`{data.get('execution_mode', 'dev')}\` | **PR ID:** \`#{pr_id}\`")
md.append(f"**Timestamp:** \`{data.get('timestamp', 'N/A')}\`\n")

md.append("### 💻 Host Environment")
host = data.get("host_info", {})
md.append(f"- **OS Family:** {host.get('os_family', 'Unknown')}")
md.append(f"- **Kernel Version:** \`{host.get('kernel_version', 'Unknown')}\`")
md.append(f"- **Podman Version:** \`{host.get('podman_version', 'Unknown')}\`\n")

md.append("### 📊 Test Matrix Results")
md.append("| Target Distro | Container Image | Status | Exit Code | CPU % | Memory | Error Summary |")
md.append("| :--- | :--- | :--- | :--- | :--- | :--- | :--- |")

results = data.get("results", [])
# Handle potential string format or dictionary list for results
if isinstance(results, str):
    try:
        results = json.loads(results)
    except Exception:
        results = []

logs_section = ["\n### 📝 Execution Logs"]

for res in results:
    distro = res.get("distro", "Unknown")
    img = res.get("image", "Unknown")
    status = res.get("status", "Unknown").upper()
    emoji = "✅ PASSED" if status == "PASSED" else "❌ FAILED"
    code = res.get("exit_code", -1)
    cpu = res.get("cpu_percentage", "0.0%")
    mem = str(res.get("memory_usage_bytes", "0"))
    err = res.get("error_summary", "") or "-"
    logs = res.get("logs", "") or "No output logged."

    md.append(f"| **{distro}** | \`{img}\` | **{emoji}** | \`{code}\` | \`{cpu}\` | \`{mem}\` | {err} |")
    logs_section.append(
        f"<details>\n<summary><b>{distro} ({status}) Log Output</b></summary>\n\n\`\`\`text\n{logs}\n\`\`\`\n</details>\n"
    )

md.extend(logs_section)

try:
    with open("${REPORT_MD}", "w") as f:
        f.write('\n'.join(md))
except Exception as e:
    print(f"Error writing markdown report: {e}", file=sys.stderr)
    sys.exit(1)

print("Report generated successfully.")
EOF

log_success "Markdown report generated at '${REPORT_MD}'"

# Extract metadata for feedback
PR_NUMBER=$(python3 -c "import json; print(json.load(open('${TELEMETRY_JSON}')).get('pr_id', '0'))" 2>/dev/null || echo "0")
OVERALL_STATUS=$(python3 -c "import json; print(json.load(open('${TELEMETRY_JSON}')).get('overall_status', 'passed'))" 2>/dev/null || echo "passed")

# ------------------------------------------------------------------------------
# 1. GitHub Pull Request Integration via gh CLI
# ------------------------------------------------------------------------------
if command -v gh >/dev/null 2>&1; then
    if [ "${PR_NUMBER}" != "0" ] && [ -n "${PR_NUMBER}" ]; then
        log_info "Attempting to post report to GitHub Pull Request #${PR_NUMBER}..."
        # Verify if the user is authenticated with GitHub CLI
        if gh auth status >/dev/null 2>&1; then
            if gh pr comment "${PR_NUMBER}" --body-file "${REPORT_MD}" >/dev/null 2>&1; then
                log_success "Successfully posted test report comment on GitHub PR #${PR_NUMBER}!"
            else
                log_warn "Failed to post comment to PR #${PR_NUMBER}. This may be due to repository permissions."
            fi
        else
            log_warn "GitHub CLI ('gh') is not authenticated. Skipping PR comment creation."
        fi
    else
        log_info "PR_ID is set to default (0) or empty. Skipping GitHub PR comments."
    fi
else
    log_warn "GitHub CLI ('gh') is not installed or not available on PATH. Skipping GitHub PR comment."
fi

# ------------------------------------------------------------------------------
# 2. Google Jules CLI Session Context Integration
# ------------------------------------------------------------------------------
JULES_POSTED=false

if command -v jules >/dev/null 2>&1; then
    log_info "Google Jules CLI detected. Attempting to feed session context..."

    # Try feeding via jules feed command
    if jules feed --help >/dev/null 2>&1; then
        if jules feed --message-file "${REPORT_MD}" >/dev/null 2>&1; then
            log_success "Successfully fed matrix telemetry to active Jules session via 'jules feed'!"
            JULES_POSTED=true
        fi
    fi

    # Fallback to jules chat context inject if jules feed wasn't successful/supported
    if [ "${JULES_POSTED}" = "false" ]; then
        if jules chat --help >/dev/null 2>&1; then
            if jules chat --message "Local Test Matrix Execution Report: $(cat "${REPORT_MD}")" >/dev/null 2>&1; then
                log_success "Successfully injected matrix telemetry into active Jules session via 'jules chat'!"
                JULES_POSTED=true
            fi
        fi
    fi
else
    log_warn "Google Jules CLI ('jules') is not installed or not available on PATH."
fi

# ------------------------------------------------------------------------------
# 3. Google Jules REST API Direct Fallback Integration
# ------------------------------------------------------------------------------
if [ "${JULES_POSTED}" = "false" ] && [ -n "${JULES_API_ENDPOINT:-}" ]; then
    log_info "Attempting to post telemetry to local Google Jules REST API at '${JULES_API_ENDPOINT}'..."
    if command -v curl >/dev/null 2>&1; then
        # Updated curl invocation to include connection timeout (10s) and total request timeout (30s)
        HTTP_RESPONSE=$(curl -s --connect-timeout 10 --max-time 30 -o /dev/null -w "%{http_code}" \
            -X POST "${JULES_API_ENDPOINT}/telemetry" \
            -H "Authorization: Bearer ${JULES_SESSION_TOKEN:-}" \
            -H "Content-Type: application/json" \
            -d @"${TELEMETRY_JSON}" || echo "failed")

        if [ "${HTTP_RESPONSE}" = "200" ] || [ "${HTTP_RESPONSE}" = "201" ]; then
            log_success "Successfully posted telemetry data directly to Jules REST API (HTTP ${HTTP_RESPONSE})!"
            JULES_POSTED=true
        else
            log_warn "Failed to post telemetry to Jules REST API. HTTP Response Code: ${HTTP_RESPONSE}"
        fi
    else
        log_warn "curl is missing. Cannot call Jules REST API."
    fi
fi

# ------------------------------------------------------------------------------
# 4. Graceful Operational Fallback
# ------------------------------------------------------------------------------
if [ "${JULES_POSTED}" = "false" ]; then
    log_warn "======================================================================"
    log_warn "WARNING: Telemetry report could not be automatically streamed to Jules!"
    log_warn "======================================================================"
    log_warn "1. The local jules CLI is not present/configured on WSL2."
    log_warn "2. JULES_API_ENDPOINT environment variable is not defined."
    log_warn "----------------------------------------------------------------------"
    log_warn "Action required: Human operators can manually read the generated"
    log_warn "Markdown report file and paste it into the Jules conversation context:"
    log_warn "   cat ${REPORT_MD}"
    log_warn "======================================================================"
fi

# Exit successfully to guarantee pipeline resiliency
exit 0
