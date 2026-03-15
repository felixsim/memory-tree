#!/usr/bin/env bash
# bonsai-status.sh — Health check for bonsai memory tree (no LLM)
# Usage: bonsai-status.sh [WORKSPACE]
# Exit codes: 0=HEALTHY, 1=WARNING, 2=CRITICAL
# Version: 2.0

set -euo pipefail

WORKSPACE="${1:-${BONSAI_WORKSPACE:-$HOME/workspace}}"
MEMORY_DIR="$WORKSPACE/memory"
META_FILE="$MEMORY_DIR/_meta.json"
STATS_FILE="$MEMORY_DIR/_stats.json"
DOMAINS_DIR="$MEMORY_DIR/domains"

status="HEALTHY"
exit_code=0

# Helper: parse simple JSON value (no jq dependency)
json_get() {
  local file="$1" key="$2"
  grep -o "\"${key}\":[^,}]*" "$file" 2>/dev/null | head -1 | sed 's/.*: *//;s/"//g;s/[, }]//g' || echo ""
}

echo "🌿 Bonsai Status"
echo "──────────────────────────────"

# --- Last reindex ---
if [[ ! -f "$META_FILE" ]]; then
  echo "Last reindex:  UNKNOWN (no _meta.json)"
  status="WARNING"
  exit_code=1
else
  last_reindex=$(json_get "$META_FILE" "last_reindex")
  total_tokens=$(json_get "$META_FILE" "total_tokens")
  domain_count=$(json_get "$META_FILE" "domain_count")

  if [[ -n "$last_reindex" ]]; then
    # Calculate how long ago
    now_epoch=$(date +%s)
    if [[ "$(uname)" == "Darwin" ]]; then
      reindex_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_reindex" +%s 2>/dev/null || echo 0)
    else
      reindex_epoch=$(date -d "$last_reindex" +%s 2>/dev/null || echo 0)
    fi
    age_secs=$(( now_epoch - reindex_epoch ))
    age_hours=$(( age_secs / 3600 ))
    age_mins=$(( (age_secs % 3600) / 60 ))

    if (( age_hours >= 1 )); then
      ago_str="${age_hours}h ${age_mins}m ago"
    else
      ago_str="${age_mins}m ago"
    fi

    echo "Last reindex:  ${ago_str} (${last_reindex})"

    # Check if overdue (>7h)
    if (( age_secs > 25200 )); then
      echo "  ⚠️  Reindex overdue (>${age_hours}h ago)"
      [[ "$exit_code" -lt 1 ]] && { status="WARNING"; exit_code=1; }
    fi
  else
    echo "Last reindex:  UNKNOWN"
    status="WARNING"
    exit_code=1
  fi

  echo "Total memory:  ${total_tokens:-0} tokens across ${domain_count:-0} domains"
fi

# --- general/ age violations ---
general_violations=0
if [[ -f "$STATS_FILE" ]]; then
  general_violations=$(json_get "$STATS_FILE" "general_age_violations")
fi

# Also do a live check
live_violations=0
if [[ -d "$DOMAINS_DIR/general" ]]; then
  now_epoch=$(date +%s)
  while IFS= read -r -d '' filepath; do
    fname=$(basename "$filepath")
    [[ "$fname" == _* ]] && continue
    if [[ "$(uname)" == "Darwin" ]]; then
      file_mtime=$(stat -f %m "$filepath")
    else
      file_mtime=$(stat -c %Y "$filepath")
    fi
    age_days=$(( (now_epoch - file_mtime) / 86400 ))
    if (( age_days > 30 )); then
      live_violations=$(( live_violations + 1 ))
    fi
  done < <(find "$DOMAINS_DIR/general" -maxdepth 1 -name "*.md" -not -name "_index.md" -print0 2>/dev/null)
fi

echo "general/ violations: ${live_violations} files older than 30d"
if (( live_violations > 0 )); then
  [[ "$exit_code" -lt 1 ]] && { status="WARNING"; exit_code=1; }
  if (( live_violations >= 5 )); then
    status="CRITICAL"; exit_code=2
  fi
fi

# --- __DELETE suffix files ---
delete_count=0
oldest_delete=""
oldest_delete_days=0
if [[ -d "$DOMAINS_DIR" ]]; then
  now_epoch=$(date +%s)
  while IFS= read -r -d '' filepath; do
    delete_count=$(( delete_count + 1 ))
    if [[ "$(uname)" == "Darwin" ]]; then
      file_mtime=$(stat -f %m "$filepath")
    else
      file_mtime=$(stat -c %Y "$filepath")
    fi
    age_days=$(( (now_epoch - file_mtime) / 86400 ))
    if (( age_days > oldest_delete_days )); then
      oldest_delete_days=$age_days
      oldest_delete=$(basename "$filepath")
    fi
  done < <(find "$DOMAINS_DIR" -name "*__DELETE*" -print0 2>/dev/null)
fi

if (( delete_count > 0 )); then
  echo "Pending purge: ${delete_count} files with __DELETE suffix (oldest: ${oldest_delete} — ${oldest_delete_days}d)"
  [[ "$exit_code" -lt 1 ]] && { status="WARNING"; exit_code=1; }
else
  echo "Pending purge: none"
fi

# --- _reflect_staging.json ---
if [[ -f "$MEMORY_DIR/_reflect_staging.json" ]]; then
  echo "Reflection:    ⚠️  _reflect_staging.json exists — agent action needed"
  [[ "$exit_code" -lt 1 ]] && { status="WARNING"; exit_code=1; }
fi

echo "──────────────────────────────"
echo "Status: ${status}"

exit $exit_code
