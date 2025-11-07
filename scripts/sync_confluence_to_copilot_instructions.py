#!/usr/bin/env python3
"""
Sync Confluence Backend Developer Documentation to GitHub Copilot Instructions

This script exports Backend Developer Documentation from Confluence and converts it
to GitHub Copilot custom instructions format (.github/copilot-instructions.md).

Requirements:
    pip install confluence-markdown-exporter requests

Usage:
    python scripts/sync_confluence_to_copilot_instructions.py

Environment Variables:
    CONFLUENCE_URL: Your Confluence instance URL (e.g., https://vfs.atlassian.net)
    CONFLUENCE_EMAIL: Your Confluence user email
    CONFLUENCE_API_TOKEN: Confluence API token (generate at: https://id.atlassian.com/manage-profile/security/api-tokens)
    CONFLUENCE_SPACE_KEY: Confluence space key to export (e.g., "PLATFORM")
"""

import os
import sys
import re
import subprocess
import tempfile
from pathlib import Path
from typing import List, Tuple

# Configuration
CONFLUENCE_URL = os.getenv('CONFLUENCE_URL', 'https://vfs.atlassian.net')
CONFLUENCE_EMAIL = os.getenv('CONFLUENCE_EMAIL')
CONFLUENCE_API_TOKEN = os.getenv('CONFLUENCE_API_TOKEN')
CONFLUENCE_SPACE_KEY = os.getenv('CONFLUENCE_SPACE_KEY', 'pilot')

# Target pages to export (customize based on your Confluence structure)
TARGET_PAGES = [
    'Backend Developer Documentation',
    'Best Practices',
    'Error Handling Standards',
    'Service Object Guidelines',
    'Testing Requirements',
    'API Endpoint Standards',
    'Security Guidelines'
]

# Output configuration
OUTPUT_FILE = '.github/copilot-instructions.md'
MAX_FILE_SIZE_KB = 100  # GitHub Copilot custom instructions file size limit (approximate)


def check_prerequisites():
    """Check that required tools and environment variables are set."""
    print("Checking prerequisites...")

    # Check environment variables
    if not CONFLUENCE_EMAIL or not CONFLUENCE_API_TOKEN:
        print("ERROR: Missing required environment variables:")
        print("  CONFLUENCE_EMAIL: Your Confluence user email")
        print("  CONFLUENCE_API_TOKEN: Confluence API token")
        print("\nGenerate an API token at: https://id.atlassian.com/manage-profile/security/api-tokens")
        sys.exit(1)

    # Check if confluence-markdown-exporter is installed
    try:
        result = subprocess.run(
            ['cf-export', '--version'],
            capture_output=True,
            text=True
        )
        print(f"✓ confluence-markdown-exporter installed")
    except FileNotFoundError:
        print("ERROR: confluence-markdown-exporter not installed")
        print("Install with: pip install confluence-markdown-exporter")
        sys.exit(1)

    print("✓ All prerequisites met\n")


def configure_confluence_exporter(config_dir: Path):
    """Configure the Confluence exporter with credentials."""
    print("Configuring Confluence exporter...")

    # Create config file for confluence-markdown-exporter
    config = {
        "confluence_url": CONFLUENCE_URL,
        "confluence_email": CONFLUENCE_EMAIL,
        "confluence_api_token": CONFLUENCE_API_TOKEN,
        "output_dir": str(config_dir)
    }

    # Run configuration (this will be stored by the tool)
    env = os.environ.copy()
    env['CONFLUENCE_URL'] = CONFLUENCE_URL
    env['CONFLUENCE_USERNAME'] = CONFLUENCE_EMAIL
    env['CONFLUENCE_API_TOKEN'] = CONFLUENCE_API_TOKEN

    print(f"✓ Configured for {CONFLUENCE_URL}\n")
    return env


def export_confluence_space(export_dir: Path, env: dict) -> List[Path]:
    """Export Confluence space to markdown files."""
    print(f"Exporting Confluence space: {CONFLUENCE_SPACE_KEY}...")

    try:
        # Export entire space
        # Note: You may need to adjust command based on actual tool usage
        result = subprocess.run(
            [
                'cf-export',
                '--url', CONFLUENCE_URL,
                '--username', CONFLUENCE_EMAIL,
                '--token', CONFLUENCE_API_TOKEN,
                '--space', CONFLUENCE_SPACE_KEY,
                '--output', str(export_dir)
            ],
            capture_output=True,
            text=True,
            env=env,
            timeout=300  # 5 minute timeout
        )

        if result.returncode != 0:
            print(f"ERROR: Export failed: {result.stderr}")
            sys.exit(1)

        print(f"✓ Export completed\n")

        # Find all exported markdown files
        markdown_files = list(export_dir.rglob('*.md'))
        print(f"Found {len(markdown_files)} markdown files")

        return markdown_files

    except subprocess.TimeoutExpired:
        print("ERROR: Export timed out after 5 minutes")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Export failed: {e}")
        sys.exit(1)


def filter_relevant_pages(markdown_files: List[Path], target_pages: List[str]) -> List[Tuple[Path, str]]:
    """Filter and prioritize markdown files based on target pages."""
    print("Filtering relevant documentation...")

    relevant_files = []

    for md_file in markdown_files:
        # Read file content
        content = md_file.read_text(encoding='utf-8')

        # Check if this file matches any target page
        for target in target_pages:
            if target.lower() in md_file.name.lower() or target.lower() in content.lower():
                relevant_files.append((md_file, content))
                print(f"  ✓ {md_file.name}")
                break

    print(f"\n✓ Selected {len(relevant_files)} relevant pages\n")
    return relevant_files


def convert_to_copilot_instructions(relevant_files: List[Tuple[Path, str]]) -> str:
    """Convert Confluence markdown to Copilot instructions format."""
    print("Converting to Copilot instructions format...")

    instructions = []

    # Add section header for Platform Documentation
    instructions.append("---")
    instructions.append("")
    instructions.append("## Platform Documentation (Auto-synced from Confluence)")
    instructions.append("")
    instructions.append(f"**Last synced**: {subprocess.run(['date'], capture_output=True, text=True).stdout.strip()}")
    instructions.append("")
    instructions.append("The following standards are automatically synced from Backend Developer Documentation in Confluence.")
    instructions.append("")

    # Process each relevant file
    for md_file, content in relevant_files:
        # Clean up Confluence-specific syntax
        cleaned_content = clean_confluence_markdown(content)

        # Add subsection
        instructions.append(f"### {md_file.stem}")
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

    # Simplify complex tables (Copilot works better with simpler format)
    # This is basic - may need more sophisticated table handling

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

    # Create temporary directory for export
    with tempfile.TemporaryDirectory() as temp_dir:
        export_dir = Path(temp_dir) / 'confluence-export'
        export_dir.mkdir(parents=True, exist_ok=True)

        # Configure exporter
        env = configure_confluence_exporter(export_dir)

        # Export Confluence space
        markdown_files = export_confluence_space(export_dir, env)

        # Filter relevant pages
        relevant_files = filter_relevant_pages(markdown_files, TARGET_PAGES)

        if not relevant_files:
            print("ERROR: No relevant pages found")
            print(f"Check that space key '{CONFLUENCE_SPACE_KEY}' is correct")
            print(f"and that target pages exist: {TARGET_PAGES}")
            sys.exit(1)

        # Convert to Copilot instructions format
        instructions_content = convert_to_copilot_instructions(relevant_files)

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
