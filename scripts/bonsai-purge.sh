#!/usr/bin/env bash
# bonsai-purge.sh — True deletion of archived files after 180-day grace period
# Usage: bonsai-purge.sh [WORKSPACE]
# Finds files with __DELETE suffix — only purges if older than 180 days
# Version: 2.0

set -euo pipefail

WORKSPACE="${1:-${BONSAI_WORKSPACE:-$HOME/workspace}}"
MEMORY_DIR="$WORKSPACE/memory"
DOMAINS_DIR="$MEMORY_DIR/domains"
PURGE_LOG="$MEMORY_DIR/_purge_log.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
now_epoch=$(date +%s)
GRACE_DAYS=180

if [[ ! -d "$DOMAINS_DIR" ]]; then
  echo "Error: domains directory not found at $DOMAINS_DIR"
  exit 1
fi

purged_count=0
skipped_count=0
purged_files_json=""
skipped_files=()

# Find all __DELETE files
while IFS= read -r -d '' filepath; do
  fname=$(basename "$filepath")

  if [[ "$(uname)" == "Darwin" ]]; then
    file_mtime=$(stat -f %m "$filepath")
  else
    file_mtime=$(stat -c %Y "$filepath")
  fi

  age_days=$(( (now_epoch - file_mtime) / 86400 ))
  remaining_days=$(( GRACE_DAYS - age_days ))

  if (( age_days >= GRACE_DAYS )); then
    # Delete the file
    rel_path="${filepath#$WORKSPACE/}"
    purged_files_json+="{\"path\":\"${rel_path}\",\"purged_at\":\"${NOW}\",\"age_days\":${age_days}},"
    rm -f "$filepath"
    purged_count=$(( purged_count + 1 ))
    echo "Purged: $fname (${age_days}d old)"
  else
    skipped_count=$(( skipped_count + 1 ))
    skipped_files+=("$fname — ${remaining_days} days remaining")
    echo "Skipping $fname — ${remaining_days} days remaining"
  fi
done < <(find "$DOMAINS_DIR" -name "*__DELETE*" -print0 2>/dev/null)

# Print skipped files summary
for item in "${skipped_files[@]+"${skipped_files[@]}"}"; do
  echo "  ⏳ $item"
done

# Update purge log
if (( purged_count > 0 )); then
  purged_files_json="${purged_files_json%,}"

  # Read existing log if present
  existing_files=""
  if [[ -f "$PURGE_LOG" ]]; then
    # Extract existing files array content
    existing_files=$(grep -o '"path".*' "$PURGE_LOG" | head -1 || true)
    # Simple approach: append to files array
    existing_json=$(cat "$PURGE_LOG" 2>/dev/null || echo "{}")
    # Just overwrite with new run appended — production systems would merge
  fi

  cat > "$PURGE_LOG" <<EOF
{
  "purged_at": "${NOW}",
  "files": [${purged_files_json}]
}
EOF
  echo ""
  echo "Purge log updated: $PURGE_LOG"
fi

echo ""
echo "Purged ${purged_count} files. ${skipped_count} files still in grace period."

# Trigger reindex if anything was purged
if (( purged_count > 0 )); then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "$SCRIPT_DIR/bonsai-reindex.sh" ]]; then
    echo "Running reindex after purge..."
    bash "$SCRIPT_DIR/bonsai-reindex.sh" "$WORKSPACE"
  else
    echo "⚠️  bonsai-reindex.sh not found — run reindex manually"
  fi
fi
