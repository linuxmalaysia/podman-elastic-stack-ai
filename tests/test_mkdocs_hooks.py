#!/usr/bin/env python3
"""
Unit tests for scripts/mkdocs_hooks.py, specifically the on_page_markdown()
MkDocs hook that rewrites relative Markdown links (stripping a leading
'docs/' prefix and collapsing one leading '../../' level to '../') while
leaving external, mailto:, ftp:, and anchor-only links untouched.
"""
import importlib.util
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HOOK_PATH = REPO_ROOT / "scripts" / "mkdocs_hooks.py"


def _load_hooks_module():
    spec = importlib.util.spec_from_file_location("mkdocs_hooks", HOOK_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


mkdocs_hooks = _load_hooks_module()


class OnPageMarkdownTests(unittest.TestCase):
    """Tests for mkdocs_hooks.on_page_markdown()."""

    def call(self, markdown):
        # page/config/files are unused by the hook implementation; pass None
        # to confirm the function does not depend on them.
        return mkdocs_hooks.on_page_markdown(markdown, None, None, None)

    def test_strips_leading_docs_prefix(self):
        result = self.call("[Install](docs/INSTALL.md)")
        self.assertEqual(result, "[Install](INSTALL.md)")

    def test_strips_docs_prefix_with_nested_path(self):
        result = self.call("[Guide](docs/guides/setup.md)")
        self.assertEqual(result, "[Guide](guides/setup.md)")

    def test_collapses_one_level_of_parent_parent_prefix(self):
        result = self.call("[Readme](../../README.md)")
        self.assertEqual(result, "[Readme](../README.md)")

    def test_collapses_only_the_first_parent_parent_level_when_nested_deeper(self):
        # '../../../file.md' should only have the first '../../' segment
        # collapsed to '../', leaving one remaining '../' level intact.
        result = self.call("[Deep](../../../file.md)")
        self.assertEqual(result, "[Deep](../../file.md)")

    def test_single_parent_prefix_is_left_untouched(self):
        # A single '../' (not '../../') does not match the elif branch and
        # must be returned unchanged.
        result = self.call("[Sibling](../file.md)")
        self.assertEqual(result, "[Sibling](../file.md)")

    def test_http_links_are_untouched(self):
        result = self.call("[External](http://example.com/docs/page)")
        self.assertEqual(result, "[External](http://example.com/docs/page)")

    def test_https_links_are_untouched(self):
        result = self.call("[External](https://example.com/docs/page)")
        self.assertEqual(result, "[External](https://example.com/docs/page)")

    def test_mailto_links_are_untouched(self):
        result = self.call("[Email](mailto:someone@example.com)")
        self.assertEqual(result, "[Email](mailto:someone@example.com)")

    def test_ftp_links_are_untouched(self):
        result = self.call("[FTP](ftp://example.com/docs/file)")
        self.assertEqual(result, "[FTP](ftp://example.com/docs/file)")

    def test_anchor_only_links_are_untouched(self):
        result = self.call("[Section](#installation)")
        self.assertEqual(result, "[Section](#installation)")

    def test_plain_relative_link_without_special_prefix_is_unchanged(self):
        result = self.call("[Other](other.md)")
        self.assertEqual(result, "[Other](other.md)")

    def test_docs_prefixed_link_with_trailing_anchor_still_stripped(self):
        # Only anchor-only links (starting with '#') are exempted; a
        # docs/-prefixed link combined with a fragment should still be
        # rewritten.
        result = self.call("[Section](docs/INSTALL.md#requirements)")
        self.assertEqual(result, "[Section](INSTALL.md#requirements)")

    def test_multiple_links_in_one_document_are_each_rewritten(self):
        markdown = (
            "See [Install](docs/INSTALL.md) and [Home](../../README.md) "
            "and [External](https://example.com) and [Anchor](#top)."
        )
        expected = (
            "See [Install](INSTALL.md) and [Home](../README.md) "
            "and [External](https://example.com) and [Anchor](#top)."
        )
        self.assertEqual(self.call(markdown), expected)

    def test_empty_markdown_returns_empty_string(self):
        self.assertEqual(self.call(""), "")

    def test_markdown_without_links_is_returned_unchanged(self):
        markdown = "# Title\n\nJust a paragraph with no links at all."
        self.assertEqual(self.call(markdown), markdown)

    def test_link_text_is_preserved_verbatim(self):
        result = self.call("[Read the Fine Manual!](docs/PLAYBOOKS.md)")
        self.assertEqual(result, "[Read the Fine Manual!](PLAYBOOKS.md)")

    def test_return_type_is_str(self):
        result = self.call("[Install](docs/INSTALL.md)")
        self.assertIsInstance(result, str)

    def test_url_starting_with_hash_but_containing_docs_substring_is_untouched(self):
        # Guard against overly-eager prefix matching: an anchor link must be
        # returned unchanged even if 'docs/' appears later in the fragment.
        result = self.call("[Jump](#docs/section)")
        self.assertEqual(result, "[Jump](#docs/section)")


if __name__ == "__main__":
    unittest.main()