#!/usr/bin/env python3
"""
Sync Confluence Backend Developer Documentation to GitHub Copilot Instructions

This script exports Backend Developer Documentation from Confluence and converts it
to GitHub Copilot custom instructions format (.github/copilot-instructions.md).

Requirements:
    pip install atlassian-python-api requests markdownify

Usage:
    python scripts/sync_confluence_to_copilot_instructions.py

Environment Variables:
    CONFLUENCE_URL: Your Confluence instance URL (e.g., https://vfs.atlassian.net)
    CONFLUENCE_EMAIL: Your Confluence user email
    CONFLUENCE_API_TOKEN: Confluence API token (generate at: https://id.atlassian.com/manage-profile/security/api-tokens)
    CONFLUENCE_SPACE_KEY: Confluence space key to export (e.g., "pilot")
"""

import os
import sys
import re
from pathlib import Path
from typing import List, Tuple, Dict, Any

try:
    from atlassian import Confluence
    from markdownify import markdownify as md
except ImportError:
    print("ERROR: Required packages not installed")
    print("Install with: pip install atlassian-python-api markdownify")
    sys.exit(1)

# Configuration
CONFLUENCE_URL = os.getenv('CONFLUENCE_URL', 'https://vfs.atlassian.net')
CONFLUENCE_EMAIL = os.getenv('CONFLUENCE_EMAIL')
CONFLUENCE_API_TOKEN = os.getenv('CONFLUENCE_API_TOKEN')
CONFLUENCE_SPACE_KEY = os.getenv('CONFLUENCE_SPACE_KEY', 'pilot')

# Target pages to export (customize based on your Confluence structure)
# POC: Only syncing Backend Developer Documentation page
TARGET_PAGES = [
    'Backend Developer Documentation',
]

# Output configuration
OUTPUT_FILE = '.github/copilot-instructions.md'
MAX_FILE_SIZE_KB = 100  # GitHub Copilot custom instructions file size limit (approximate)


def check_prerequisites():
    """Check that required environment variables are set."""
    print("Checking prerequisites...")

    if not CONFLUENCE_EMAIL or not CONFLUENCE_API_TOKEN:
        print("ERROR: Missing required environment variables:")
        print("  CONFLUENCE_EMAIL: Your Confluence user email")
        print("  CONFLUENCE_API_TOKEN: Confluence API token")
        print("\nGenerate an API token at: https://id.atlassian.com/manage-profile/security/api-tokens")
        sys.exit(1)

    print("✓ All prerequisites met\n")


def connect_to_confluence() -> Confluence:
    """Create and return Confluence API connection."""
    print(f"Connecting to Confluence: {CONFLUENCE_URL}...")

    try:
        confluence = Confluence(
            url=CONFLUENCE_URL,
            username=CONFLUENCE_EMAIL,
            password=CONFLUENCE_API_TOKEN,
            cloud=True
        )

        # Test the connection
        confluence.get_space(CONFLUENCE_SPACE_KEY)
        print(f"✓ Connected to space: {CONFLUENCE_SPACE_KEY}\n")

        return confluence

    except Exception as e:
        print(f"ERROR: Failed to connect to Confluence: {e}")
        print(f"\nCheck that:")
        print(f"  - URL is correct: {CONFLUENCE_URL}")
        print(f"  - Space key exists: {CONFLUENCE_SPACE_KEY}")
        print(f"  - Credentials are valid")
        sys.exit(1)


def find_pages_in_space(confluence: Confluence, target_titles: List[str]) -> List[Dict[str, Any]]:
    """Find target pages in the Confluence space."""
    print(f"Searching for pages in space '{CONFLUENCE_SPACE_KEY}'...")

    found_pages = []

    try:
        # Get all pages in the space
        start = 0
        limit = 100
        all_pages = []

        while True:
            pages = confluence.get_all_pages_from_space(
                CONFLUENCE_SPACE_KEY,
                start=start,
                limit=limit,
                expand='version'
            )

            if not pages:
                break

            all_pages.extend(pages)
            start += limit

            if len(pages) < limit:
                break

        print(f"Found {len(all_pages)} total pages in space")

        # Filter for target pages
        for page in all_pages:
            page_title = page.get('title', '')
            for target in target_titles:
                if target.lower() in page_title.lower():
                    found_pages.append(page)
                    print(f"  ✓ Found: {page_title}")
                    break

        print(f"\n✓ Selected {len(found_pages)} relevant pages\n")
        return found_pages

    except Exception as e:
        print(f"ERROR: Failed to search pages: {e}")
        sys.exit(1)


