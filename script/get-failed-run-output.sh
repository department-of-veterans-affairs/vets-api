#!/bin/bash

# Function to display help text
show_help() {
    echo "Usage: $0 <url>"
    echo
    echo "Extracts the run id from the provided url and retrieves the log of a failed GitHub Actions run."
    echo
    echo "Arguments:"
    echo "  GHWR_URL    The URL of the GitHub Actions run."
    echo
    echo "Example:"
    echo "  $0 https://github.com/department-of-veterans-affairs/vets-api/runs/123456789/job/98765"
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Error: Invalid number of arguments."
    show_help
    exit 1
fi

GHWR_URL=$1

# Check if the GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/ and try again."
    exit 1
fi

# Validate the URL format
if ! [[ "$GHWR_URL" =~ ^https://github\.com/.*/runs/[0-9]+/?(job/[0-9]+)?$ ]]; then
    echo "Error: Invalid URL format. Please provide a URL in the format: https://github.com/owner/repo/runs/123456789 or https://github.com/owner/repo/runs/123456789/job/1234"
    exit 1
fi

# Extract GHWR_ID from the provided URL
GHWR_ID=$(echo "$GHWR_URL" | awk -F'runs/' '{if ($2) {split($2, a, /[^0-9]/); print a[1]}}')

# Check if GHWR_ID was successfully extracted
if [ -z "$GHWR_ID" ]; then
    echo "Error: Unable to extract GHWR_ID from the provided URL."
    exit 1
fi

# Retrieve and filter the log of the failed GitHub Actions run
gh run view -R department-of-veterans-affairs/vets-api --log-failed "$GHWR_ID" | grep -A2 -E "rspec [']?\./"
