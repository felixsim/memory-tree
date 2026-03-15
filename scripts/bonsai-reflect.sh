#!/usr/bin/env bash
# bonsai-reflect.sh — Stage LLM reflection candidates (no LLM — prepares sentinel file)
# Usage: bonsai-reflect.sh [WORKSPACE]
# Phase 1: Identify candidates → write _reflect_staging.json
# Phase 2: Agent picks up _reflect_staging.json and makes decisions
# Version: 2.0

set -euo pipefail

WORKSPACE="${1:-${BONSAI_WORKSPACE:-$HOME/workspace}}"
MEMORY_DIR="$WORKSPACE/memory"
DOMAINS_DIR="$MEMORY_DIR/domains"
STATS_FILE="$MEMORY_DIR/_stats.json"
STAGING_FILE="$MEMORY_DIR/_reflect_staging.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
now_epoch=$(date +%s)

if [[ ! -d "$DOMAINS_DIR" ]]; then
  echo "Error: domains directory not found at $DOMAINS_DIR"
  exit 1
fi

if [[ -f "$STAGING_FILE" ]]; then
  echo "⚠️  _reflect_staging.json already exists."
  echo "Process it with your agent before staging again."
  echo "Delete it manually to force a new staging run."
  exit 1
fi

candidates=()

# Helper: parse simple JSON value (no jq dependency)
json_domain_tokens() {
  local domain="$1"
  grep -o "\"${domain}\":{[^}]*}" "$STATS_FILE" 2>/dev/null | \
    grep -o '"tokens":[0-9]*' | sed 's/"tokens"://' || echo "0"
}
json_domain_files() {
  local domain="$1"
  grep -o "\"${domain}\":{[^}]*}" "$STATS_FILE" 2>/dev/null | \
    grep -o '"files":[0-9]*' | sed 's/"files"://' || echo "0"
}

# Build candidates JSON array
candidates_json=""

# Scan all domain files
while IFS= read -r -d '' filepath; do
  fname=$(basename "$filepath")
  domain=$(basename "$(dirname "$filepath")")

  [[ "$fname" == _* ]] && continue
  [[ "$fname" == *__DELETE* ]] && continue

  chars=$(wc -c < "$filepath" | tr -d ' ')
  tokens=$(( chars / 4 ))

  if [[ "$(uname)" == "Darwin" ]]; then
    file_mtime=$(stat -f %m "$filepath")
  else
    file_mtime=$(stat -c %Y "$filepath")
  fi
  age_days=$(( (now_epoch - file_mtime) / 86400 ))

  reason=""

  # Rule 1: general/ files older than 15 days
  if [[ "$domain" == "general" ]] && (( age_days > 15 )); then
    reason="general/ file older than 15 days (${age_days}d)"
  fi

  # Rule 3: individual file token count > 500 (oversized file)
  if [[ -z "$reason" ]] && (( tokens > 500 )); then
    reason="oversized file (${tokens} tokens)"
  fi

  if [[ -n "$reason" ]]; then
    rel_path="${filepath#$WORKSPACE/}"
    entry="{\"file\":\"${rel_path}\",\"domain\":\"${domain}\",\"age_days\":${age_days},\"tokens\":${tokens},\"reason\":\"${reason}\"}"
    candidates_json+="${entry},"
  fi
done < <(find "$DOMAINS_DIR" -name "*.md" -not -name "_index.md" -print0 2>/dev/null)

# Rule 2: domains with >20 files — add a domain-level candidate
if [[ -d "$DOMAINS_DIR" ]]; then
  for domain_dir in "$DOMAINS_DIR"/*/; do
    [[ -d "$domain_dir" ]] || continue
    domain=$(basename "$domain_dir")
    file_count=$(find "$domain_dir" -maxdepth 1 -name "*.md" -not -name "_index.md" | wc -l | tr -d ' ')
    if (( file_count > 20 )); then
      entry="{\"file\":\"memory/domains/${domain}/_index.md\",\"domain\":\"${domain}\",\"age_days\":0,\"tokens\":0,\"reason\":\"domain has ${file_count} files (>20) — consider splitting\"}"
      candidates_json+="${entry},"
    fi
    # Rule: domain token count > 500 from stats file
    if [[ -f "$STATS_FILE" ]]; then
      dtokens=$(json_domain_tokens "$domain")
      if [[ -n "$dtokens" ]] && (( dtokens > 500 )); then
        entry="{\"file\":\"memory/domains/${domain}/_index.md\",\"domain\":\"${domain}\",\"age_days\":0,\"tokens\":${dtokens},\"reason\":\"domain token count ${dtokens} exceeds 500\"}"
        candidates_json+="${entry},"
      fi
    fi
  done
fi

# Remove trailing comma
candidates_json="${candidates_json%,}"

# Count candidates
candidate_count=0
if [[ -n "$candidates_json" ]]; then
  candidate_count=$(echo "$candidates_json" | grep -o '"file"' | wc -l | tr -d ' ')
fi

# Write staging file
cat > "$STAGING_FILE" <<EOF
{
  "triggered_at": "${NOW}",
  "candidates": [${candidates_json}]
}
EOF

echo "Reflection staged: ${candidate_count} candidates written to _reflect_staging.json"
echo "Run your agent now to process the reflection staging file."
echo ""
echo "Agent instructions:"
echo "  1. Read memory/_reflect_staging.json"
echo "  2. For each candidate: decide keep / migrate / archive (prefix with __DELETE)"
echo "  3. Run bonsai-reindex.sh after all decisions"
echo "  4. Delete _reflect_staging.json when done"