def get_page_content(confluence: Confluence, page_id: str) -> Tuple[str, str]:
    """Get page content and convert to markdown."""
    try:
        page = confluence.get_page_by_id(
            page_id,
            expand='body.storage,version'
        )

        title = page['title']
        html_content = page['body']['storage']['value']

        # Convert HTML to Markdown
        markdown_content = md(html_content, heading_style="ATX")

        return title, markdown_content

    except Exception as e:
        print(f"ERROR: Failed to get page content for ID {page_id}: {e}")
        return "", ""


def export_pages_to_markdown(confluence: Confluence, pages: List[Dict[str, Any]]) -> List[Tuple[str, str]]:
    """Export pages to markdown format."""
    print("Exporting pages to markdown...")

    markdown_pages = []

    for page in pages:
        page_id = page['id']
        page_title = page['title']

        print(f"  Exporting: {page_title}...", end=" ")

        title, content = get_page_content(confluence, page_id)

        if content:
            markdown_pages.append((title, content))
            print("✓")
        else:
            print("✗ (failed)")

    print(f"\n✓ Exported {len(markdown_pages)} pages\n")
    return markdown_pages


def convert_to_copilot_instructions(markdown_pages: List[Tuple[str, str]]) -> str:
    """Convert Confluence markdown to Copilot instructions format."""
    print("Converting to Copilot instructions format...")

    instructions = []

    # Add section header for Platform Documentation
    instructions.append("---")
    instructions.append("")
    instructions.append("## Platform Documentation (Auto-synced from Confluence)")
    instructions.append("")

    from datetime import datetime
    instructions.append(f"**Last synced**: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}")
    instructions.append("")
    instructions.append("The following standards are automatically synced from Backend Developer Documentation in Confluence.")
    instructions.append("")

    # Process each page
    for title, content in markdown_pages:
        # Clean up Confluence-specific syntax
        cleaned_content = clean_confluence_markdown(content)

        # Add subsection
        instructions.append(f"### {title}")
        instructions.append("")
        instructions.append(cleaned_content)
        instructions.append("")

    # Add footer with link to full docs
    instructions.append(f"**Full Platform Documentation**: {CONFLUENCE_URL}/wiki/spaces/{CONFLUENCE_SPACE_KEY}")
    instructions.append("")
    instructions.append("---")
    instructions.append("")

    full_content = '\n'.join(instructions)

    print(f"✓ Generated {len(full_content)} characters of instructions\n")
    return full_content


def clean_confluence_markdown(content: str) -> str:
    """Clean Confluence-specific markdown syntax."""
    # Remove Confluence metadata
    content = re.sub(r'^---\n.*?\n---\n', '', content, flags=re.DOTALL | re.MULTILINE)

    # Remove Confluence macros that don't translate well
    content = re.sub(r'\{.*?\}', '', content)

    # Clean up excessive whitespace
    content = re.sub(r'\n{3,}', '\n\n', content)

    # Remove HTML comments
    content = re.sub(r'<!--.*?-->', '', content, flags=re.DOTALL)

    return content.strip()


def truncate_if_needed(content: str, max_size_kb: int) -> str:
    """Truncate content if it exceeds size limit."""
    content_size_kb = len(content.encode('utf-8')) / 1024

    if content_size_kb <= max_size_kb:
        print(f"✓ Content size: {content_size_kb:.1f}KB (within {max_size_kb}KB limit)\n")
        return content

    print(f"⚠ Content size: {content_size_kb:.1f}KB exceeds {max_size_kb}KB limit")
    print("Truncating content...")

    # Truncate and add notice
    max_bytes = max_size_kb * 1024
    truncated = content.encode('utf-8')[:max_bytes].decode('utf-8', errors='ignore')

    truncated += "\n\n---\n\n"
    truncated += "**Note**: Content truncated due to size limit. "
    truncated += f"See full documentation: {CONFLUENCE_URL}/wiki/spaces/{CONFLUENCE_SPACE_KEY}"

    print(f"✓ Truncated to {max_size_kb}KB\n")
    return truncated


