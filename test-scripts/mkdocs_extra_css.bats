#!/usr/bin/env bats
#
# Regression tests for docs/stylesheets/extra.css, the custom MkDocs Material
# design system (glassmorphism header, light/dark color tokens, high-contrast
# hyperlinks, and the 3-button theme mode toggle) introduced alongside
# docs/javascripts/extra.js.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
EXTRA_CSS="${REPO_ROOT}/docs/stylesheets/extra.css"

@test "docs/stylesheets/extra.css exists and is readable" {
  [ -f "${EXTRA_CSS}" ]
  [ -r "${EXTRA_CSS}" ]
}

@test "extra.css defines light-theme design tokens on :root" {
  grep -qF ':root {' "${EXTRA_CSS}"
  grep -qF '--lab-bg: #f8f9fa;' "${EXTRA_CSS}"
  grep -qF '--lab-purple: #8e44ad;' "${EXTRA_CSS}"
}

@test "extra.css overrides dark-theme design tokens under the slate color scheme selector" {
  grep -qF '[data-md-color-scheme="slate"] {' "${EXTRA_CSS}"
  grep -qF '--lab-bg: #0f172a;' "${EXTRA_CSS}"
  grep -qF '--lab-purple: #a855f7;' "${EXTRA_CSS}"
}

@test "extra.css sets distinct high-contrast link colors for light and dark schemes" {
  grep -qF '[data-md-color-scheme="slate"] .md-typeset a,' "${EXTRA_CSS}"
  grep -qF '[data-md-color-scheme="default"] .md-typeset a,' "${EXTRA_CSS}"
  grep -qF 'color: #38bdf8 !important;' "${EXTRA_CSS}"
  grep -qF 'color: #6d28d9 !important;' "${EXTRA_CSS}"
}

@test "extra.css applies a glassmorphism blur effect to the header" {
  grep -qF '.md-header {' "${EXTRA_CSS}"
  grep -qF 'backdrop-filter: blur(var(--lab-blur));' "${EXTRA_CSS}"
}

@test "extra.css defines styles for the 3-button theme mode toggle control" {
  grep -qF '.theme-mode-toggle-container {' "${EXTRA_CSS}"
  grep -qF '.theme-mode-segmented-control {' "${EXTRA_CSS}"
  grep -qF '.theme-mode-btn {' "${EXTRA_CSS}"
  grep -qF '.theme-mode-btn.active {' "${EXTRA_CSS}"
}

@test "extra.css customizes scrollbar and selection colors with the purple accent" {
  grep -qF '::-webkit-scrollbar-thumb {' "${EXTRA_CSS}"
  grep -qF '::selection {' "${EXTRA_CSS}"
}

@test "extra.css has balanced curly braces (basic syntactic sanity check)" {
  local open_count close_count
  open_count="$(grep -o '{' "${EXTRA_CSS}" | wc -l)"
  close_count="$(grep -o '}' "${EXTRA_CSS}" | wc -l)"
  [ "${open_count}" -eq "${close_count}" ]
  [ "${open_count}" -gt 0 ]
}

@test "extra.css font-family variables use Inter for text and a monospace stack for code" {
  grep -qF '--md-text-font: "Inter", system-ui, -apple-system, sans-serif !important;' "${EXTRA_CSS}"
  grep -qF '--md-code-font: "SF Mono", "Cascadia Code", "Fira Code", monospace !important;' "${EXTRA_CSS}"
}