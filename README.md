# 🌳 Memory Tree

**Hierarchical memory for OpenClaw agents.**

Replace your monolithic `MEMORY.md` with a domain-based context tree. Your agent loads a ~400-token index on boot instead of the full file — and searches for details only when it needs them.

> Built because ByteRover charges $15/month for something your agent can do itself in 2 minutes.

---

## The Problem

OpenClaw's default memory is a single flat file: `MEMORY.md`. Every session, every agent, every boot — the entire file gets loaded into context. A typical workspace accumulates 5,000-10,000+ tokens of memory. Most of it is irrelevant to the current task.

That's dead token weight on every single interaction.

## The Solution

Memory Tree restructures your flat file into a hierarchical domain tree:

```
memory/
├── _index.md                  ← ~400 tokens, loaded on boot
├── domains/
│   ├── identity/
│   │   ├── _index.md          ← domain summary
│   │   ├── personal.md
│   │   ├── family.md
│   │   └── preferences.md
│   ├── business/
│   │   ├── _index.md
│   │   ├── company.md
│   │   └── seo/
│   │       ├── main-site.md
│   │       └── blog.md
│   ├── infrastructure/
│   │   ├── _index.md
│   │   ├── services.md
│   │   └── issues.md
│   └── ...
├── dates.md
└── daily/                     ← existing daily logs, untouched
    └── YYYY-MM-DD.md
```

The root `_index.md` contains one-line summaries of each domain. Domain `_index.md` files contain one-line summaries of each topic. The agent reads the root on boot, then drills into specific domains only when a task requires it.

**OpenClaw's `memory_search` works out of the box** — it already searches `memory/*.md` recursively. No configuration changes needed.

## How It Works

This isn't a tool, a CLI, or a SaaS product. It's a **skill** — a set of instructions that any OpenClaw agent can follow to restructure its own memory.

The agent:

1. **Reads** its `MEMORY.md` and counts sections
2. **Classifies** each `## Section` into a domain (identity, business, infrastructure, etc.) using keyword matching
3. **Splits** each section into its own file under `memory/domains/<domain>/`
4. **Generates indexes** — `_index.md` at each level with token counts and one-line summaries
5. **Replaces** `MEMORY.md` with the slim root index (~400 tokens)

Original content is preserved in `memory/MEMORY.md.bak`. Nothing is lost, summarized, or truncated during migration.

### Domain Classification

Sections are classified by keywords in their headings:

| Domain | Matches |
|--------|---------|
| `identity` | personal, family, personality, preferences, professional network |
| `business` | business, revenue, company, SEO, brand, clients, product |
| `infrastructure` | services, cron, voice, API, config, tools, issues |
| `community` | community, directory, meetup, group |
| `agents` | agent, task, sub-agent, monitoring |
| `legal` | legal, contract, compliance |
| `dates` | dates, remember, anniversary, birthday |
| `general` | everything else |

Subdomain nesting is supported (e.g., `business/seo/main-site.md`) for sections that clearly belong to a sub-category.

## Results

Tested across 9 agents in production:

| Agent | Before | After | Reduction |
|-------|--------|-------|-----------|
| Chuck (main) | ~6,400 tokens | ~385 tokens | **94%** |
| Evelyn (ops) | ~2,764 tokens | ~367 tokens | **87%** |
| Matt (SEO) | ~2,732 tokens | ~373 tokens | **87%** |
| Mira (content) | ~1,945 tokens | ~271 tokens | **86%** |
| Alfred (school) | ~1,450 tokens | ~296 tokens | **80%** |
| Ray (code) | ~1,012 tokens | ~249 tokens | **75%** |
| Alex (research) | ~939 tokens | ~316 tokens | **66%** |
| Lewis (LinkedIn) | ~899 tokens | ~218 tokens | **76%** |

Average: **81% reduction** in boot memory token load.

## Installation

### Option 1: Install as OpenClaw Skill

```bash
# Copy SKILL.md into your skills directory
cp SKILL.md ~/.openclaw/workspace/skills/memory-tree/SKILL.md
```

Then tell your agent: *"Restructure your memory using the memory-tree skill."*

### Option 2: Manual — Just Give Your Agent the Instructions

Copy the content of [`SKILL.md`](SKILL.md) into your agent's context and ask it to follow the steps. No installation required. The instructions are self-contained.

### Option 3: Install from ClawHub

```
openclaw skill install memory-tree
```

*(Coming soon)*

## Architecture Decisions

**Why a skill, not a script?**
Scripts are brittle — they hardcode paths, assume directory structures, break across OS versions. A skill is a set of instructions that any LLM agent can interpret and adapt to its own workspace. The agent handles edge cases, naming conflicts, and unusual section structures naturally. It's more resilient than any bash script.

**Why keyword-based classification instead of LLM-based?**
Determinism. Keyword matching produces consistent results across runs. An LLM might classify "Voice Reply Config" as `identity` one day and `infrastructure` the next. The keyword table is a lookup, not a judgment call.

**Why not a database?**
Markdown files are grep-able, git-able, human-readable, and work with OpenClaw's existing `memory_search` (which uses embedding-based semantic search over .md files). A database adds a dependency for zero benefit.

**Why per-domain indexes instead of one big index?**
Progressive disclosure. The root index tells the agent *what domains exist*. A domain index tells it *what topics exist in that domain*. The topic file gives the actual content. The agent traverses only the branch it needs. Three reads max for any fact lookup: root → domain → topic.

**Why preserve the original?**
Rollback. If something breaks, `cp memory/MEMORY.md.bak MEMORY.md` and you're back to exactly where you started.

## Comparison

| | Flat MEMORY.md | ByteRover ($15/mo) | Memory Tree (free) |
|---|---|---|---|
| Boot tokens | Full file every time | Loads relevant subtree | ~400 token index |
| Search | Semantic (memory_search) | LLM-powered (brv query) | Semantic (memory_search) |
| Write | Manual edit | brv curate (LLM decides) | Manual edit |
| Structure | Single file | `.brv/context-tree/` | `memory/domains/` |
| Dependencies | None | CLI + cloud account | None |
| Cost | Free | $14.90/month | Free |
| Migration | N/A | Their CLI | Your agent does it |

## FAQ

**Does this break `memory_search`?**
No. OpenClaw's memory_search already scans `memory/*.md` recursively. The new file paths are automatically discovered.

**What if my MEMORY.md has unusual sections?**
Sections that don't match any keyword domain go into `general/`. You can manually re-classify after migration.

**Can I add new memory after migration?**
Yes. Create new `.md` files in the appropriate domain directory. Re-run the indexing step (Step 10 in SKILL.md) to update the `_index.md` files.

**What about agents with very small MEMORY.md (<1,000 tokens)?**
The skill checks for this and recommends skipping migration if it's not worth it.

## License

MIT. Use it, fork it, improve it.

---

*Built by [Felix Sim](https://felixsim.com) as a contribution to the [OpenClaw](https://openclaw.ai) community.*
