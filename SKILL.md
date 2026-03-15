---
name: memory-tree
description: Restructure a flat MEMORY.md into a self-maintaining hierarchical memory tree. v2 adds automated reindexing, health monitoring, archive/purge lifecycle, and LLM reflection staging. Cuts boot token load by 70-95%.
---

# Memory Tree

Restructure a flat MEMORY.md into a hierarchical `memory/domains/` tree with auto-generated indexes. The agent reads a ~300-500 token root index on boot instead of the full file. Detailed content is searched on-demand via `memory_search`.

## Version
- v1.0 — Initial release. One-time migration tool.
- v2.0 — Living memory system. Adds 5 automated scripts, cron scheduling, health monitoring, archive/purge lifecycle, and LLM reflection staging.

## v2 Improvements

| Capability | v1 | v2 |
|---|---|---|
| Initial migration | ✅ Manual | ✅ Preserved |
| Reindexing | ❌ Manual | ✅ Auto every 6h (cron) |
| Memory health check | ❌ None | ✅ Status check every 6h |
| Stale entry cleanup | ❌ Never | ✅ Archive → 180d purge |
| general/ domain rot | ❌ Grows forever | ✅ 30-day max age enforced |
| LLM reflection staging | ❌ Never | ✅ Via _reflect_staging.json |
| Operational state | ❌ None | ✅ _meta.json + _stats.json |

## When to Run
- MEMORY.md exceeds ~1,000 tokens (~4KB)
- Agent boots are slow due to large memory context
- Explicitly asked to upgrade/restructure memory

## Architecture

```
memory/
├── _index.md              # Root summary (~300-500 tokens) — replaces MEMORY.md
├── _meta.json             # { last_reindex, domain_count, total_tokens, script_version }
├── _stats.json            # { domains: { <name>: { files, tokens } }, general_age_violations }
├── _reflect_staging.json  # (ephemeral) LLM reflection candidates — agent processes and deletes
├── _purge_log.json        # Audit log of purged files
├── domains/
│   ├── <domain>/
│   │   ├── _index.md      # Domain summary (auto-generated)
│   │   ├── topic-a.md     # One ## section from old MEMORY.md
│   │   └── topic-b__DELETE.md  # Archived — queued for 180d purge
│   └── <domain>/
│       └── ...
├── dates.md               # Cross-cutting dates (if present)
└── daily/                  # Existing daily logs moved here
    ├── YYYY-MM-DD.md
    └── ...
```

---

## Step-by-Step Instructions (Initial Migration — v1)

### 1. Audit Current State

Read your MEMORY.md. Count `##` sections and estimate total tokens (chars ÷ 4). If under ~1,000 tokens, stop — migration isn't worth it.

### 2. Backup

```
cp MEMORY.md memory/MEMORY.md.bak
```

Never skip this. The backup is your rollback.

### 3. Classify Each Section Into a Domain

Read each `## Heading` and assign it to a domain using these keyword rules:

| Domain | Keywords in heading |
|--------|-------------------|
| `identity` | identity, personal, family, personality, preferences, network, professional network |
| `business` | business, revenue, company, SEO, events, product, brand, pricing, clients |
| `infrastructure` | infrastructure, services, cron, voice, API, issues, quirks, config, tools |
| `community` | community, directory, meetup, group |
| `agents` | agent, task, sub-agent, monitoring |
| `legal` | legal, non-compete, contract, compliance |
| `dates` | dates, remember, anniversary, birthday → goes to `memory/dates.md` (not a domain) |
| `general` | anything that doesn't match above |

If a section clearly fits a subdomain (e.g., "getout.sg SEO"), nest it: `domains/business/seo/getout-sg.md`.

### 4. Create Domain Directories and Split

For each `## Section` in MEMORY.md:

1. Create the domain directory: `memory/domains/<domain>/`
2. Create a file named by slugifying the heading: lowercase, spaces→hyphens, strip special chars, max 60 chars
3. Write the full section content (heading + body + `_Related:` lines) into that file
4. Preserve ALL content exactly — do not summarize or truncate during migration

Example: `## Key Identity Facts` → `memory/domains/identity/key-identity-facts.md`

### 5. Move Daily Logs

Move all `memory/YYYY-*.md` files to `memory/daily/`:

```
mkdir -p memory/daily
mv memory/2026-*.md memory/daily/
```

Also move any progress-tracking files (e.g., `*-progress*.md`).

### 6. Generate Domain Indexes

For each domain directory, create `_index.md`:

```markdown
# <Domain> Index
_Last indexed: <ISO timestamp>_
_Estimated tokens: ~<total>_

### <filename.md> (~<tokens> tokens)
<First meaningful line from the file, max 250 chars>

### <filename2.md> (~<tokens> tokens)
<First meaningful line>
```

