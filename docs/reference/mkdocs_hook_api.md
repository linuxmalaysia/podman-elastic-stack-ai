---
title: "MkDocs Rewriter Hook API"
description: "Reference specification of the custom python-based URI-rewriting Hook."
nav_order: 13
---

# MkDocs Rewriter Hook API

This document lists the technical signatures, helper routines, and regex behaviors of the custom link-rewriting build hook defined in `scripts/mkdocs_hooks.py`.

---

## 🛠️ Hook Routines

### 1. `resolve_relative_url(url, page, config)`
* **Signature**:
  ```python
  def resolve_relative_url(url, page, config):
  ```
* **Arguments**:
  - `url` (`str`): The raw link read from the Markdown file.
  - `page` (`mkdocs.structure.pages.Page` or `None`): The MkDocs metadata page model representing the active file being compiled.
  - `config` (`dict` or `None`): The master configuration dictionary loaded from `mkdocs.yml`.
* **Behavior Details**:
  - Skips rewriting any links starting with `#`, `//`, or matched by `^[a-zA-Z][a-zA-Z0-9+.-]*:` (e.g. `https:`, `mailto:`, `ftp:`).
  - Strips leading `docs/` paths and translates them relative to the active document compile depth.
  - Resolves links pointing outside the `docs/` workspace to absolute GitHub links when `repo_url` is configured.

### 2. `on_page_markdown(markdown, page, config, files)`
* **Signature**:
  ```python
  def on_page_markdown(markdown, page, config, files):
  ```
* **Regex Pattern**:
  ```python
  pattern = r'(```[\s\S]*?```)|(`[^`]*?`)|(\[([^\]]+)\]\(([^)]+)\))'
  ```
  - Isolates code-blocks and inline literals first to prevent accidental rewriting of markdown syntax stored in code examples.
