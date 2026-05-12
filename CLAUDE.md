# LLM Wiki — Agile Edition

A pattern for building personal knowledge bases for agile software development,using LLMs and Graphify on Feishu (Lark) Drive.

## Skills in This Project

This project uses **two types of skills**. Understanding the difference prevents confusion:

### 1. Project-Specific Skill: `llm-wiki-agile`
- **What it does**: Provides wiki operations (init, ingest, query, sync, lint)
- **When to use**: When operating THIS wiki system
- **Examples**: "Ingest this PRD", "Query the wiki", "Sync code"
- **Location**: SKILL.md (this project only)

### 2. General Superpowers Skills
- **What they do**: Provide methodologies (brainstorming, debugging, TDD)
- **When to use**: For ANY software development task
- **Examples**: "How to approach this feature?", "Debug this error", "Plan implementation"
- **Location**: Superpowers ecosystem (universal)

### Quick Decision Guide
```
Is the request about wiki operations?
├─ Yes → Use llm-wiki-agile
└─ No → Use appropriate Superpower skill
   ├─ Creative work → superpowers:brainstorming
   ├─ Bug/failure → superpowers:systematic-debugging
   ├─ Implementation → superpowers:test-driven-development
   └─ Planning → superpowers:writing-plans
```

**See also**: SKILLS.md for complete skill taxonomy and interaction patterns.

## Core Idea

Traditional RAG rediscovers knowledge on every query. LLM Wiki is different: theLLM incrementally compiles raw sources (PRDs, code, meeting notes) into apersistent, compounding wiki — structured docx documents in Feishu Drive. Cross-references are maintained, contradictions flagged, synthesis kept current.

Three layers:
- **Raw sources** — curated, immutable. Lives in `raw/` subfolders.
- **The wiki** — LLM-generated docx in a Feishu Drive folder. LLM owns this entirely.
- **The schema** — this document. Tells the LLM how the wiki is structured.

## Architecture

```
raw/                    Feishu Drive wiki/              Graphify (local)
├── 10-product/         ├── index (docx)                graph.json
│   ├── prd/            ├── entities/                   GRAPH_REPORT.md
│   ├── user-stories/   ├── concepts/
│   └── epic/           ├── sources/
├── 20-design/          ├── syntheses/
│   ├── architecture/   └── log (docx)
│   └── api/
├── 30-development/
│   ├── git-repos/      (git pull → graphify build)
│   └── db-schemas/     (mysqldump → graphify build)
├── 40-process/
│   ├── meeting-notes/
│   └── decisions/
└── 50-research/
    ├── papers/
    └── articles/
```

**Key insight**: Graphify runs locally on raw/ to extract code AST + semanticentities. Its output (graph.json, GRAPH_REPORT.md) is parsed by the LLM andwritten back into Feishu wiki/ as docx pages. Feishu Drive is the single sourceof truth for human consumption; Graphify is the analysis engine.

## Entity Types

All typed entities use YAML frontmatter with `type: <EntityName>`. The systemrecognizes 19 entity types across 6 families:

### Structural — Product (manual frontmatter)
| Type | Purpose | Key Relations |
|------|---------|---------------|
| `ProductRequirement` | PRD document | decomposes_into → UserStory |
| `UserStory` | User story | belongs_to → Epic, implemented_by → Task |
| `Epic` | Epic/theme | contains → UserStory |
| `Task` | Development task | implements → UserStory, has_code → CodeModule |
| `Bug` | Defect | blocks → UserStory, fixed_by → PullRequest |

### Structural — Code (auto-extracted by Graphify AST)
| Type | Purpose | Key Relations |
|------|---------|---------------|
| `CodeModule` | File/class/module | imports → CodeModule, serves → APIEndpoint |
| `CodeFunction` | Function/method | belongs_to → CodeModule, calls → CodeFunction |
| `APIEndpoint` | HTTP endpoint | served_by → CodeModule, consumes → DataModel |
| `DataModel` | DB table/schema | supports → DomainConcept, queried_by → CodeModule |

### Structural — Git (synced from git log/API)
| Type | Purpose | Key Relations |
|------|---------|---------------|
| `PullRequest` | PR | implements → Task, modifies → CodeModule |
| `GitCommit` | Commit | part_of → PullRequest, modifies → CodeModule |

### Conceptual (LLM semantic extraction)
| Type | Purpose | Key Relations |
|------|---------|---------------|
| `DomainConcept` | Business/technical concept | used_in → UserStory, implemented_by → CodeFunction |
| `BusinessRule` | Business constraint | constrains → UserStory, enforced_in → CodeModule |
| `DesignPattern` | Architectural pattern | applied_in → CodeModule |

