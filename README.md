# 🌿 Bonsai Memory — Prune Your AI Agent's Context Window

**Reduce your AI agent's token usage by 70-95%.** Bonsai Memory restructures flat memory files into a carefully pruned hierarchy — a slim index on boot, domain branches on demand. Like shaping a bonsai: intentional, minimal, nothing wasted.

Built for [OpenClaw](https://openclaw.ai) agents. Works with any LLM agent framework that uses persistent memory files.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/felixsim/bonsai-memory)](https://github.com/felixsim/bonsai-memory/releases)

---

## The Simple Explanation

Every time an AI agent starts a conversation, it loads its memory — everything it knows about you, your business, your preferences, your history. All of it. Every single time. Even if you're just asking it to check the weather.

Imagine starting every workday by reading your entire diary from cover to cover before answering a single email. That's what your AI agent is doing.

**Bonsai Memory fixes this.** Instead of one giant memory file, it shapes your agent's knowledge into a pruned tree — a trunk (slim index), branches (domains), and leaves (topic files). Your agent reads the trunk on boot (takes seconds, uses minimal tokens), then grows into the specific branch it needs for the current task.

### What You Get

- ⚡ **Faster responses** — Less memory to process on every interaction
- 💰 **Lower API costs** — Fewer tokens per call means lower bills
- 🧠 **Better reasoning** — Less noise in context means sharper focus
- 🔒 **Zero risk** — Original memory is backed up, one command to rollback

### How to Use It

Tell your OpenClaw agent:

> *"Restructure your memory using the bonsai-memory skill."*

That's it. The agent reads the instructions and does the migration itself. No coding, no terminal commands, no configuration.

### Real Results

Tested across 9 production agents:

| Agent Role | Token Reduction |
|------------|----------------|
| Chief of staff | **94%** (6,400 → 385) |
| Operations | **87%** (2,764 → 367) |
| SEO | **87%** (2,732 → 373) |
| Content | **86%** (1,945 → 271) |
| School assistant | **80%** (1,450 → 296) |
| Code | **75%** (1,012 → 249) |
| Research | **66%** (939 → 316) |
| LinkedIn | **76%** (899 → 218) |

**Average: 81% reduction** in boot memory token load across all agents.

---

## Technical Deep Dive

### The Problem: Linear Memory in a Branching World

LLM agents with persistent memory typically use a flat-file approach: a single `MEMORY.md` (or equivalent) that gets injected into the system prompt or context window on every session initialization. This creates three compounding problems:

1. **O(n) boot cost.** Every session pays the full token cost of the entire memory, regardless of task relevance. An agent with 6,000 tokens of memory burns 6,000 tokens before generating a single response — on every interaction.

2. **Context window pollution.** Irrelevant memory competes with task-relevant information for attention in the transformer's context window. Research shows LLM performance degrades as context length increases with irrelevant content ([Lost in the Middle, Liu et al. 2023](https://arxiv.org/abs/2307.03172)). Your agent is literally thinking worse because it's remembering too much.

3. **Linear scaling.** As the agent accumulates knowledge, boot cost grows linearly with no ceiling. A productive agent that learns over weeks/months eventually hits context window limits or unacceptable latency.

### The Solution: Hierarchical Progressive Disclosure

Bonsai Memory applies a B-tree-inspired indexing strategy to agent memory. Like a bonsai tree, every branch is intentional — no wild growth, no dead weight. Instead of loading all content, the agent traverses a pruned hierarchy:

```
                    ┌─────────────────────┐
    Trunk:          │   Root Index        │  ~400 tokens
    (every session) │   (domain summaries)│  (always loaded)
                    └────────┬────────────┘
                             │
              ┌──────────────┼──────────────┐
    Branches: ▼              ▼              ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │ Identity │  │ Business │  │ Infra    │  ~100-200 tokens each
        │ _index   │  │ _index   │  │ _index   │  (loaded on demand)
        └────┬─────┘  └────┬─────┘  └────┬─────┘
             │              │              │
    Leaves:  ├────┐    ┌───┴────┐    ┌───┴────┐
             ▼    ▼    ▼        ▼    ▼        ▼
         personal family company  SEO services issues   (loaded on demand)
           .md    .md    .md     .md   .md     .md
```

**Maximum traversal depth: 3 reads** for any fact lookup. Worst case token cost per lookup: ~400 (trunk) + ~150 (branch index) + ~200 (leaf) = **~750 tokens** vs loading the entire 6,000+ token file.

Best case (task doesn't need memory): **~400 tokens**. That's the trunk and nothing else.

### How the Migration Works

#### Step 1: Section Extraction

The agent parses `MEMORY.md` and splits on `## ` heading boundaries. Each heading becomes a discrete knowledge unit.

#### Step 2: Deterministic Domain Classification

Each section is classified using keyword matching against the heading text:

```
Heading: "## Infrastructure & Services"
         → matches keyword "infrastructure" → domain: infrastructure

Heading: "## Family Notes"
         → matches keyword "family" → domain: identity

Heading: "## Slack Channel Config"
         → matches keyword "config" → domain: infrastructure

Heading: "## Monthly Revenue Targets"
         → matches keyword "revenue" → domain: business
```

| Domain | Keyword Triggers |
|--------|-----------------|
| `identity` | personal, family, personality, preferences, professional network |
| `business` | business, revenue, company, SEO, brand, clients, product |
| `infrastructure` | services, cron, API, config, tools, issues |
| `community` | community, directory, meetup, group |
| `agents` | agent, task, sub-agent, monitoring |
| `legal` | legal, contract, compliance |
| `dates` | dates, anniversary, birthday |
| `general` | fallback for unmatched sections |

**Why deterministic keyword matching instead of LLM classification?** Consistency. An LLM might classify "Voice Reply Config" as `identity` in one run and `infrastructure` in the next. Memory migration must be idempotent — running it twice should produce identical results. Keyword matching is a lookup table, not a probabilistic judgment.

#### Step 3: File Tree Generation

Each section is written to `memory/domains/<domain>/<slugified-heading>.md`. The slug is derived from the heading: lowercased, special characters stripped, spaces replaced with hyphens, truncated to 60 characters.

```
"## GO Events Staff Roster (Updated 5 Mar 2026)"
→ memory/domains/business/go-events-staff-roster-updated-5-mar-2026.md
```

#### Step 4: Index Generation (Bottom-Up)

Indexes are generated at two levels:

**Branch `_index.md`** — For each domain directory:
```markdown
# Business Index
_Last indexed: 2026-03-11T09:41:41+08:00_
_Estimated tokens: ~723_

### company.md (~380 tokens)
Get Out! Events — events agency, 10+ years, ~$2M/year revenue, corporate & government clients.

### seo-config.md (~210 tokens)
Domain migration from getoutevents.com to getout.sg completed Feb 2026.

### staff-roster.md (~133 tokens)
12 staff members, 3 departments, updated March 2026.
```

**Root `_index.md`** (the trunk) — Aggregates all branches:
```markdown
# Memory Index
_Last indexed: 2026-03-11T09:41:41+08:00_
_Estimated tokens: ~2,984_

## Domains

### Identity (~529 tokens)
Felix Sim, Singaporean entrepreneur, Co-Founder of Get Out! Events.
_Also: preferences, family, professional-network_

### Business (~482 tokens)
Get Out! Events — events agency, corporate & government clients.
_Also: seo-config, staff-roster_

### Infrastructure (~1,851 tokens)
Vercel hosting, Supabase DB, GitHub repos, Slack, Linear.
_Also: known-issues, cron-config, api-keys_
```

Token estimates use the heuristic `ceil(character_count / 4)`, which is accurate to ±10% for English text across GPT and Claude tokenizers.

#### Step 5: MEMORY.md Replacement

The original `MEMORY.md` is backed up to `memory/MEMORY.md.bak`. The trunk index replaces `MEMORY.md`. This is what the agent loads on boot — typically **~300-500 tokens** regardless of total memory size.

### Semantic Search Compatibility

OpenClaw's `memory_search` uses embedding-based semantic search over all `.md` files in the `memory/` directory, recursively. The bonsai structure is fully transparent to the search layer — no configuration changes required. Files at `memory/domains/business/company.md` are indexed exactly the same as a flat `memory/company.md` would be.

This means the agent has **two retrieval paths**:

1. **Structured traversal**: Trunk → Branch → Leaf (for known-category lookups)
2. **Semantic search**: Direct query across all leaf files (for cross-cutting or fuzzy lookups)

Both paths coexist. The hierarchy optimizes boot cost; semantic search handles the long tail.

### Complexity Analysis

| Operation | Flat file | Bonsai Memory |
|-----------|-----------|---------------|
| Boot load | O(n) — full file | O(1) — trunk only (~400 tokens fixed) |
| Known-category lookup | O(n) — scan full file | O(1) — 3 reads max (~750 tokens) |
| Cross-cutting search | O(n) — semantic search | O(n) — semantic search (identical) |
| Write new fact | O(1) — append to file | O(1) — write to leaf + update branch index |
| Migration | N/A | O(n) — one-time, ~2 minutes |

The tradeoff: cross-cutting semantic search is unchanged (it must scan all files regardless), but the dominant operation — session boot — drops from O(n) to O(1).

### Why Not a Vector Database?

Markdown files are:
- **Grep-able** — `grep -r "keyword" memory/` works instantly
- **Git-able** — Full version history, diffs, branches, PRs
- **Human-readable** — Open in any editor, no special tooling
- **Search-compatible** — Works with OpenClaw's existing embedding-based `memory_search`
- **Zero-dependency** — No server, no connection string, no schema migrations

A vector database solves a different problem (similarity search over embeddings). Bonsai Memory solves the boot cost problem with zero infrastructure overhead.

---

## Installation

### Option 1: Install as an OpenClaw Skill

```bash
mkdir -p ~/.openclaw/workspace/skills/bonsai-memory
cp SKILL.md ~/.openclaw/workspace/skills/bonsai-memory/SKILL.md
```

Then tell your agent: *"Restructure your memory using the bonsai-memory skill."*

### Option 2: Manual — Give Your Agent the Instructions

Copy the content of [`SKILL.md`](SKILL.md) into your agent's context and ask it to follow the steps. No installation required.

### Option 3: Download the Skill Package

```bash
curl -LO https://github.com/felixsim/bonsai-memory/releases/download/v1.0.0/bonsai-memory.skill
unzip bonsai-memory.skill -d ~/.openclaw/workspace/skills/bonsai-memory/
```

---

## Compatibility

Works with any AI agent framework that uses file-based persistent memory:

- **[OpenClaw](https://openclaw.ai)** — Full native support. `memory_search` auto-discovers the tree.
- **Custom agent setups** — Any framework using markdown for agent memory or context injection.
- **Multi-agent systems** — Each agent migrates independently.

The migration is **idempotent** — safe to run multiple times. Existing leaf files are never overwritten.

---

## Examples

See the [`examples/`](examples/) directory:

- [`before-MEMORY.md`](examples/before-MEMORY.md) — A typical flat memory file
- [`after-MEMORY.md`](examples/after-MEMORY.md) — The slim trunk index that replaces it
- [`after-tree.txt`](examples/after-tree.txt) — The resulting bonsai structure

---

## FAQ

<details>
<summary><strong>Does this break existing memory search?</strong></summary>
No. OpenClaw's memory_search scans memory/*.md recursively. The new paths are automatically discovered.
</details>

<details>
<summary><strong>What if sections don't match any domain?</strong></summary>
They go into <code>general/</code>. You can manually re-classify after migration.
</details>

<details>
<summary><strong>Can I add new memory after migration?</strong></summary>
Yes. Create new .md files in the appropriate domain directory and re-run the indexing step to update the branch indexes.
</details>

<details>
<summary><strong>Does this work with non-OpenClaw agents?</strong></summary>
Yes. If your agent uses a flat file for persistent memory that gets loaded into context on boot, Bonsai Memory reduces that token load. The instructions are framework-agnostic.
</details>

<details>
<summary><strong>What about very small memory files?</strong></summary>
Below ~1,000 tokens, the overhead of the directory structure isn't worth the savings. The skill checks for this and recommends skipping.
</details>

---

## Contributing

Issues and PRs welcome. If you've adapted Bonsai Memory for another agent framework, open an issue — I'd love to hear about it.

---

## License

MIT — free to use, modify, and distribute.

---

*Built by [Felix Sim](https://sg.linkedin.com/in/simfelix) as a free contribution to the [OpenClaw](https://openclaw.ai) community.*
