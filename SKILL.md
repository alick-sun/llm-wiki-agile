---
name: llm-wiki-agile
category: project-specific
description: |
  **[PROJECT-SPECIFIC SKILL]** Operate a personal knowledge base for agile
  software development. This skill provides domain-specific commands for the
  LLM Wiki system only. Use when user wants to: ingest PRDs/user stories/meeting
  notes, query project knowledge, sync code repositories into graph, export
  database schemas, run health checks on wiki, or manage team documentation.

  **NOT a general methodology skill** — this is a tool for this specific project.
  For general workflow/methodology questions (TDD, debugging, planning), use
  Superpowers skills instead.

  Triggers on phrases like "wiki", "ingest", "sync code", "knowledge base",
  "entity", "PRD", "user story", "meeting notes", "architecture decision", or
  "code graph" in the context of this project.
when_to_use: |
  Trigger this skill when the user:
  - Mentions "wiki", "knowledge base", "知识库" in the context of THIS project
  - Asks to ingest, add, or import documents to THE WIKI
  - Asks to query, search, or find information IN THE WIKI
  - Mentions syncing code, updating code graph for THIS project
  - Asks about database schema or entity relationships IN THIS WIKI
  - Asks to check, lint, or validate wiki health
  - References wiki entity types: UserStory, Task, Bug, Meeting, ADR, CodeModule

  **DO NOT trigger** for general methodology questions like:
  - "How should I implement this feature?" → Use superpowers:brainstorming
  - "This code has a bug" → Use superpowers:systematic-debugging
  - "Should we use TDD?" → Use superpowers:test-driven-development
argument-hint: "[command] [args...]"
arguments:
  - command
  - args
user-invocable: true
disable-model-invocation: false
see_also:
  - superpowers:brainstorming
  - superpowers:systematic-debugging
  - SKILLS.md (full skill taxonomy)
---

# LLM Wiki — Agile Edition

You operate a personal knowledge base for agile software development, stored inFeishu (Lark) Drive with integrated code graph analysis via Graphify.

## Architecture

