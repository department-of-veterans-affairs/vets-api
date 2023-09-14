#!/bin/bash

set -e

# Fetch the latest information from the remote repository
git fetch origin master

# Get the SHA of the latest commit on the current branch
HEAD_SHA=$(git rev-parse HEAD)

# Use the latest commit from the origin/master as the base SHA
BASE_SHA=$(git rev-parse origin/master)

# Get the list of changed files between the base and head commits
DELETED_FILES=$(git diff --name-only --diff-filter=D ${BASE_SHA}...${HEAD_SHA})

# Check if a file's or its parent directory's reference is in CODEOWNERS
file_in_codeowners() {
    local file="$1"
    if grep -qE "^\s*${file}(/)?(\s|\$)" .github/CODEOWNERS; then
        echo "Exact match found in CODEOWNERS: $file"
        return 0
    fi
    return 1
}

for FILE in $DELETED_FILES; do
    PARENT_DIR=$(dirname "$FILE")
    if [ ! -d "$PARENT_DIR" ] || [ -z "$(ls -A "$PARENT_DIR" 2>/dev/null)" ]; then
        # The entire directory is empty or does not exist.
        if file_in_codeowners "$PARENT_DIR"; then
            echo "Error: $PARENT_DIR is empty or does not exist but its explicit reference still exists in CODEOWNERS."
            echo "offending_file=$PARENT_DIR" >> $GITHUB_ENV
            exit 1
        else
            echo "Directory $PARENT_DIR is empty and has no entry in CODEOWNERS."
        fi
    else
        # The directory still has files.
        if file_in_codeowners "$FILE"; then
            echo "Error: $FILE is deleted but its explicit reference still exists in CODEOWNERS."
            echo "offending_file=$FILE" >> $GITHUB_ENV
            exit 1
        else
            echo "Directory $PARENT_DIR still has files, so no need to update CODEOWNERS."
        fi
    fi
done

echo "All references to deleted files are consistent with CODEOWNERS."
