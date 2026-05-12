# LLM Wiki — Agile Edition

> A personal knowledge base for agile software development, powered by LLMs and Graphify on Feishu Drive.

## 🚀 Quick Start

```bash
# 1. Initialize wiki
scripts/wiki-init.sh --name "My-Wiki"

# 2. Ingest documents
scripts/wiki-ingest.sh https://doc-url --type ProductRequirement

# 3. Query knowledge
scripts/wiki-query.sh "How does user authentication work?"

# 4. Sync code repositories
scripts/wiki-sync-code.sh --all
```

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **README.md** (this) | Project overview and quick start |
| **CLAUDE.md** | Architecture, entity types, operations |
| **SKILL.md** | Wiki operation skill definition |
| **SKILLS.md** | Complete skill taxonomy and usage guide |
| **schema/entities.yaml** | All 19 entity type definitions |

## 🏗️ Architecture

```
raw/ (sources) → wiki/ (Feishu docs) ← Graphify (code analysis)
```

- **raw/**: Immutable source documents (PRDs, code, meeting notes)
- **wiki/**: LLM-generated docx documents in Feishu Drive
- **graph.json**: Code structure graph from Graphify

### Three Layers
1. **Raw Sources** — Curated, immutable. Lives in `raw/` subfolders.
2. **The Wiki** — LLM-generated docx in Feishu Drive. LLM owns this.
3. **The Schema** — Entity types and relationships (19 types, 6 families).

## 🎯 Entity Types (19 across 6 families)

| Family | Types |
|--------|-------|
| **Structural — Product** | ProductRequirement, UserStory, Epic, Task, Bug |
| **Structural — Code** | CodeModule, CodeFunction, APIEndpoint, DataModel |
| **Structural — Git** | PullRequest, GitCommit |
| **Conceptual** | DomainConcept, BusinessRule, DesignPattern |
| **Process** | Sprint, Meeting, ArchitectureDecision, Release |
| **People** | TeamMember |

See `schema/entities.yaml` for complete definitions with frontmatter fields.

## 🛠️ Operations

Six commands automate the wiki lifecycle:

| Command | Purpose | Example |
|---------|---------|---------|
| `wiki-init` | Initialize wiki folder structure | `wiki-init.sh --name "Team-Wiki"` |
| `wiki-ingest` | Ingest URL/file/Drive doc → raw/ → wiki | `wiki-ingest.sh prd.pdf --type ProductRequirement` |
| `wiki-query` | Query: graphify + docs → synthesize | `wiki-query.sh "API authentication flow"` |
| `wiki-sync-code` | Git pull + graphify build → update entities | `wiki-sync-code.sh --repo backend` |
| `wiki-sync-db` | mysqldump schema + graphify → update models | `wiki-sync-db.sh --conn $DB_URL --name users` |
| `wiki-lint` | Health check: orphans, stale graph, contradictions | `wiki-lint.sh --fix` |

## 🧠 Skills System

This project uses **two types of skills**. See [SKILLS.md](SKILLS.md) for details.

### Project-Specific Skill
- **`llm-wiki-agile`**: Wiki operations (init/ingest/query/sync/lint)
- Use for: Operating THIS wiki system
- Trigger: `/wiki-*` commands, mentions of "wiki", "ingest", "knowledge base"

### General Superpowers Skills
- **`superpowers:brainstorming`**: Explore requirements before implementation
- **`superpowers:systematic-debugging`**: Debug bugs systematically
- **`superpowers:test-driven-development`**: TDD workflow
- Use for: Methodology, workflow, process (any project)

**Key distinction**: Project skills provide domain commands; Superpowers provide methodologies.

## 📝 Conventions

### Frontmatter
Every typed document MUST include YAML frontmatter:

```yaml
---
type: UserStory
id: US-001
title: "微信扫码登录"
status: todo
priority: P1
tags: [登录, 微信, OAuth]
related: [PRD-001, TASK-042]
created_at: "2026-05-11"
---
```

### Cross-References
- In Feishu docx: `<mention-doc token="doxcnXXX" type="docx">Title</mention-doc>`
- In frontmatter: `related: [US-001, PRD-002]`
- Wiki-link style: `[[US-001]]` (LLM converts to @mention-doc)

### Directory Structure
```
raw/
├── 10-product/          # PRDs, user stories, epics, tasks, bugs
├── 20-design/           # Architecture, API specs, UI/UX
├── 30-development/      # Git repos, code snippets, DB schemas
├── 40-process/          # Meeting notes, sprints, decisions, PRs
└── 50-research/         # Papers, articles, competitors
```

## 🎯 Why This Works

Traditional RAG rediscovers knowledge on every query. LLM Wiki is different:

1. **Incremental compilation** — LLM compiles raw sources into persistent wiki
2. **Cross-reference maintenance** — LLM updates links automatically
3. **Contradiction detection** — LLM flags conflicts across documents
4. **Graphify integration** — Code structure awareness (AST, dependencies)
5. **Human-in-the-loop** — Humans curate sources, LLM handles bookkeeping

The tedious parts (updating cross-references, noting contradictions, keeping summaries current) are automated. Humans focus on curation and questions.

## 🔧 Prerequisites

### Quick Setup (Recommended)
```bash
# Run one-time setup (installs missing tools automatically)
./scripts/setup.sh

# Verify environment
./scripts/check-env.sh
```

### Manual Installation

| Tool | Install | Purpose |
|------|---------|---------|
| lark-cli | `npm install -g @larksuite/cli` | Feishu Drive/Doc operations |
| graphify | `npm install -g @graphify-labs/graphify` | Code graph analysis |
| git | `choco install git` (Windows) | Repo management |
| jq | `choco install jq` (Windows) | JSON parsing |

**See [INSTALL.md](INSTALL.md)** for detailed installation instructions and troubleshooting.

**Authentication**: `lark-cli auth login`

## 📖 Next Steps

1. **Initialize**: Run `scripts/wiki-init.sh` to set up your wiki
2. **Configure**: Edit `config/project-config.yaml` for team members
3. **Add code**: Clone repos into `raw/30-development/git-repos/`
4. **Ingest**: Add your first PRD with `scripts/wiki-ingest.sh`
5. **Query**: Start asking questions with `scripts/wiki-query.sh`

## 📄 License

This is a pattern/specification. Use what's useful, ignore what isn't.

## 🤝 Contributing

This is a personal knowledge system pattern. Adapt it to your needs. Your LLM agent can figure out the rest.
