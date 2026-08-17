#!/usr/bin/env bats
#
# Regression tests for the repository URL/rename update in docs/GITEA_GUIDE.md
# and docs/INSTALL.md: clone instructions and directory names were updated
# from the old HarisfazillahJamel/podman-elastic-stack repository to the
# active linuxmalaysia/podman-elastic-stack-ai repository, and the
# now-redundant "podman for AI testing" alternate clone block was removed
# from INSTALL.md.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
GITEA_GUIDE="${REPO_ROOT}/docs/GITEA_GUIDE.md"
INSTALL="${REPO_ROOT}/docs/INSTALL.md"
NEW_URL="https://github.com/linuxmalaysia/podman-elastic-stack-ai.git"
OLD_URL="https://github.com/HarisfazillahJamel/podman-elastic-stack.git"
OLD_AI_TESTING_URL="https://github.com/linuxmalaysia/podman-elastic-stack.git"

# ------------------------------------------------------------------------
# docs/GITEA_GUIDE.md
# ------------------------------------------------------------------------

@test "GITEA_GUIDE.md exists and is readable" {
  [ -f "${GITEA_GUIDE}" ]
  [ -r "${GITEA_GUIDE}" ]
}

@test "GITEA_GUIDE.md's git clone command uses the active linuxmalaysia/podman-elastic-stack-ai repository" {
  grep -qF -- "git clone ${NEW_URL}" "${GITEA_GUIDE}"
}

@test "GITEA_GUIDE.md navigates into the podman-elastic-stack-ai directory after cloning" {
  grep -qx -- 'cd podman-elastic-stack-ai' "${GITEA_GUIDE}"
}

@test "GITEA_GUIDE.md no longer references the old HarisfazillahJamel repository URL" {
  run grep -qF -- "${OLD_URL}" "${GITEA_GUIDE}"
  [ "${status}" -ne 0 ]
  run grep -qF -- 'HarisfazillahJamel' "${GITEA_GUIDE}"
  [ "${status}" -ne 0 ]
}

@test "GITEA_GUIDE.md no longer navigates into the old podman-elastic-stack directory (without the -ai suffix)" {
  run grep -qx -- 'cd podman-elastic-stack' "${GITEA_GUIDE}"
  [ "${status}" -ne 0 ]
}

@test "GITEA_GUIDE.md's clone command and cd command reference the same repository name" {
  local clone_line cd_dir repo_name
  clone_line="$(grep -F -- 'git clone https://github.com/' "${GITEA_GUIDE}" | head -1)"
  cd_dir="$(grep -x -- 'cd [a-zA-Z0-9_-]*' "${GITEA_GUIDE}" | head -1 | sed -E 's/^cd //')"
  repo_name="$(echo "${clone_line}" | sed -E 's#.*/([^/]+)\.git$#\1#')"
  [ "${repo_name}" = "podman-elastic-stack-ai" ]
  [ "${cd_dir}" = "podman-elastic-stack-ai" ]
}

# ------------------------------------------------------------------------
# docs/INSTALL.md
# ------------------------------------------------------------------------

@test "INSTALL.md exists and is readable" {
  [ -f "${INSTALL}" ]
  [ -r "${INSTALL}" ]
}

@test "INSTALL.md's Git Repository link points at the active linuxmalaysia/podman-elastic-stack-ai repository" {
  grep -qF -- "[${NEW_URL}](${NEW_URL})" "${INSTALL}"
}

@test "INSTALL.md's git clone command uses the active linuxmalaysia/podman-elastic-stack-ai repository" {
  grep -qF -- "git clone ${NEW_URL}" "${INSTALL}"
}

@test "INSTALL.md documents that cloning creates a directory named podman-elastic-stack-ai" {
  grep -qF -- 'This will create a directory named `podman-elastic-stack-ai` in your current directory and download the repository files into it.' "${INSTALL}"
}

@test "INSTALL.md navigates into the podman-elastic-stack-ai directory after cloning" {
  grep -qx -- 'cd podman-elastic-stack-ai' "${INSTALL}"
}

@test "INSTALL.md no longer references the old HarisfazillahJamel repository URL anywhere" {
  run grep -qF -- 'HarisfazillahJamel' "${INSTALL}"
  [ "${status}" -ne 0 ]
}

@test "INSTALL.md no longer offers the redundant 'podman for AI testing' alternate clone block" {
  # Regression guard: INSTALL.md previously documented two separate clone
  # URLs (the main repo, and a second "for podman for AI testing" variant
  # pointing at linuxmalaysia/podman-elastic-stack.git without the -ai
  # suffix). That second, now-redundant block was removed entirely.
  run grep -qF -- 'or for podman for AI testing' "${INSTALL}"
  [ "${status}" -ne 0 ]
  run grep -qF -- "git clone ${OLD_AI_TESTING_URL}" "${INSTALL}"
  [ "${status}" -ne 0 ]
}

@test "INSTALL.md no longer navigates into the old podman-elastic-stack directory (without the -ai suffix)" {
  run grep -qx -- 'cd podman-elastic-stack' "${INSTALL}"
  [ "${status}" -ne 0 ]
}

@test "INSTALL.md's Git Repository section documents the clone URL exactly twice (link reference and clone command)" {
  local count
  count="$(grep -cF -- "${NEW_URL}" "${INSTALL}")"
  [ "${count}" -eq 2 ]
}

@test "INSTALL.md documents only a single git clone command for the Elasticsearch/Kibana scripts repository" {
  local count
  count="$(grep -cE -- '^ *git clone https://github.com/' "${INSTALL}")"
  [ "${count}" -eq 1 ]
}

@test "INSTALL.md's Git Repository section retains its numbered clone walkthrough steps" {
  grep -qF -- '**Open a terminal:**' "${INSTALL}"
  grep -qF -- '**Create a directory (optional):**' "${INSTALL}"
  grep -qF -- '**Clone the repository:**' "${INSTALL}"
  grep -qF -- '**Navigate to the repository:**' "${INSTALL}"
}

# ------------------------------------------------------------------------
# Cross-file consistency
# ------------------------------------------------------------------------

@test "GITEA_GUIDE.md and INSTALL.md agree on the canonical repository clone URL" {
  grep -qF -- "${NEW_URL}" "${GITEA_GUIDE}"
  grep -qF -- "${NEW_URL}" "${INSTALL}"
}

@test "neither GITEA_GUIDE.md nor INSTALL.md contain a malformed or unrelated clone URL" {
  run grep -qF -- 'git clone https://github.com/some-other-org/unrelated-repo.git' "${GITEA_GUIDE}"
  [ "${status}" -ne 0 ]
  run grep -qF -- 'git clone https://github.com/some-other-org/unrelated-repo.git' "${INSTALL}"
  [ "${status}" -ne 0 ]
}