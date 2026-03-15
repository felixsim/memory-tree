#!/usr/bin/env bash
# bonsai-migrate.sh — Move a memory file between domains
# Usage: bonsai-migrate.sh <SOURCE_FILE> <DEST_DOMAIN> [WORKSPACE]
# Example: bonsai-migrate.sh memory/domains/general/some-topic.md business
# Version: 2.0

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: bonsai-migrate.sh <SOURCE_FILE> <DEST_DOMAIN> [WORKSPACE]"
  echo "Example: bonsai-migrate.sh memory/domains/general/some-topic.md business"
  exit 1
fi

SOURCE_FILE="$1"
DEST_DOMAIN="$2"
WORKSPACE="${3:-${BONSAI_WORKSPACE:-$HOME/workspace}}"

# Resolve source file path (relative to WORKSPACE if not absolute)
if [[ "$SOURCE_FILE" != /* ]]; then
  SOURCE_FILE="$WORKSPACE/$SOURCE_FILE"
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Error: source file not found: $SOURCE_FILE"
  exit 1
fi

MEMORY_DIR="$WORKSPACE/memory"
DOMAINS_DIR="$MEMORY_DIR/domains"
SOURCE_DOMAIN=$(basename "$(dirname "$SOURCE_FILE")")
FILENAME=$(basename "$SOURCE_FILE")
DEST_DIR="$DOMAINS_DIR/$DEST_DOMAIN"
DEST_FILE="$DEST_DIR/$FILENAME"

if [[ "$SOURCE_DOMAIN" == "$DEST_DOMAIN" ]]; then
  echo "Error: source and destination domains are the same ($DEST_DOMAIN)"
  exit 1
fi

if [[ -f "$DEST_FILE" ]]; then
  echo "Error: destination file already exists: $DEST_FILE"
  echo "Rename the source file first or remove the destination."
  exit 1
fi

# Create destination domain directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Update frontmatter domain: field if present
# Read file content
file_content=$(cat "$SOURCE_FILE")

if echo "$file_content" | grep -q "^domain:"; then
  # Update existing domain field
  updated_content=$(echo "$file_content" | sed "s/^domain:.*$/domain: ${DEST_DOMAIN}/")
  echo "$updated_content" > "$SOURCE_FILE"
  echo "Updated frontmatter: domain: ${DEST_DOMAIN}"
elif echo "$file_content" | grep -q "^---"; then
  # Frontmatter exists but no domain field — insert it after first ---
  updated_content=$(echo "$file_content" | awk '
    /^---/ && !inserted {
      print
      print "domain: '"$DEST_DOMAIN"'"
      inserted=1
      next
    }
    { print }
  ')
  echo "$updated_content" > "$SOURCE_FILE"
  echo "Inserted frontmatter: domain: ${DEST_DOMAIN}"
else
  # No frontmatter — prepend it
  {
    echo "---"
    echo "domain: ${DEST_DOMAIN}"
    echo "---"
    echo ""
    cat "$SOURCE_FILE"
  } > "${SOURCE_FILE}.tmp" && mv "${SOURCE_FILE}.tmp" "$SOURCE_FILE"
  echo "Added frontmatter: domain: ${DEST_DOMAIN}"
fi

# Move the file
mv "$SOURCE_FILE" "$DEST_FILE"
echo "Moved: $SOURCE_DOMAIN/$FILENAME → $DEST_DOMAIN/$FILENAME"

# Trigger reindex
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/bonsai-reindex.sh" ]]; then
  bash "$SCRIPT_DIR/bonsai-reindex.sh" "$WORKSPACE"
else
  echo "⚠️  bonsai-reindex.sh not found at $SCRIPT_DIR — run reindex manually"
fi
