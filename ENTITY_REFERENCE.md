# 实体关系快速参考

## 🚀 快速查询指南

### 常用实体关系

| 从 | 到 | 关系 | 用途 |
|----|----|----|----|
| **ProductRequirement** | **UserStory** | decomposes_into | 需求分解 |
| **UserStory** | **Task** | implemented_by | 任务实现 |
| **Task** | **CodeModule** | has_code | 代码关联 |
| **Bug** | **PullRequest** | fixed_by | 问题修复 |
| **CodeModule** | **CodeModule** | imports | 依赖分析 |
| **UserStory** | **UserStory** | relates_to | 相关需求 |

### 典型查询路径

**需求追溯**:
```
ProductRequirement → UserStory → Task → CodeModule → CodeFunction
```

**影响分析**:
```
CodeModule → serves → APIEndpoint → used_by → UserStory → Epic
```

**根因分析**:
```
Bug → caused_by → CodeModule → CodeFunction.calls → PullRequest → TeamMember
```

## 📋 实体速查

### 产品实体
- `ProductRequirement`: prd_id (PRD-NNN)
- `UserStory`: us_id (US-NNN)
- `Epic`: epic_id (EPIC-NNN)
- `Task`: task_id (TASK-NNN)
- `Bug`: bug_id (BUG-NNN)

### 代码实体
- `CodeModule`: module_name (类路径)
- `CodeFunction`: func_name (函数名)
- `APIEndpoint`: endpoint_path + method
- `DataModel`: model_name (表名)

### 流程实体
- `Sprint`: sprint_id (Sprint-NN)
- `Meeting`: meeting_id (MTG-NNN)
- `ArchitectureDecision`: adr_id (ADR-NNN)
- `Release`: version (x.y.z)

## 🔧 实用命令

### 创建实体文档
```bash
./bin/wiki-ingest doc.md --type UserStory
./bin/wiki-ingest prd.pdf --type ProductRequirement
```

### 查询关系
```bash
./bin/wiki-query "US-001的所有实现任务"
./bin/wiki-query "依赖AuthService的模块"
```

### 同步代码
```bash
./bin/wiki-sync-code.sh --repo backend
```

---
**完整设计**: 见 [研发知识图谱设计文档](./research-knowledge-graph-design.md)
