#!/usr/bin/env bash
# bonsai-reindex.sh — Rebuild bonsai memory index (no LLM)
# Usage: bonsai-reindex.sh [WORKSPACE]
# Version: 2.0

set -euo pipefail

WORKSPACE="${1:-${BONSAI_WORKSPACE:-$HOME/workspace}}"
MEMORY_DIR="$WORKSPACE/memory"
DOMAINS_DIR="$MEMORY_DIR/domains"
META_FILE="$MEMORY_DIR/_meta.json"
STATS_FILE="$MEMORY_DIR/_stats.json"
ROOT_INDEX="$MEMORY_DIR/_index.md"
MEMORY_MD="$WORKSPACE/MEMORY.md"
SCRIPT_VERSION="2.0"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ ! -d "$DOMAINS_DIR" ]]; then
  echo "Error: domains directory not found at $DOMAINS_DIR"
  echo "Run the initial bonsai migration first (see SKILL.md)."
  exit 1
fi

total_files=0
total_tokens=0
declare -A domain_files
declare -A domain_tokens
general_age_violations=0

# Scan all domain files
while IFS= read -r -d '' filepath; do
  # Skip _index.md and __DELETE files for token counting but count the file
  filename=$(basename "$filepath")
  domain=$(basename "$(dirname "$filepath")")

  # Count tokens (chars ÷ 4)
  chars=$(wc -c < "$filepath" | tr -d ' ')
  tokens=$(( chars / 4 ))

  domain_files[$domain]=$(( ${domain_files[$domain]:-0} + 1 ))
  domain_tokens[$domain]=$(( ${domain_tokens[$domain]:-0} + tokens ))
  total_files=$(( total_files + 1 ))
  total_tokens=$(( total_tokens + tokens ))

  # Check general/ domain age violations (>30 days)
  if [[ "$domain" == "general" && "$filename" != _* ]]; then
    # Get file modification time in seconds since epoch
    if [[ "$(uname)" == "Darwin" ]]; then
      file_mtime=$(stat -f %m "$filepath")
    else
      file_mtime=$(stat -c %Y "$filepath")
    fi
    now_epoch=$(date +%s)
    age_days=$(( (now_epoch - file_mtime) / 86400 ))
    if (( age_days > 30 )); then
      general_age_violations=$(( general_age_violations + 1 ))
    fi
  fi
done < <(find "$DOMAINS_DIR" -name "*.md" -not -name "_index.md" -print0 2>/dev/null)

# Generate per-domain _index.md files
for domain_dir in "$DOMAINS_DIR"/*/; do
  [[ -d "$domain_dir" ]] || continue
  domain=$(basename "$domain_dir")
  domain_index="$domain_dir/_index.md"

  {
    echo "# ${domain^} Index"
    echo "_Last indexed: ${NOW}_"
    echo "_Estimated tokens: ~${domain_tokens[$domain]:-0}_"
    echo ""

    while IFS= read -r -d '' filepath; do
      fname=$(basename "$filepath")
      [[ "$fname" == _* ]] && continue

      chars=$(wc -c < "$filepath" | tr -d ' ')
      ftokens=$(( chars / 4 ))

      # Get first meaningful line (non-empty, non-frontmatter, non-heading-only)
      first_line=""
      while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"  # trim leading whitespace
        [[ -z "$line" ]] && continue
        [[ "$line" == "---" ]] && continue
        [[ "$line" =~ ^#+ && ${#line} -lt 5 ]] && continue
        first_line="${line:0:250}"
        break
      done < "$filepath"

      echo "### ${fname} (~${ftokens} tokens)"
      echo "${first_line:-[no content]}"
      echo ""
    done < <(find "$domain_dir" -maxdepth 1 -name "*.md" -not -name "_index.md" -print0 2>/dev/null | sort -z)
  } > "$domain_index"
done

# Generate root _index.md
{
  echo "# Memory Index"
  echo "_Last indexed: ${NOW}_"
  echo "_Estimated tokens: ~${total_tokens}_"
  echo ""
  echo "## Domains"
  echo ""

  for domain in $(echo "${!domain_files[@]}" | tr ' ' '\n' | sort); do
    files="${domain_files[$domain]:-0}"
    tokens="${domain_tokens[$domain]:-0}"
    # List file names (without extension) as a quick overview
    file_list=""
    while IFS= read -r -d '' fp; do
      fn=$(basename "$fp" .md)
      [[ "$fn" == _* ]] && continue
      file_list+="${fn}, "
    done < <(find "$DOMAINS_DIR/$domain" -maxdepth 1 -name "*.md" -not -name "_index.md" -print0 2>/dev/null | sort -z)
    file_list="${file_list%, }"

    echo "### ${domain^} (~${tokens} tokens, ${files} files)"
    if [[ -n "$file_list" ]]; then
      echo "_Files: ${file_list}_"
    fi
    echo ""
  done

  # Note daily logs if present
  if [[ -d "$MEMORY_DIR/daily" ]]; then
    daily_count=$(find "$MEMORY_DIR/daily" -name "*.md" | wc -l | tr -d ' ')
    echo "### Daily Logs (${daily_count} files in memory/daily/)"
    echo "Searchable via memory_search."
    echo ""
  fi
} > "$ROOT_INDEX"

# Update MEMORY.md with root index content
if [[ -f "$MEMORY_MD" ]]; then
  {
    echo "# Memory Index (see memory/domains/ for full content)"
    echo "# Auto-generated — do not edit directly"
    echo "# Last regenerated: ${NOW}"
    echo ""
    cat "$ROOT_INDEX"
  } > "$MEMORY_MD"
fi

# Write _meta.json
domain_count=${#domain_files[@]}
cat > "$META_FILE" <<EOF
{
  "last_reindex": "${NOW}",
  "domain_count": ${domain_count},
  "total_tokens": ${total_tokens},
  "script_version": "${SCRIPT_VERSION}"
}
EOF

# Write _stats.json
domains_json="{"
first=true
for domain in $(echo "${!domain_files[@]}" | tr ' ' '\n' | sort); do
  $first || domains_json+=","
  domains_json+="\"${domain}\":{\"files\":${domain_files[$domain]:-0},\"tokens\":${domain_tokens[$domain]:-0}}"
  first=false
done
domains_json+="}"

cat > "$STATS_FILE" <<EOF
{
  "domains": ${domains_json},
  "general_age_violations": ${general_age_violations}
}
EOF

echo "Reindexed ${total_files} files across ${domain_count} domains (${total_tokens} tokens)"
