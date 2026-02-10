#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# search_github_org.sh
#
# Searches for a string across every repository in a GitHub organization
# using the GitHub Code Search API.
#
# Requirements:
#   - A GitHub Personal Access Token (PAT) with `repo` scope
#     (classic) or fine-grained read access to the org's repos.
#   - curl & jq installed
#
# Usage:
#   export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
#   ./search_github_org.sh
# ---------------------------------------------------------------------------

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────
SEARCH_STRING="vets-api-sidekiq-admin-group-prod"
ORG="department-of-veterans-affairs"
PER_PAGE=100          # max allowed by GitHub API
# ---------------------------------------------------------------------------

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: Please export GITHUB_TOKEN before running this script."
  echo "  export GITHUB_TOKEN=\"ghp_...\""
  exit 1
fi

AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"
ACCEPT_HEADER="Accept: application/vnd.github.v3+json"

# URL-encode the query: "<string> org:<org>"
QUERY="${SEARCH_STRING}+org:${ORG}"

echo "============================================================"
echo "Searching for \"${SEARCH_STRING}\""
echo "in all repos under: https://github.com/${ORG}"
echo "============================================================"
echo ""

page=1
total_found=0

while true; do
  response=$(curl -s -w "\n%{http_code}" \
    -H "${AUTH_HEADER}" \
    -H "${ACCEPT_HEADER}" \
    "https://api.github.com/search/code?q=${QUERY}&per_page=${PER_PAGE}&page=${page}")

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  # Handle rate-limiting (HTTP 403 / 429)
  if [[ "$http_code" == "403" || "$http_code" == "429" ]]; then
    echo "⏳  Rate-limited. Waiting 30 seconds before retrying..."
    sleep 30
    continue
  fi

  if [[ "$http_code" != "200" ]]; then
    echo "ERROR: GitHub API returned HTTP ${http_code}"
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
  fi

  total_count=$(echo "$body" | jq '.total_count')
  items_count=$(echo "$body" | jq '.items | length')

  if [[ "$page" -eq 1 ]]; then
    echo "🔎  Total matches found by GitHub: ${total_count}"
    echo ""
  fi

  if [[ "$items_count" -eq 0 ]]; then
    break
  fi

  # Print each result
  echo "$body" | jq -r '.items[] | "📄 \(.repository.full_name)  →  \(.path)\n   🔗 \(.html_url)\n"'

  total_found=$((total_found + items_count))

  # GitHub Code Search caps at 1000 results (10 pages × 100)
  if [[ "$total_found" -ge "$total_count" ]] || [[ "$page" -ge 10 ]]; then
    break
  fi

  page=$((page + 1))

  # Code Search API has a secondary rate limit — be polite
  sleep 5
done

echo "============================================================"
echo "✅  Done. Displayed ${total_found} of ${total_count:-0} results."
echo "============================================================"