### Process (manual frontmatter)
| Type | Purpose | Key Relations |
|------|---------|---------------|
| `Sprint` | Iteration | contains → UserStory, contains → Task |
| `Meeting` | Meeting notes | discusses → ArchitectureDecision, reviews → Sprint |
| `ArchitectureDecision` | ADR | affects → CodeModule, decided_in → Meeting |
| `Release` | Release | includes → UserStory, deploys → CodeModule |

### People (config file)
| Type | Purpose | Key Relations |
|------|---------|---------------|
| `TeamMember` | Team member | owns → UserStory, authors → PullRequest |

## Frontmatter Convention

Every typed document in raw/ MUST include frontmatter. The `type` field ismandatory; other fields depend on the entity type. Use `related: [ID-001,ID-002]` to link related entities (auto-resolved to @mention-doc).

### Universal Template

```yaml
---
type: UserStory
id: US-001
title: "微信扫码登录"
status: done
priority: P1
tags: [登录, 微信, OAuth]
related: [PRD-001, TASK-042, API-005]
created_at: "2026-04-01"
updated_at: "2026-04-15"
# type-specific fields below
---
```

Entity types with full required/optional fields are defined in`schema/entities.yaml`.

## Operations

Six commands automate the wiki lifecycle. Run via shell scripts in `skill-core/`.

| Command | Purpose |
|---------|---------|
| `wiki-init` | Create Feishu Drive folder structure, index, log |
| `wiki-ingest <source>` | Ingest URL/file/Drive doc → raw/ → update wiki |
| `wiki-query "<question>"` | Query: graphify query + docs fetch → synthesize |
| `wiki-sync-code --repo <name>` | Git pull + graphify build → update code entities |
| `wiki-sync-db --conn <dsn>` | mysqldump schema + graphify → update data models |
| `wiki-lint` | Health check: orphans, stale graph, contradictions |

### Ingest Flow

```
source (URL/file/Drive) → LLM reads → discusses with user
→ writes typed doc with frontmatter to raw/
→ graphify build . --update (if code-related)
→ creates/updates wiki doc via lark-cli docs +create/update
→ updates index doc with @mention-doc links
→ appends log entry
```

### Query Flow

```
question → graphify query "question" (code structure)
→ lark-cli drive +search (text search)
→ docs +fetch relevant pages
→ LLM synthesizes answer with citations
→ optional: files answer back to wiki as new page
```

### Sync Flow (Code)

```
git -C raw/30-development/git-repos/<repo> pull
→ graphify build . --update
→ LLM reads GRAPH_REPORT.md + graph.json changes
→ updates wiki/entities/ for changed CodeModule/CodeFunction
→ detects God Nodes / Surprise Edges / new communities
→ writes summary to log
```

## Index & Log

**index** (docx in wiki folder): Content-oriented catalog. Lists every page with`@mention-doc` link, one-line summary, type, status, date. Updated on everyingest. LLM reads this first when answering queries.

**log** (docx in wiki folder): Append-only chronological record. Format:`## [YYYY-MM-DD] <operation> | <description>`. Used for timeline tracking andresuming sessions.

## Tips

- **web-access skill** is the primary source intake method. Fetches URLs,converts to Lark-flavored Markdown, then `docs +create` into wiki.
- **@mention-doc** for cross-references: `<mention-doc token="doxcnXXX"type="docx">Title</mention-doc>`. Extract token from Feishu URL.
- **Images**: Remote via `<image url="https://..."/>`; local via `drive+upload` then `docs +media-insert`.
- **Folder structure as navigation**: Since we use Drive folder (not WikiSpace), subfolders (`entities/`, `concepts/`, `sources/`) provide structure.Use `drive files list` to browse.
- **Version history**: Built into Feishu docs. No git needed for wiki itself.For offline backup, use `drive +export` periodically.
- **Comments as signals**: Use `drive +add-comment` to flag contradictions ormark pages for review.

## Why This Works

The tedious part of knowledge maintenance is bookkeeping — updating cross-references, noting contradictions, keeping summaries current. LLMs don't getbored and can touch 15 docs in one pass. Graphify adds structural awareness(code dependencies, architecture hotspots) that pure LLM analysis misses.Together they handle the maintenance; humans curate sources and ask questions.

## Note

This document is intentionally a pattern, not an implementation. Pick what'suseful, ignore what isn't. The exact folder structure, entity types, pageformats — all depend on your domain. Share this with your LLM agent andcollaborate to instantiate a version that fits your needs. Your LLM can figureout the rest.
