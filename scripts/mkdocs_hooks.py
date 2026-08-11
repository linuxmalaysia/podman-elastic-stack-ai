"""
MkDocs Custom Hook for Link Rewriting.

Dynamically strips 'docs/' prefixes and adjusts relative link paths during MkDocs page
compilation to ensure smooth navigation across both GitHub web view and MkDocs HTML builds.
"""
import re
import os
from posixpath import normpath, relpath, dirname, join

def on_page_markdown(markdown, page, config, files):
    """
    Rewrite relative Markdown links for MkDocs-compatible paths.

    Parameters:
        markdown (str): Markdown content whose links should be rewritten.
        page: MkDocs page associated with the content.
        config: MkDocs configuration.
        files: MkDocs file collection.

    Returns:
        str: Markdown content with applicable relative links rewritten.
    """
    # Remove code blocks and inline code to avoid rewriting links inside them
    code_blocks = []
    inline_codes = []

    # Extract fenced code blocks (``` ... ```)
    def preserve_fenced_code(match):
        code_blocks.append(match.group(0))
        return f"<<<CODEBLOCK_{len(code_blocks) - 1}>>>"

    markdown_no_fenced = re.sub(r'```[\s\S]*?```', preserve_fenced_code, markdown)

    # Extract inline code spans (` ... `)
    def preserve_inline_code(match):
        inline_codes.append(match.group(0))
        return f"<<<INLINECODE_{len(inline_codes) - 1}>>>"

    markdown_no_code = re.sub(r'`[^`\n]+?`', preserve_inline_code, markdown_no_fenced)

    def replace_link(match):
        """
        Rewrite a Markdown link URL for MkDocs compilation.

        Parameters:
            match: A regular expression match containing the link text and URL.

        Returns:
            str: The link with proper relative path resolution based on page location.
        """
        text = match.group(1)
        url = match.group(2)

        # Keep external or anchor-only links intact
        if url.startswith(('http://', 'https://', 'mailto:', 'ftp:', '#')):
            return match.group(0)

        new_url = url

        # Split URL from any anchor/fragment
        anchor = ""
        if "#" in new_url:
            new_url, anchor = new_url.split("#", 1)
            anchor = "#" + anchor

        # If the link starts with 'docs/', strip it
        if new_url.startswith('docs/'):
            new_url = new_url[5:]
        # For relative links (../ or ../../), compute proper relative path
        elif new_url.startswith('../'):
            # Get current page's directory (source path in docs)
            current_dir = dirname(page.file.src_uri)

            # Resolve the target path from current page location
            target_path = normpath(join(current_dir, new_url))

            # Compute relative path from current page to target
            new_url = relpath(target_path, current_dir)

        return f"[{text}]({new_url}{anchor})"

    # Match markdown links: [text](url) - only in non-code content
    markdown_rewritten = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', replace_link, markdown_no_code)

    # Restore inline code spans
    for i, code in enumerate(inline_codes):
        markdown_rewritten = markdown_rewritten.replace(f"<<<INLINECODE_{i}>>>", code)

    # Restore fenced code blocks
    for i, block in enumerate(code_blocks):
        markdown_rewritten = markdown_rewritten.replace(f"<<<CODEBLOCK_{i}>>>", block)

    return markdown_rewritten
