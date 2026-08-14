#!/usr/bin/env python3
"""
Python Script to parse llms.txt, compile llms-full.txt from markdown sources,
and generate a structured XML context file (llms_context.xml).
"""
import os
import re
import xml.etree.ElementTree as ET
from xml.dom import minidom

def parse_llms_txt(file_path):
    """
    Parses llms.txt following the llmstxt.org specification.
    Extracts the document sections, URLs, and descriptions.
    """
    if not os.path.exists(file_path):
        print(f"Error: {file_path} not found.")
        return []

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Regex to find links: [Title](URL): Description
    pattern = r"-\s*\[([^\]]+)\]\(([^)]+)\):\s*([^\n]+)"
    matches = re.findall(pattern, content)

    documents = []
    for title, url, desc in matches:
        documents.append({
            "title": title.strip(),
            "url": url.strip(),
            "description": desc.strip()
        })
    return documents

def generate_llms_full(documents, output_path="llms-full.txt"):
    """
    Aggregates full markdown contents of all linked documentation files
    into a single full-length context file.
    """
    full_content = "# Full Project Documentation Context\n\n"
    full_content += "This file contains a unified compilation of all system documentation resources.\n\n"

    for doc in documents:
        # Resolve path locally from the url (e.g. docs/INSTALL.md)
        local_path = doc["url"]
        if local_path.startswith("http://") or local_path.startswith("https://"):
            # skip remote URLs
            continue

        full_content += f"\n--- \n"
        full_content += f"## Document: {doc['title']}\n"
        full_content += f"Path: {local_path}\n"
        full_content += f"Description: {doc['description']}\n\n"

        if os.path.exists(local_path):
            with open(local_path, "r", encoding="utf-8") as f:
                full_content += f.read()
        else:
            full_content += f"*(Error: Content of {local_path} could not be resolved locally)*"
        full_content += "\n"

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(full_content)
    print(f"Unified context compiled successfully to {output_path}")

def generate_xml_context(documents, output_path="llms_context.xml"):
    """
    Builds a highly structured XML representation of the documentation index
    to optimize contextual intake for LLMs and AI pipelines.
    """
    root = ET.Element("documentation_index")
    root.set("project", "podman-elastic-stack-ai")

    for doc in documents:
        doc_elem = ET.SubElement(root, "document")
        title_elem = ET.SubElement(doc_elem, "title")
        title_elem.text = doc["title"]

        url_elem = ET.SubElement(doc_elem, "url")
        url_elem.text = doc["url"]

        desc_elem = ET.SubElement(doc_elem, "description")
        desc_elem.text = doc["description"]

        # If it exists locally, inject the raw content into the XML tree
        local_path = doc["url"]
        if not (local_path.startswith("http://") or local_path.startswith("https://")) and os.path.exists(local_path):
            with open(local_path, "r", encoding="utf-8") as f:
                content_elem = ET.SubElement(doc_elem, "raw_content")
                content_elem.text = f.read()

    # Pretty print XML
    xml_str = ET.tostring(root, encoding="utf-8")
    parsed_xml = minidom.parseString(xml_str)
    pretty_xml = parsed_xml.toprettyxml(indent="  ")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(pretty_xml)
    print(f"Structured XML context file compiled successfully to {output_path}")

if __name__ == "__main__":
    docs = parse_llms_txt("llms.txt")
    print(f"Parsed {len(docs)} document links from llms.txt.")
    generate_llms_full(docs)
    generate_xml_context(docs)