Token estimate = file chars ÷ 4.

### 7. Generate Root Index

Create `memory/_index.md`:

```markdown
# Memory Index
_Last indexed: <ISO timestamp>_
_Estimated tokens: ~<grand total across all domains>_

## Domains

### <Domain> (~<tokens> tokens)
<One-line summary of domain's primary topic>
_Also: <other file names without .md>_

### Daily Logs (<N> files in memory/daily/)
Searchable via memory_search.
```

### 8. Replace MEMORY.md

Overwrite MEMORY.md with:

```markdown
# Memory Index (see memory/domains/ for full content)
# Auto-generated — do not edit directly
# Original preserved at memory/MEMORY.md.bak
# Last regenerated: <ISO timestamp>

<contents of memory/_index.md>
```

This is what gets loaded on boot — ~300-500 tokens instead of the full file.

### 9. Verify

1. Confirm `memory/MEMORY.md.bak` exists and matches original size
2. Confirm every `## Section` from original exists as a file in `memory/domains/`
3. Test `memory_search` for a known fact — it should find content in the new paths
4. Confirm MEMORY.md is now under ~500 tokens

---

## v2 Scripts

Five shell scripts live in `skills/bonsai-memory/scripts/`. Install them once; run via cron or manually.

### bonsai-reindex.sh — Rebuild Index

Scans all domain files, regenerates `_index.md` for each domain, regenerates `memory/_index.md`, updates `MEMORY.md`, and writes `_meta.json` + `_stats.json`. No LLM required.

```bash
# Basic usage (uses ~/workspace by default)
bash skills/bonsai-memory/scripts/bonsai-reindex.sh

# Custom workspace
bash skills/bonsai-memory/scripts/bonsai-reindex.sh /path/to/workspace

# Via env var
BONSAI_WORKSPACE=/path/to/workspace bash skills/bonsai-memory/scripts/bonsai-reindex.sh
```

**Output:**
```
Reindexed 24 files across 5 domains (3840 tokens)
```

**Writes:**
- `memory/_meta.json` — `{ last_reindex, domain_count, total_tokens, script_version }`
- `memory/_stats.json` — `{ domains: { <name>: { files, tokens } }, general_age_violations }`
- `memory/_index.md` — root summary
- `memory/domains/<domain>/_index.md` — per-domain summaries
- `MEMORY.md` — updated with root index

---

### bonsai-status.sh — Health Check

Reads `_meta.json` and `_stats.json`, runs live checks on the filesystem, prints a clean status report. No LLM required.

```bash
bash skills/bonsai-memory/scripts/bonsai-status.sh
```

**Output:**
```
🌿 Bonsai Status
──────────────────────────────
Last reindex:  2h 15m ago (2026-03-15T06:00:00Z)
Total memory:  3840 tokens across 5 domains
general/ violations: 0 files older than 30d
Pending purge: none
──────────────────────────────
Status: HEALTHY
```

**Exit codes:**
- `0` = HEALTHY
- `1` = WARNING (overdue reindex, violations, pending purge, or staging file present)
- `2` = CRITICAL (5+ general violations)

---

### bonsai-migrate.sh — Move Files Between Domains

Moves a memory file from one domain to another, updates frontmatter `domain:` field, then triggers reindex.

```bash
bash skills/bonsai-memory/scripts/bonsai-migrate.sh <SOURCE_FILE> <DEST_DOMAIN> [WORKSPACE]
```

**Examples:**
```bash
# Move a general/ file into business domain
bash skills/bonsai-memory/scripts/bonsai-migrate.sh \
  memory/domains/general/go-events-pricing.md business

# With explicit workspace
bash skills/bonsai-memory/scripts/bonsai-migrate.sh \
  memory/domains/general/some-topic.md infrastructure /path/to/workspace
```

**What it does:**
1. Validates source file exists and dest differs from source domain
2. Updates or inserts `domain: <DEST_DOMAIN>` in frontmatter
3. Moves the file to `memory/domains/<DEST_DOMAIN>/`
4. Runs `bonsai-reindex.sh` automatically

---

### bonsai-reflect.sh — Stage LLM Reflection

Phase 1 (cheap, no LLM): Scans `_stats.json` and the filesystem for candidates that need agent review. Writes `_reflect_staging.json` as a sentinel file for an agent to pick up.

**Candidates are flagged when:**
- `general/` files are older than 15 days (should be migrated to a proper domain)
- A domain has >20 files (may need splitting)
- A domain has >500 tokens (may need pruning)
- An individual file has >500 tokens (oversized)

```bash
bash skills/bonsai-memory/scripts/bonsai-reflect.sh
```