def read_existing_instructions(output_file: str) -> Tuple[str, str, str]:
    """Read existing copilot instructions and split into sections."""
    output_path = Path(output_file)

    if not output_path.exists():
        print("No existing copilot-instructions.md found, will create new file")
        return "", "", ""

    print("Reading existing copilot-instructions.md...")
    existing_content = output_path.read_text(encoding='utf-8')

    # Find the Platform Documentation section markers
    platform_start_marker = "## Platform Documentation (Auto-synced from Confluence)"

    # Split into before, platform section, and after
    if platform_start_marker in existing_content:
        # Find where platform section starts
        platform_start_idx = existing_content.find("---\n\n" + platform_start_marker)

        if platform_start_idx == -1:
            platform_start_idx = existing_content.find(platform_start_marker)

        before_platform = existing_content[:platform_start_idx].rstrip()

        # Find where platform section ends (next --- or end of file)
        remaining = existing_content[platform_start_idx:]
        # Look for the closing ---
        end_marker_idx = remaining.find("\n---\n\n", len(platform_start_marker))

        if end_marker_idx != -1:
            after_platform = remaining[end_marker_idx + 5:].lstrip()  # +5 to skip "\n---\n\n"
        else:
            after_platform = ""

        print("✓ Found existing Platform Documentation section, will replace it")
        return before_platform, "", after_platform
    else:
        print("✓ No Platform Documentation section found, will append to end")
        return existing_content.rstrip(), "", ""


def write_copilot_instructions(new_platform_content: str, output_file: str):
    """Merge new Platform Documentation content with existing instructions."""
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Merging content into {output_file}...")

    # Read existing content
    before_platform, _, after_platform = read_existing_instructions(output_file)

    # Build final content
    final_parts = []

    # Add existing content before Platform Documentation section
    if before_platform:
        final_parts.append(before_platform)

    # Add new Platform Documentation section
    final_parts.append(new_platform_content)

    # Add any content that was after Platform Documentation section
    if after_platform:
        final_parts.append(after_platform)

    final_content = '\n\n'.join(final_parts)

    # Write merged content
    output_path.write_text(final_content, encoding='utf-8')
    print(f"✓ Written {len(final_content)} characters (merged)\n")


def main():
    """Main sync workflow."""
    print("=" * 60)
    print("Confluence → Copilot Instructions Sync")
    print("=" * 60)
    print()

    # Check prerequisites
    check_prerequisites()

    # Connect to Confluence
    confluence = connect_to_confluence()

    # Find target pages
    pages = find_pages_in_space(confluence, TARGET_PAGES)

    if not pages:
        print("ERROR: No relevant pages found")
        print(f"Check that space key '{CONFLUENCE_SPACE_KEY}' is correct")
        print(f"and that target pages exist: {TARGET_PAGES}")
        sys.exit(1)

    # Export pages to markdown
    markdown_pages = export_pages_to_markdown(confluence, pages)

    if not markdown_pages:
        print("ERROR: Failed to export any pages")
        sys.exit(1)

    # Convert to Copilot instructions format
    instructions_content = convert_to_copilot_instructions(markdown_pages)

    # Truncate if needed
    instructions_content = truncate_if_needed(instructions_content, MAX_FILE_SIZE_KB)

    # Write output file
    write_copilot_instructions(instructions_content, OUTPUT_FILE)

    print("=" * 60)
    print("✅ Sync completed successfully!")
    print("=" * 60)
    print()
    print(f"Next steps:")
    print(f"1. Review the generated file: {OUTPUT_FILE}")
    print(f"2. Commit and push to enable Copilot Code Review")
    print(f"3. Set up automated sync via GitHub Actions")
    print()


if __name__ == '__main__':
    main()
