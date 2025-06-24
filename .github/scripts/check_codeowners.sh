#!/bin/bash
set -e

# Fetch latest master to compare
git fetch origin master

# Get SHAs
HEAD_SHA=$(git rev-parse HEAD)
BASE_SHA=$(git rev-parse origin/master)

# Get added, modified, renamed files (not deleted)
IFS=$'\n'
CHANGED_FILES=$(git diff --name-only --diff-filter=AMR "${BASE_SHA}"..."${HEAD_SHA}")
echo "Changed files:"
echo "$CHANGED_FILES"

# Sanitize CODEOWNERS rules (remove comments and blank lines)
mapfile -t CODEOWNERS_RULES < <(grep -v '^\s*#' .github/CODEOWNERS | awk '{print $1}' | grep -v '^\s*$')

# Function to test if file has a specific CODEOWNERS entry
check_direct_codeowners_entry() {
  local file="$1"

  for rule in "${CODEOWNERS_RULES[@]}"; do
    # Convert CODEOWNERS path-style rules to glob patterns
    rule_pattern="${rule#/}"  # strip leading slash
    rule_pattern="${rule_pattern//\*/.*}"  # convert * to regex

    # Exact match
    if [[ "$file" == "$rule" ]]; then
      echo "✅ Exact match in CODEOWNERS: $rule"
      return 0
    fi

    # Directory wildcard match, e.g., app/controllers/*.rb
    if [[ "$rule" == */* && "$file" =~ ^$rule_pattern$ ]]; then
      echo "✅ Pattern match in CODEOWNERS: $rule"
      return 0
    fi
  done

  echo "❌ No specific CODEOWNERS entry for: $file"
  return 1
}

# Check each changed file
for FILE in ${CHANGED_FILES}; do
  # Ignore dotfiles or CODEOWNERS itself
  if [[ "$FILE" == .* || "$FILE" == ".github/CODEOWNERS" ]]; then
    echo "Ignoring $FILE"
    continue
  fi

  echo "Checking $FILE..."
  if ! check_direct_codeowners_entry "$FILE"; then
    echo "Error: $FILE does not have a direct CODEOWNERS entry."
    echo "offending_file=$FILE" >> "$GITHUB_ENV"
    exit 1
  fi
done

echo "✅ All changed files have specific CODEOWNERS entries."
IFS=$' \t\n'  # Reset IFS