**Output:**
```
Reflection staged: 7 candidates written to _reflect_staging.json
Run your agent now to process the reflection staging file.

Agent instructions:
  1. Read memory/_reflect_staging.json
  2. For each candidate: decide keep / migrate / archive (prefix with __DELETE)
  3. Run bonsai-reindex.sh after all decisions
  4. Delete _reflect_staging.json when done
```

**`_reflect_staging.json` format:**
```json
{
  "triggered_at": "2026-03-15T08:00:00Z",
  "candidates": [
    {
      "file": "memory/domains/general/old-note.md",
      "domain": "general",
      "age_days": 22,
      "tokens": 120,
      "reason": "general/ file older than 15 days (22d)"
    }
  ]
}
```

---

### bonsai-purge.sh — True Deletion After Grace Period

Finds all files with `__DELETE` suffix in `memory/domains/`. Only deletes if older than 180 days. Logs purged files to `_purge_log.json`.

```bash
bash skills/bonsai-memory/scripts/bonsai-purge.sh
```

**Output:**
```
Skipping old-note__DELETE.md — 134 days remaining
Purged: ancient-note__DELETE.md (184d old)

Purge log updated: memory/_purge_log.json

Purged 1 files. 1 files still in grace period.
```

**Archive workflow:**
1. Agent decides to archive a file → rename it: `some-topic.md` → `some-topic__DELETE.md`
2. `bonsai-purge.sh` runs weekly, checks mtime — skips if <180 days old
3. After 180 days, the file is permanently deleted and logged

---

## Cron Setup

Run these cron jobs to keep memory automatically maintained:

```bash
# Add to crontab (crontab -e):
0 */6 * * * bash ~/workspace/skills/bonsai-memory/scripts/bonsai-reindex.sh
30 */6 * * * bash ~/workspace/skills/bonsai-memory/scripts/bonsai-status.sh
0 2 * * 0 bash ~/workspace/skills/bonsai-memory/scripts/bonsai-purge.sh
```

**Schedule breakdown:**
- **bonsai-reindex.sh** — every 6 hours at :00 (keeps index fresh)
- **bonsai-status.sh** — every 6 hours at :30 (health check 30m after reindex)
- **bonsai-purge.sh** — Sundays at 2am (weekly cleanup)

**Optional: Weekly reflection staging**
```bash
# Run reflect every Sunday at 3am to queue candidates for agent review
0 3 * * 0 bash ~/workspace/skills/bonsai-memory/scripts/bonsai-reflect.sh
```

---

## Reflection Workflow

When `bonsai-reflect.sh` runs, it writes `memory/_reflect_staging.json`. On next boot (or when the agent checks status), it should notice this file and process it.

**Agent steps when `_reflect_staging.json` exists:**

1. **Read** `memory/_reflect_staging.json` — get the candidates list
2. **For each candidate**, decide one of three actions:
   - **keep** — leave the file as-is (it belongs where it is)
   - **migrate** — run `bonsai-migrate.sh <file> <dest-domain>` to move it to a better domain
   - **archive** — rename the file with `__DELETE` suffix (e.g., `old-note.md` → `old-note__DELETE.md`); it enters the 180-day grace period before `bonsai-purge.sh` removes it permanently
3. **Run** `bonsai-reindex.sh` after all decisions to regenerate indexes
4. **Delete** `_reflect_staging.json` when done

**Decision heuristics:**
- `general/` files >15 days: try to classify into a real domain; if not classifiable, archive
- Oversized domains (>20 files): look for natural sub-groupings to split into a subdomain
- Oversized files (>500 tokens): consider splitting into multiple files by sub-topic
- If a file's content is no longer relevant → archive (never hard-delete directly)

---

## Rules

- **Never lose content.** Every line from original MEMORY.md must exist in a domain file.
- **Backup first.** Always create `memory/MEMORY.md.bak` before touching MEMORY.md.
- **Idempotent.** If domain files already exist, skip them — don't overwrite.
- **`memory_search` compatibility.** OpenClaw's memory_search scans `memory/*.md` recursively. The tree structure is fully compatible — no config changes needed.
- **Daily logs stay simple.** Just move to `memory/daily/`, don't restructure them.
- **Archive before delete.** Never hard-delete memory files directly. Always rename with `__DELETE` suffix first and let `bonsai-purge.sh` handle final deletion after 180 days.
- **general/ domain is a staging area, not a home.** Files there older than 30 days are violations. Reflect and migrate them.

---

## Expected Results

| Workspace size | Before (tokens) | After (tokens) | Reduction |
|---------------|-----------------|----------------|-----------|
| Small (<1K) | ~500 | ~300 | ~40% |
| Medium (1-3K) | ~2,000 | ~350 | ~80% |
| Large (3-6K) | ~5,000 | ~400 | ~92% |
| Very large (6K+) | ~6,400 | ~385 | ~94% |