Three layers:
- **raw/** — immutable source documents (PRDs, code, meeting notes, DB schemas)
- **wiki/** — Feishu Drive folder with LLM-generated docx documents
- **schema** — entity type definitions and frontmatter conventions

```
raw/                              Feishu Drive wiki/
├── 10-product/                   ├── index (docx catalog)
│   ├── prd/                      ├── entities/
│   ├── user-stories/             ├── concepts/
│   ├── epics/                    ├── sources/
│   ├── tasks/                    ├── syntheses/
│   └── bugs/                     └── log (docx timeline)
├── 20-design/
│   ├── architecture/
│   └── api/
├── 30-development/
│   ├── git-repos/      ← graphify build
│   └── db-schemas/     ← mysqldump
├── 40-process/
│   ├── meeting-notes/
│   └── decisions/
└── 50-research/
```

## Commands

Use the following commands to operate the wiki. Each command maps to a script
in the `scripts/` directory.

### `/wiki-init` — Initialize wiki folder structure

Run once to set up the Feishu Drive folder and local directory structure.

```bash
scripts/wiki-init.sh [--name <folder_name>] [--parent <parent_folder_token>]
```

What it does:
1. Creates `LLM-Wiki` folder in Feishu Drive
2. Creates subfolders (`10-product/`, `20-design/`, `30-development/`, etc.)
3. Creates `index` and `log` docx documents in Feishu
4. Creates local `raw/` directory structure
5. Saves configuration to `config/wiki-config.json`

### `/wiki-ingest` — Ingest a new source

Add PRDs, meeting notes, research articles, or any document to the wiki.

```bash
scripts/wiki-ingest.sh <source> [--type <entity_type>] [--title <title>]
```

Parameters:
- `<source>`: URL, local file path, or Feishu Drive folder token
- `--type`: One of ProductRequirement, UserStory, Epic, Task, Bug, Meeting,ArchitectureDecision, Sprint, ResearchNote
- `--title`: Title for the wiki document

What it does:
1. Fetches/copies source to appropriate `raw/` subfolder
2. Adds YAML frontmatter if missing
3. Creates docx document in Feishu wiki via lark-cli
4. Updates index with @mention-doc link
5. Appends log entry

### `/wiki-query` — Query the wiki

Ask questions against both the Feishu documents and the Graphify code graph.

```bash
scripts/wiki-query.sh "<question>" [--save] [--title <title>]
```

Parameters:
- `"<question>"`: Natural language question
- `--save`: Save the answer as a new wiki page
- `--title`: Title for saved answer page

What it does:
1. Runs `graphify query` on code repos (if available)
2. Runs `lark-cli drive +search` on Feishu documents
3. Fetches top matching documents
4. Synthesizes answer with citations from both sources

### `/wiki-sync-code` — Sync code repositories

Pull latest code and rebuild the Graphify code graph.

```bash
scripts/wiki-sync-code.sh [--repo <repo_name>] [--all] [--force]
```

Parameters:
- `--repo`: Sync specific repo by name
- `--all`: Sync all configured repos
- `--force`: Force rebuild even if cache is fresh

What it does:
1. `git pull` in specified repo(s)
2. `graphify build . --update` to rebuild code graph
3. Extracts God Nodes, communities, surprise edges from GRAPH_REPORT
4. Updates or creates CodeModule/CodeFunction entity pages in wiki
5. Appends sync summary to log

### `/wiki-sync-db` — Export database schema

Export database DDL and sync DataModel entities to wiki.

```bash
scripts/wiki-sync-db.sh --conn <connection_string> --name <db_name> [--type <db_type>]
```

Parameters:
- `--conn`: Database connection string (e.g. `postgresql://user:pass@host/db`)
- `--name`: Database name/label
- `--type`: Database type (PostgreSQL, MySQL). Default: PostgreSQL

What it does:
1. `pg_dump --schema-only` or `mysqldump --no-data`
2. `graphify build` on DDL files
3. Extracts table/column metadata
4. Creates/updates DataModel entity pages in wiki

### `/wiki-lint` — Health check the wiki

Run comprehensive health checks across structure, graph, and content.

```bash
scripts/wiki-lint.sh [--fix] [--focus <area>]
```

Parameters:
- `--fix`: Attempt automatic fixes
- `--focus`: Check area — `all` (default), `structure`, `graph`, `content`

What it checks:
- Structure: orphan pages, folder integrity, config completeness
- Graph: stale graph cache, missing graphify output, God Nodes
- Content: untyped documents, stale log, broken @mention-doc links

## Entity Types

All typed documents use YAML frontmatter with `type: <EntityName>`. When creatingany document for the wiki, include proper frontmatter.

### Core Entities (19 types across 6 families)

**Structural — Product** (manual frontmatter):
| Type | Identifier | Raw Location |
|------|-----------|--------------|
| ProductRequirement | `type: ProductRequirement` | `10-product/prd/` |
| UserStory | `type: UserStory` | `10-product/user-stories/` |
| Epic | `type: Epic` | `10-product/epics/` |
| Task | `type: Task` | `10-product/tasks/` |
| Bug | `type: Bug` | `10-product/bugs/` |

**Structural — Code** (auto-extracted by Graphify):
| Type | Identifier | Source |
|------|-----------|--------|
| CodeModule | `type: CodeModule` | Graphify AST |
| CodeFunction | `type: CodeFunction` | Graphify AST |
| APIEndpoint | `type: APIEndpoint` | AST + OpenAPI |
| DataModel | `type: DataModel` | DDL AST |

**Structural — Git** (synced from git log):
| Type | Identifier | Source |
|------|-----------|--------|
| PullRequest | `type: PullRequest` | Git API |
| GitCommit | `type: GitCommit` | Git log |

**Conceptual** (LLM semantic extraction):
| Type | Identifier | Source |
|------|-----------|--------|
| DomainConcept | `type: DomainConcept` | LLM auto-extract |
| BusinessRule | `type: BusinessRule` | LLM auto-extract |
| DesignPattern | `type: DesignPattern` | LLM auto-extract |

**Process** (manual frontmatter):
| Type | Identifier | Raw Location |
|------|-----------|--------------|
| Sprint | `type: Sprint` | `40-process/sprints/` |
| Meeting | `type: Meeting` | `40-process/meeting-notes/` |
| ArchitectureDecision | `type: ArchitectureDecision` | `40-process/decisions/` |
| Release | `type: Release` | `40-process/releases/` |

**People** (defined in config):
| Type | Identifier | Source |
|------|-----------|--------|
| TeamMember | `type: TeamMember` | `config/project-config.yaml` |

Full entity definitions with all attributes and relations: `references/entities.yaml`

## Frontmatter Templates

### Universal Template (all types)

```yaml
---
type: UserStory
id: US-001
title: "微信扫码登录"
status: todo
priority: P1
tags: [登录, 微信, OAuth]
related: [PRD-001, TASK-042, API-005]
created_at: "2026-05-11"
---
```

### Type-Specific Fields

**UserStory** adds: `us_id, epic, sprint, story_points, assignee, acceptance_criteria[], version_affected[]`

**Task** adds: `task_id, task_type[dev/test/doc/ops], parent_us, estimated_hours, actual_hours, due_date, git_branch, pr_url`

**Bug** adds: `bug_id, severity[critical/high/medium/low], environment, reproduce_steps, root_cause, affected_versions[], reporter, assignee`

**Meeting** adds: `meeting_id, meeting_type[standup/planning/review/retrospective], date, attendees[], duration_min, agenda[], decisions[], action_items[]`

**ArchitectureDecision** adds: `adr_id, status[proposed/accepted/deprecated/superseded], context, decision, consequences[positive/negative], alternatives_considered[], deciders[]`

**CodeModule** adds: `module_name, language, repo, path, lines_of_code, god_node_rank, import_count, imported_by_count, last_commit_hash, last_commit_date`

**DataModel** adds: `model_name, db_type, schema, fields[{name,type,constraints}], indexes, estimated_rows, last_migration`

Full templates for each type: `references/frontmatter-templates/`

## Cross-Reference Syntax

**In Feishu docx** (Lark-flavored Markdown):
```markdown
<mention-doc token="doxcnXXX" type="docx">Title</mention-doc>
```

**In frontmatter related field**:
```yaml
related: [PRD-001, TASK-042, US-003]  # LLM resolves to doc tokens
```

**In raw markdown**:
```markdown
See also: [[US-001]]  # Wiki-link style, LLM converts to @mention-doc
```

## Key Conventions

1. **Every typed document MUST have frontmatter** with at least `type` and `id` fields
2. **Use kebab-case IDs**: `US-001`, `TASK-042`, `BUG-018`, `ADR-003`
3. **@mention-doc for all cross-references** between wiki pages
4. **Images**: Remote `<image url="https://..."/>`, local via `drive +upload` then `docs +media-insert`
5. **Index doc**: Content catalog, updated on every ingest
6. **Log doc**: Append-only chronological record, format `## [YYYY-MM-DD] operation | description`
7. **Graphify runs locally** on `raw/30-development/git-repos/`, output goes to `graphify-out/`
8. **Git repos**: Clone into `raw/30-development/git-repos/<name>/`, managed as normal git repos
9. **Database schemas**: Export via `mysqldump --no-data` or `pg_dump --schema-only` to `raw/30-development/db-schemas/`
10. **Comments as signals**: Use `drive +add-comment` to flag contradictions or mark pages for review

## Workflows

### Ingest Flow

```
User provides source → wiki-ingest
  → Write to raw/ with frontmatter
  → If code-related: graphify build . --update
  → Create docx in Feishu wiki via lark-cli docs +create
  → Update index with @mention-doc link
  → Append to log
  → LLM: discuss key takeaways with user
```

### Query Flow

```
User asks question → wiki-query
  → graphify query "question" (code structure insights)
  → lark-cli drive +search (Feishu document search)
  → docs +fetch top documents
  → LLM synthesizes answer with citations
  → Optional: save answer as new wiki page
```

### Code Sync Flow

```
User: sync code → wiki-sync-code --repo backend
  → git pull
  → graphify build . --update
  → Read GRAPH_REPORT.md for God Nodes / communities / surprise edges
  → Update affected CodeModule/CodeFunction entity pages
  → Update log with sync summary
```

### Lint Flow

```
User: check wiki health → wiki-lint
  → Check structure: orphan pages, folder integrity
  → Check graph: stale cache, missing Graphify output
  → Check content: untyped docs, stale log, broken links
  → Generate report doc in wiki
  → If --fix: attempt automatic repairs
```

## Prerequisites

| Tool | Install Command | Purpose |
|------|----------------|---------|
| lark-cli | `npm install -g @larksuite/cli` | Feishu Drive/Doc operations |
| graphify | `npm install -g @graphify-labs/graphify` | Code graph analysis |
| git | `brew/apt install git` | Repo management |
| jq | `brew/apt install jq` | JSON config parsing |

Authentication: `lark-cli config init --new && lark-cli auth login`

## File Reference

| File | Purpose |
|------|---------|
| `scripts/wiki-init.sh` | Initialize wiki structure |
| `scripts/wiki-ingest.sh` | Ingest sources |
| `scripts/wiki-query.sh` | Query wiki |
| `scripts/wiki-sync-code.sh` | Sync code + rebuild graph |
| `scripts/wiki-sync-db.sh` | Export DB schema |
| `scripts/wiki-lint.sh` | Health check |
| `references/entities.yaml` | Full entity type definitions |
| `references/frontmatter-templates/` | Frontmatter templates per type |
| `config/wiki-config.json` | Runtime state (auto-generated) |
| `config/project-config.yaml` | Team config (user-edited) |
