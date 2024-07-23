#!/bin/bash

set -e

# Fetch the latest information from the remote repository
git fetch origin master

# Get the SHA of the latest commit on the current branch
HEAD_SHA=$(git rev-parse HEAD)

# Use the latest commit from the origin/master as the base SHA
BASE_SHA=$(git rev-parse origin/master)

# Get the list of changed files between the base and head commits
IFS=$'\n'  # Change IFS to split only on newlines
CHANGED_FILES=$(git diff --name-only --diff-filter=AMR ${BASE_SHA}...${HEAD_SHA})
echo "Changed files: $CHANGED_FILES"

check_in_codeowners() {
    local file="$1"
    while [[ "$file" != '.' && "$file" != '/' ]]; do
        echo "Checking CODEOWNERS for: $file"
        # Check for exact match or trailing slash
        if grep -qE "^\s*${file}(/)?(\s|\$)" .github/CODEOWNERS; then
            echo "Found in CODEOWNERS: $file"
            return 0
        fi
        # Check for wildcard match
        if grep -qE "^\s*${file}/\*(\s|\$)" .github/CODEOWNERS; then
            echo "Found in CODEOWNERS as wildcard: ${file}/*"
            return 0
        fi
        # Move to the parent directory
        echo "PARENT DIR: Checking CODEOWNERS for: $file"
        file=$(dirname "$file")
    done
    echo "Not found in CODEOWNERS: $file"
    return 1
}

for FILE in ${CHANGED_FILES}; do
  # Ignore files starting with a dot
  if [[ $FILE == .* ]]; then
    echo "Ignoring file $FILE"
    continue
  fi

  echo "Checking file: $FILE"
  if ! check_in_codeowners "$FILE"; then
    echo "Error: $FILE (or its parent directories) does not have a CODEOWNERS entry."
    echo "offending_file=$FILE" >> $GITHUB_ENV
    exit 1
  fi
done

echo "All changed files or their parent directories have a CODEOWNERS entry."
IFS=$' \t\n'  # Reset IFS after the loop
