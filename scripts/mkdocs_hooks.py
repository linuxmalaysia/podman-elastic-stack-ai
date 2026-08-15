"""
MkDocs Custom Hook for Link Rewriting.

Dynamically strips 'docs/' prefixes and adjusts relative link paths during MkDocs page
compilation to ensure smooth navigation across both GitHub web view and MkDocs HTML builds.
"""
import re
import posixpath
import os

def resolve_relative_url(url, page, config):
    """
    Resolve relative URLs to clean paths.
    """
    # Keep external, mailto, or anchor-only links intact
    if url.startswith(('http://', 'https://', 'mailto:', 'ftp:', '#')):
        return url

    # Extract anchor if present
    base_url = url
    anchor = ""
    if '#' in url:
        base_url, anchor = url.split('#', 1)
        anchor = "#" + anchor

    # Safely retrieve the current document directory if page and page.file are populated
    doc_dir = ""
    if page and getattr(page, 'file', None) and getattr(page.file, 'src_uri', None):
        doc_dir = posixpath.dirname(page.file.src_uri)

    # If the link starts with 'docs/', make it relative to the current page's depth
    if base_url.startswith('docs/'):
        target_path = base_url[5:]
        if doc_dir:
            rel = os.path.relpath(target_path, doc_dir).replace('\\', '/')
        else:
            rel = target_path
        return rel + anchor

    if base_url.startswith('../../'):
        return base_url[3:] + anchor

    # Resolve any relative link (e.g. starting with ../ or otherwise) against the current page's repository path
    current_repo_dir = posixpath.join("docs", doc_dir) if doc_dir else "docs"

    # Resolve the target path relative to the repository root
    repo_path = posixpath.normpath(posixpath.join(current_repo_dir, base_url))

    # If the resolved path points inside the docs/ directory, compile it as a relative link in the MkDocs site
    if repo_path.startswith("docs/"):
        target_docs_path = repo_path[5:]
        if doc_dir:
            rel = os.path.relpath(target_docs_path, doc_dir).replace('\\', '/')
        else:
            rel = target_docs_path
        return rel + anchor
    else:
        # If it points outside docs/, resolve it to the GitHub repository if repo_url is available
        repo_url = config.get('repo_url', '') if config else ''
        if repo_url:
            repo_url = repo_url.rstrip('/')
            return f"{repo_url}/blob/main/{repo_path}{anchor}"
        return url

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
    # Pattern to match fenced code blocks, inline code blocks, and markdown links
    pattern = r'(```[\s\S]*?```)|(`[^`]*?`)|(\[([^\]]+)\]\(([^)]+)\))'

    def replace_match(match):
        # If it's a fenced code block, return it unchanged
        if match.group(1):
            return match.group(1)
        # If it's inline code, return it unchanged
        if match.group(2):
            return match.group(2)

        # It's a markdown link
        text = match.group(4)
        url = match.group(5)

        new_url = resolve_relative_url(url, page, config)
        return f"[{text}]({new_url})"

    return re.sub(pattern, replace_match, markdown)
