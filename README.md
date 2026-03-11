# 🌳 Memory Tree — Hierarchical Memory for AI Agents

**Reduce your AI agent's context window token usage by 70-95%.** Memory Tree restructures flat memory files into a domain-based hierarchy that loads a slim index on boot and searches for details on demand.

Built for [OpenClaw](https://openclaw.ai) agents. Works with any LLM agent framework that uses persistent memory files.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/felixsim/memory-tree)](https://github.com/felixsim/memory-tree/releases)

---

## Why Memory Tree?

AI agents that use persistent memory — whether via `MEMORY.md`, long-term context files, or any file-based memory system — face a fundamental problem: **every boot loads the entire memory into the context window**, regardless of what the current task needs.

A typical agent accumulates 5,000–10,000+ tokens of memory. Most of it is irrelevant to any single interaction. That's dead weight in every API call — burning tokens, increasing latency, and reducing the space available for actual reasoning.

Memory Tree solves this with **progressive disclosure**: load a ~400-token index on boot, then drill into specific domains only when the task requires it. Three reads maximum for any fact lookup.

### Token Optimization Results

Tested across 9 production AI agents:

| Agent | Before | After | Reduction |
|-------|--------|-------|-----------|
| Main (chief of staff) | ~6,400 tokens | ~385 tokens | **94%** |
| Ops agent | ~2,764 tokens | ~367 tokens | **87%** |
| SEO agent | ~2,732 tokens | ~373 tokens | **87%** |
| Content agent | ~1,945 tokens | ~271 tokens | **86%** |
| School agent | ~1,450 tokens | ~296 tokens | **80%** |
| Code agent | ~1,012 tokens | ~249 tokens | **75%** |
| Research agent | ~939 tokens | ~316 tokens | **66%** |
| LinkedIn agent | ~899 tokens | ~218 tokens | **76%** |

**Average: 81% reduction** in boot memory token load.

---

## How It Works

Memory Tree converts a flat memory file into a hierarchical domain tree:

```
Before:                          After:
                                 
MEMORY.md (6,400 tokens)  →     memory/
├── ## Identity                  ├── _index.md (~400 tokens, loaded on boot)
├── ## Business                  ├── domains/
├── ## Infrastructure            │   ├── identity/
├── ## Family                    │   │   ├── _index.md
├── ## Network                   │   │   ├── personal.md
├── ## Known Issues              │   │   ├── family.md
├── ## Dates                     │   │   └── preferences.md
└── ## ... (15 more sections)    │   ├── business/
                                 │   │   ├── _index.md
                                 │   │   ├── company.md
                                 │   │   └── clients.md
                                 │   └── infrastructure/
                                 │       ├── _index.md
                                 │       ├── services.md
                                 │       └── known-issues.md
                                 ├── dates.md
                                 └── daily/
                                     └── YYYY-MM-DD.md
```

### Architecture: Progressive Disclosure

The key insight is **three-level progressive disclosure**:

1. **Root index** (~400 tokens) — Loaded on every boot. One-line summary per domain with token counts.
2. **Domain index** (~100-200 tokens) — Loaded when the agent needs a specific domain. One-line summary per topic file.
3. **Topic file** (variable) — Loaded only when the agent needs that specific fact.

This means the agent traverses at most three reads to find any piece of stored knowledge: root → domain → topic. The context window carries only what's relevant to the current task.

### Domain Classification

Each `## Section` in the original memory file is classified into a domain using deterministic keyword matching:

| Domain | Matches |
|--------|---------|
| `identity` | personal, family, personality, preferences, professional network |
| `business` | business, revenue, company, SEO, brand, clients, product |
| `infrastructure` | services, cron, API, config, tools, issues |
| `community` | community, directory, meetup, group |
| `agents` | agent, task, sub-agent, monitoring |
| `legal` | legal, contract, compliance |
| `dates` | dates, anniversary, birthday |
| `general` | anything that doesn't match above |

**Why keyword-based, not LLM-based?** Determinism. Keyword matching produces consistent results across runs. An LLM might classify "Voice Config" as `identity` one day and `infrastructure` the next. Classification should be a lookup, not a judgment call.

---

## Installation

### Option 1: Install as an OpenClaw Skill

```bash
mkdir -p ~/.openclaw/workspace/skills/memory-tree
cp SKILL.md ~/.openclaw/workspace/skills/memory-tree/SKILL.md
```

Then tell your agent:

> *"Restructure your memory using the memory-tree skill."*

The agent reads the instructions and performs the migration autonomously.

### Option 2: Manual — Just Give Your Agent the Instructions

Copy the content of [`SKILL.md`](SKILL.md) into your agent's prompt or context, and ask it to follow the steps. No installation required. The instructions are completely self-contained.

### Option 3: Download the Skill Package

Grab the `.skill` file from the [latest release](https://github.com/felixsim/memory-tree/releases):

```bash
# Download and extract
curl -LO https://github.com/felixsim/memory-tree/releases/download/v1.0.0/memory-tree.skill
unzip memory-tree.skill -d ~/.openclaw/workspace/skills/memory-tree/
```

---

## Design Decisions

### Why a Skill, Not a Script?

Scripts are brittle — they hardcode paths, assume directory structures, and break across environments. A skill is a set of instructions that any LLM agent can interpret and adapt to its own workspace. The agent handles edge cases, naming conflicts, and unusual section structures naturally. It's more resilient than any bash script, and it's portable to any device without modification.

### Why Not a Database?

Markdown files are grep-able, git-able, human-readable, and work with semantic search tools out of the box. OpenClaw's `memory_search` uses embedding-based semantic search over `.md` files recursively — the tree structure is fully compatible with zero configuration changes. A database adds a dependency for no benefit.

### Why Per-Domain Indexes?

Progressive disclosure. The root index tells the agent *what domains exist* (~400 tokens). A domain index tells it *what topics exist in that domain* (~100 tokens). The topic file gives the actual content. The agent only ever loads the branch it needs — not the entire tree.

### Why Preserve the Original?

Rollback safety. The original `MEMORY.md` is backed up to `memory/MEMORY.md.bak` before any changes. If something goes wrong: `cp memory/MEMORY.md.bak MEMORY.md` and you're back to exactly where you started.

---

## Compatibility

Memory Tree works with any AI agent framework that uses file-based persistent memory:

- **[OpenClaw](https://openclaw.ai)** — Full native support. `memory_search` auto-discovers the new tree structure.
- **Custom agent setups** — Any framework using markdown files for agent memory or context injection.
- **Multi-agent systems** — Each agent migrates independently. Shared memory can use the same domain structure.

The migration is **idempotent** — safe to run multiple times. Existing domain files are never overwritten.

---

## Examples

See the [`examples/`](examples/) directory:

- [`before-MEMORY.md`](examples/before-MEMORY.md) — A typical flat memory file (~1,400 tokens)
- [`after-MEMORY.md`](examples/after-MEMORY.md) — The slim root index that replaces it (~200 tokens)
- [`after-tree.txt`](examples/after-tree.txt) — The resulting directory structure

---

## FAQ

**Does this break existing memory search?**
No. OpenClaw's `memory_search` scans `memory/*.md` recursively. The new file paths are automatically discovered.

**What if my MEMORY.md has unusual section structures?**
Sections that don't match any keyword domain go into `general/`. You can manually re-classify after migration.

**Can I add new memory after migration?**
Yes. Create new `.md` files in the appropriate domain directory. Re-run the indexing step to update the `_index.md` files.

**Does this work with AI agents that aren't OpenClaw?**
Yes. If your agent uses a flat file for persistent memory and loads it into context on boot, Memory Tree will reduce that token load. The SKILL.md instructions are framework-agnostic.

**What about very small memory files (<1,000 tokens)?**
The skill checks for this and recommends skipping migration. Below ~1,000 tokens, the overhead of the directory structure isn't worth the savings.

---

## Contributing

Issues and PRs welcome. If you've adapted Memory Tree for another agent framework, I'd love to hear about it.

---

## License

MIT — free to use, modify, and distribute.

---

*Built by [Felix Sim](https://sg.linkedin.com/in/simfelix) as a contribution to the [OpenClaw](https://openclaw.ai) community.*
