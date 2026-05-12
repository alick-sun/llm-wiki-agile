# Skills Reference for LLM Wiki — Agile Edition

This document defines all skills available in this project and their taxonomy.

## Skill Categories

### 🎯 Project-Specific Skills
These skills are **custom-built for this project only**. They provide domain-specific operations.

| Skill | Purpose | Trigger |
|-------|---------|---------|
| `llm-wiki-agile` | Wiki operations (init/ingest/query/sync/lint) | `/wiki-*` commands, mentions of "wiki", "ingest", "knowledge base" |

**When to use**: When operating the LLM wiki system — initializing, ingesting documents, querying knowledge, syncing code.

### 🔧 General-Purpose Skills (Superpowers)
These skills are **universal methodologies** applicable to any software project. They are part of the Superpowers ecosystem.

| Skill | Purpose | Trigger |
|-------|---------|---------|
| `superpowers:brainstorming` | Explore requirements before implementation | "Let's build...", "How should we...", creative tasks |
| `superpowers:systematic-debugging` | Debug bugs and failures systematically | Any bug, test failure, unexpected behavior |
| `superpowers:test-driven-development` | TDD workflow for features/bugfixes | Implementing features or fixing bugs |
| `superpowers:writing-plans` | Create implementation plans from specs | "Here's the spec, plan the implementation" |
| `superpowers:executing-plans` | Execute existing plans with checkpoints | "Execute this plan" |
| `superpowers:verification-before-completion` | Verify work before claiming done | Before completing any task |

**When to use**: For methodology, workflow, and process — regardless of domain.

## Skill Interaction Patterns

### Pattern 1: Methodology First, Then Tool
```
User: "Let's add a feature to ingest GitHub PRs"
↓
Use: superpowers:brainstorming (explore requirements)
↓
Use: superpowers:writing-plans (create implementation plan)
↓
Use: llm-wiki-agile (execute wiki-specific operations)
```

### Pattern 2: Project-Specific Directly
```
User: "Ingest this PRD document"
↓
Use: llm-wiki-agile (direct domain operation)
```

### Pattern 3: Universal Debugging
```
User: "The wiki-ingest script is failing"
↓
Use: superpowers:systematic-debugging (diagnose any bug)
↓
Use: llm-wiki-agile (apply wiki-specific fix)
```

## Key Distinctions

| Aspect | Project-Specific (llm-wiki-agile) | General (Superpowers) |
|--------|-----------------------------------|----------------------|
| **Scope** | This project only | Any project |
| **Provides** | Domain operations, commands | Methodologies, workflows |
| **Example** | "How to ingest a PRD?" | "How to approach any implementation?" |
| **Analogous to** | `curl`, `git` commands | `TDD`, `debugging` practices |

## Decision Tree for Claude

When the user makes a request:

```
Is it about wiki operations (init/ingest/query/sync)?
├─ Yes → Use llm-wiki-agile skill
└─ No
   ├─ Is it creative/implementation work?
   │  └─ Yes → Use superpowers:brainstorming first
   ├─ Is it a bug/failure?
   │  └─ Yes → Use superpowers:systematic-debugging
   ├─ Is it a feature/bugfix to implement?
   │  └─ Yes → Use superpowers:test-driven-development
   └─ Is it claiming work is done?
      └─ Yes → Use superpowers:verification-before-completion
```

## Anti-Patterns to Avoid

❌ **Don't**: Use superpowers for straightforward domain operations
- Example: Using brainstorming for "ingest this document"

❌ **Don't**: Use llm-wiki-agile for general methodology questions
- Example: Using wiki-ingest skill to decide "should we use TDD?"

❌ **Don't**: Assume project skills are universal
- Not every project has a `/wiki-ingest` command

## For Future Maintainers

When adding new skills to this project:

1. **Decide the category**: Is this project-specific or general methodology?
2. **Project-specific**: Add to SKILL.md, document in this file under "Project-Specific Skills"
3. **Methodology**: Consider if it belongs in Superpowers ecosystem instead
4. **Update this document**: Add trigger conditions and interaction patterns

## Version History

- 2026-05-11: Initial skill taxonomy created to prevent confusion between domain and methodology skills
