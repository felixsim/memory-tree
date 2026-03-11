---
name: memory-tree
description: Restructure an OpenClaw agent's flat MEMORY.md into a hierarchical domain-based memory tree. Cuts boot token load by 70-95%. Use when an agent's MEMORY.md exceeds ~1,000 tokens, or when told to "upgrade memory", "restructure memory", "implement memory tree", or "reduce memory token usage". Works on any OpenClaw workspace — no scripts or config needed.
---

# Memory Tree

Restructure a flat MEMORY.md into a hierarchical `memory/domains/` tree with auto-generated indexes. The agent reads a ~300-500 token root index on boot instead of the full file. Detailed content is searched on-demand via `memory_search`.

## When to Run
- MEMORY.md exceeds ~1,000 tokens (~4KB)
- Agent boots are slow due to large memory context
- Explicitly asked to upgrade/restructure memory

## Architecture

```
memory/
├── _index.md              # Root summary (~300-500 tokens) — replaces MEMORY.md
├── domains/
│   ├── <domain>/
│   │   ├── _index.md      # Domain summary (auto-generated)
│   │   ├── topic-a.md     # One ## section from old MEMORY.md
│   │   └── topic-b.md
│   └── <domain>/
│       └── ...
├── dates.md               # Cross-cutting dates (if present)
└── daily/                  # Existing daily logs moved here
    ├── YYYY-MM-DD.md
    └── ...
```

## Step-by-Step Instructions

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

### 10. Re-index (Ongoing)

After editing any domain file, regenerate that domain's `_index.md` and the root index. Keep token estimates current.

## Rules

- **Never lose content.** Every line from original MEMORY.md must exist in a domain file.
- **Backup first.** Always create `memory/MEMORY.md.bak` before touching MEMORY.md.
- **Idempotent.** If domain files already exist, skip them — don't overwrite.
- **`memory_search` compatibility.** OpenClaw's memory_search scans `memory/*.md` recursively. The tree structure is fully compatible — no config changes needed.
- **Daily logs stay simple.** Just move to `memory/daily/`, don't restructure them.

## Expected Results

| Workspace size | Before (tokens) | After (tokens) | Reduction |
|---------------|-----------------|----------------|-----------|
| Small (<1K) | ~500 | ~300 | ~40% |
| Medium (1-3K) | ~2,000 | ~350 | ~80% |
| Large (3-6K) | ~5,000 | ~400 | ~92% |
| Very large (6K+) | ~6,400 | ~385 | ~94% |
