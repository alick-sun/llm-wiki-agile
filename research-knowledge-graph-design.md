---
type: ResearchNote
id: RESEARCH-001
title: "研发知识图谱设计 - 实体关系体系"
status: completed
priority: P1
tags: [知识图谱, 实体设计, 关系建模, 研发流程, 认知沉淀]
created_at: "2026-05-12"
related: []
---

# 研发知识图谱设计 - 实体关系体系

## 📋 文档概述

**研究主题**: 基于LLM的研发知识库实体关系体系设计
**设计目标**: 建立完整的研发过程认知沉淀框架
**设计时间**: 2026-05-12
**适用范围**: 敏捷软件开发团队知识管理

---

## 🎯 设计理念

### 核心思想

研发过程的知识沉淀**不仅仅是文档管理**，而是建立**实体间的关联网络**。通过明确的实体类型和关系定义，实现：

1. **需求追溯**: 从PRD到代码的完整链路
2. **影响分析**: 代码变更影响的范围评估
3. **知识发现**: 隐藏关联的自动识别
4. **决策记录**: 技术决策的上下文关联
5. **团队协作**: 人员与工作的多维关联

### 设计原则

- **分层关联**: Structural (产品/代码/Git) + Conceptual (概念/规则) + Process (流程)
- **双向追踪**: Forward (需求→实现) + Backward (实现→需求)
- **多维度**: 时间 + 人员 + 质量 + 架构
- **可扩展**: 支持新实体类型和关系的动态添加

---

## 📊 完整实体属性表

### 结构层 - 产品 (Structural - Product)

| 实体类型 | 主要属性 | 标识符 | 状态 | 关键关系 |
|---------|----------|--------|------|----------|
| **ProductRequirement** | prd_id, title, status, priority, stakeholder[] | prd_id | draft/review/approved/deprecated | decomposes_into→UserStory, relates_to→DomainConcept |
| **UserStory** | us_id, title, status, story_points, acceptance_criteria[] | us_id | todo/doing/done/cancelled | belongs_to→Epic, implemented_by→Task, tested_by→TestCase |
| **Epic** | epic_id, title, status, business_value, progress_pct | epic_id | planned/active/completed/cancelled | contains→UserStory, contributes_to→ProductRequirement |
| **Task** | task_id, title, task_type, git_branch, estimated_hours | task_id | todo/doing/done/review/blocked | implements→UserStory, has_code→CodeModule, reviewed_in→PullRequest |
| **Bug** | bug_id, title, severity, environment, root_cause | bug_id | new/confirmed/in_progress/fixed/verified/closed | blocks→UserStory, caused_by→CodeModule, fixed_by→PullRequest |

### 结构层 - 代码 (Structural - Code)

| 实体类型 | 主要属性 | 标识符 | 来源 | 关键关系 |
|---------|----------|--------|------|----------|
| **CodeModule** | module_name, language, path, lines_of_code, god_node_rank | module_name | Graphify AST提取 | imports→CodeModule, serves→APIEndpoint, implements→Task |
| **CodeFunction** | func_name, signature, cyclomatic_complexity, is_public | func_name | Graphify AST提取 | belongs_to→CodeModule, calls→CodeFunction, implements→DomainConcept |
| **APIEndpoint** | endpoint_path, method, auth_required, request_schema | endpoint_path | AST + OpenAPI | served_by→CodeModule, consumes→DataModel, used_by→UserStory |
| **DataModel** | model_name, db_type, table_name, fields[], indexes[] | model_name | DDL AST | supports→DomainConcept, queried_by→CodeModule, referenced_in→APIEndpoint |

### 结构层 - Git (Structural - Git)

| 实体类型 | 主要属性 | 标识符 | 来源 | 关键关系 |
|---------|----------|--------|------|----------|
| **PullRequest** | pr_number, title, branch_from, branch_to, files_changed[] | pr_number | Git API | implements→Task, modifies→CodeModule, reviewed_by→TeamMember |
| **GitCommit** | hash, message, author, date, insertions, deletions | hash | git log | part_of→PullRequest, modifies→CodeModule, author→TeamMember |

### 概念层 (Conceptual)

| 实体类型 | 主要属性 | 标识符 | 来源 | 关键关系 |
|---------|----------|--------|------|----------|
| **DomainConcept** | name, aliases[], definition, confidence, first_seen_date | name | LLM语义提取 | specializes→DomainConcept, used_in→UserStory, implemented_by→CodeFunction |
| **BusinessRule** | rule_id, description, rule_type, trigger_event, priority | rule_id | LLM语义提取 | constrains→UserStory, enforced_in→CodeModule, originates_from→ProductRequirement |
| **DesignPattern** | name, category, intent, applicability[], tradeoffs{} | name | LLM识别 | applied_in→CodeModule, related_to→DesignPattern |

### 流程层 (Process)

| 实体类型 | 主要属性 | 标识符 | 来源 | 关键关系 |
|---------|----------|--------|------|----------|
| **Sprint** | sprint_id, name, status, goal, velocity, planned_points | sprint_id | 手动记录 | contains→UserStory, contains_task→Task, reviewed_in→Meeting |
| **Meeting** | meeting_id, title, meeting_type, attendees[], agenda[], decisions[] | meeting_id | 手动记录 | discusses→ArchitectureDecision, reviews→Sprint, attended_by→TeamMember |
| **ArchitectureDecision** | adr_id, title, status, context, decision, consequences{} | adr_id | 手动记录 | supersedes→ArchitectureDecision, decided_in→Meeting, affects→CodeModule |
| **Release** | version, status, release_date, features[], bugfixes[] | version | 手动记录 | includes_us→UserStory, includes_bug→Bug, deploys→CodeModule |

### 人员层 (People)

| 实体类型 | 主要属性 | 标识符 | 来源 | 关键关系 |
|---------|----------|--------|------|----------|
| **TeamMember** | name, role, email, expertise[], current_sprint_capacity | name | 配置文件 | owns→UserStory, authors→PullRequest, attends→Meeting, reports→Bug |

---

## 🔗 完整关系类型表

### 产品开发关系

| 关系名称 | 关系描述 | 方向 | 示例 |
|---------|----------|------|------|
| **decomposes_into** | 需求分解为用户故事 | 1→N | ProductRequirement → UserStory |
| **belongs_to** | 用户故事属于史诗 | N→1 | UserStory → Epic |
| **implements** | 任务实现用户故事 | N→M | Task → UserStory |
| **has_code** | 任务关联代码模块 | 1→N | Task → CodeModule |
| **tested_by** | 用户故事被测试用例验证 | N→M | UserStory → TestCase |
| **blocked_by** | 用户故事被缺陷阻塞 | N→M | UserStory → Bug |
| **fixed_by** | 缺陷被PR修复 | N→1 | Bug → PullRequest |
| **caused_by** | 缺陷由代码模块引起 | N→M | Bug → CodeModule |

### 代码结构关系

| 关系名称 | 关系描述 | 方向 | 用途 |
|---------|----------|------|------|
| **imports** | 代码模块导入依赖 | N→M | 依赖分析、重构影响范围 |
| **serves** | 模块服务API端点 | 1→N | 接口与实现映射 |
| **belongs_to** | 函数属于模块 | N→1 | 代码组织结构 |
| **calls** | 函数调用关系 | N→M | 调用链分析、性能瓶颈识别 |
| **consumes** | API消费数据模型 | N→M | 接口依赖分析 |
| **part_of** | 组成更大实体 | N→1 | Git组织、模块归属 |
| **modifies** | 提交/PR修改代码 | N→M | 变更历史追踪 |

### 概念关联关系

| 关系名称 | 关系描述 | 方向 | 用途 |
|---------|----------|------|------|
| **specializes** | 概念特化/继承 | N→1 | 领域知识层次化 |
| **used_in** | 概念用于用户故事 | N→M | 需求中的概念使用 |
| **implemented_by** | 概念由函数实现 | N→M | 概念到代码的映射 |
| **constrains** | 规则约束用户故事 | N→M | 业务规则约束验证 |
| **enforced_in** | 规则在代码中执行 | N→M | 规则实现位置追踪 |
| **originates_from** | 规则来源于需求 | N→1 | 规则需求追溯 |
| **applied_in** | 设计模式应用位置 | N→M | 架构模式识别 |

### 流程协作关系

| 关系名称 | 关系描述 | 方向 | 用途 |
|---------|----------|------|------|
| **contains** | Sprint包含工作项 | 1→N | 迭代规划 |
| **discusses** | 会议讨论决策 | N→M | 决策上下文 |
| **reviews** | 会议审查迭代 | N→1 | 流程节点 |
| **supersedes** | 决策替代旧决策 | 1→1 | 决策演化 |
| **decided_in** | 决策在会议中做出 | N→1 | 决策过程追溯 |
| **affects** | 决策影响代码模块 | N→M | 架构影响范围 |
| **produces** | 会议产生行动项 | N→M | 行动跟踪 |

### 人员参与关系

| 关系名称 | 关系描述 | 方向 | 用途 |
|---------|----------|------|------|
| **owns** | 成员拥有用户故事 | N→M | 责任分配 |
| **authors** | 成员创建PR | N→1 | 代码贡献追踪 |
| **attends** | 成员参加会议 | N→M | 协作网络 |
| **reports** | 成员报告缺陷 | N→M | 质量责任 |
| **decides** | 成员参与决策 | N→M | 决策参与者 |
| **reviewed_by** | 成员审查PR | N→M | 代码审查流程 |

---

## 🏗️ 分层架构设计

### 三层实体体系

```
┌─────────────────────────────────────────────────────────────┐
│                    Conceptual Layer                         │
│  DomainConcept | BusinessRule | DesignPattern               │
│  (语义提取、抽象建模、模式识别)                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Structural Layer                            │
│  Product │ Code │ Git                                      │
│  (需求→设计→实现→追溯)                                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Process Layer                             │
│  Sprint │ Meeting │ ADR │ Release                           │
│  (时间线、协作、决策记录)                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    People Layer                              │
│  TeamMember (所有活动的主体)                                 │
└─────────────────────────────────────────────────────────────┘
```

### 层间关系流向

**垂直流向** (上下文追溯):
- People → Process: 谁参与了什么会议/迭代
- Process → Structural: 什么会议/迭代产生了什么代码/需求
- Structural → Conceptual: 什么代码/需求体现了什么概念/规则
- Conceptual → People: 谁是某个概念/规则的专家

**水平流向** (关联发现):
- 同层内部关联: 相关需求、依赖模块、类似模式
- 跨层跳跃: 概念直接连接到函数、决策影响代码

---

## 🎯 关键设计特性

### 1. 双向可追溯性 (Bidirectional Traceability)

**Forward Traceability** (正向追溯):
- PRD → UserStory → Task → CodeModule → CodeFunction
- 需求可以一路追溯到具体的代码实现

**Backward Traceability** (反向追溯):
- CodeFunction → DomainConcept → UserStory → ProductRequirement
- 代码变更可以反向评估需求影响

### 2. 多维度关联 (Multi-dimensional Relations)

**时间维度**:
- Sprint → Release → Meeting → ArchitectureDecision
- 迭代周期中的所有活动

**质量维度**:
- Bug → TestCase → PullRequest → CodeModule
- 质量问题的完整生命周期

**架构维度**:
- DesignPattern → CodeModule → APIEndpoint → DataModel
- 架构设计的具体实现

**协作维度**:
- TeamMember → UserStory → PullRequest → Meeting
- 人员参与的所有活动

### 3. Graphify集成 (Code Analysis Integration)

**自动提取的代码关系**:
- **CodeModule.imports**: 模块依赖图
- **CodeFunction.calls**: 函数调用图
- **God Node检测**: 架构热点识别
- **Community发现**: 代码模块聚类

**语义增强**:
- AST结构 + LLM语义理解
- 代码意图自动识别
- 设计模式自动检测

### 4. 动态知识发现 (Dynamic Knowledge Discovery)

**隐式关系**:
- 相似用户故事自动聚类
- 相关代码模块推荐
- 潜在Bug风险预测

**冲突检测**:
- 相同概念的不同定义
- 相互矛盾的架构决策
- 重复实现的功能

---

## 📊 实体关系矩阵

### 核心实体关联强度表

|  | PR | US | Epic | Task | Bug | CM | CF | API | DM | PRs | Commit | DC | BR | DP | Sprint | Meet | ADR | Rel | TM |
|--|----|----|-----|-----|-----|----|----|-----|----|-----|--------|----|----|----|-------|-----|-----|-----|----|
| **PR** | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ |
| **US** | ✅ | ➖ | ✅ | ✅ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ✅ | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ |
| **Epic** | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ |
| **Task** | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ |
| **Bug** | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ |
| **CM** | ➖ | ➖ | ➖ | ✅ | ✅ | ➖ | ✅ | ✅ | ✅ | ✅ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ |
| **CF** | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ |
| **API** | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ |
| **DM** | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ |
| **PRs** | ➖ | ➖ | ➖ | ✅ | ✅ | ✅ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ |
| **Commit** | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ |
| **DC** | ✅ | ✅ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ |
| **BR** | ✅ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ |
| **DP** | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ |
| **Sprint** | ➖ | ✅ | ➖ | ✅ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ✅ | ➖ | ✅ |
| **Meet** | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ✅ | ➖ | ✅ |
| **ADR** | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ✅ | ✅ | ➖ | ✅ |
| **Rel** | ➖ | ✅ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ➖ | ✅ | ➖ | ➖ | ➖ | ✅ |
| **TM** | ➖ | ✅ | ✅ | ✅ | ✅ | ➖ | ➖ | ➖ | ➖ | ✅ | ✅ | ✅ | ➖ | ➖ | ✅ | ✅ | ✅ | ✅ | ✅ |

**图例**: ✅ 强关联 | ➖ 弱/无关联

---

## 🚀 实际应用场景

### 场景1: 需求影响分析

**问题**: 用户故事"微信扫码登录"需要修改，影响范围是什么？

**查询路径**:
1. UserStory(US-001) → Task[] → CodeModule[]
2. CodeModule[] → APIEndpoint[] + DataModel[]
3. CodeModule[] → PullRequest[] → GitCommit[]
4. CodeModule[] → DomainConcept[] → other UserStory[]

**输出影响报告**:
- 直接影响的代码模块: 3个
- 相关的API接口: 2个
- 数据模型变更: 1个表
- 相关的其他用户故事: 4个
- 历史修改记录: 7个PR

### 场景2: 代码质量根因分析

**问题**: 生产环境发现数据丢失Bug，如何快速定位根本原因？

**分析路径**:
1. Bug → caused_by → CodeModule[]
2. CodeModule[] → CodeFunction.calls → CodeFunction[]
3. CodeModule[] → PullRequest[] → GitCommit[].author
4. CodeModule[] → BusinessRule.enforced_in
5. CodeModule[] → tested_by → TestCase[]

**输出根因报告**:
- 问题代码模块: AuthService
- 责任函数: validateToken() → parseUser()
- 最近修改: 3天前, 作者: @Alice
- 违反的业务规则: "TOKEN_EXPIRY_24H"
- 测试覆盖: 无自动化测试
- 建议行动: 添加单元测试 + 代码审查

### 场景3: 技术决策影响评估

**问题**: 架构决策"从Monolith迁移到Microservices"，如何评估影响？

**决策影响图**:
1. ArchitectureDecision → affects → CodeModule[]
2. CodeModule[] → imports → CodeModule[] (依赖分析)
3. CodeModule[] → serves → APIEndpoint[]
4. APIEndpoint[] → used_by → UserStory[]
5. CodeModule[] → PullRequest.reviewed_by → TeamMember[]
6. UserStory[] → Sprint → Release

**输出影响报告**:
- 影响的代码模块: 15个核心模块
- 需要重构的API: 8个接口
- 涉及的用户故事: 23个
- 受影响的迭代: Sprint 1-3
- 需要协调的团队成员: 5人
- 风险评估: 高风险，建议分阶段迁移

---

## 📈 知识图谱质量指标

### 覆盖率指标

- **需求追溯率**: (有CodeModule关联的UserStory数) / (总UserStory数)
- **测试覆盖率**: (有TestCase关联的UserStory数) / (总UserStory数)
- **决策记录率**: (有ADR关联的CodeModule数) / (总核心CodeModule数)
- **人员参与率**: (有TeamMember关联的实体数) / (总实体数)

### 健康度指标

- **孤立实体率**: (无任何关系的实体数) / (总实体数) - 目标 < 5%
- **关系密度**: (实际关系数) / (可能关系数) - 目标 > 30%
- **概念一致性**: (冲突的DomainConcept定义数) - 目标 = 0
- **追溯完整性**: (PR→US→Task→Code的完整链路数) / (总需求数)

---

## 🔧 技术实现

### 存储方案

**Graphify格式**:
```json
{
  "nodes": [
    {
      "id": "US-001",
      "type": "UserStory",
      "attributes": {
        "title": "微信扫码登录",
        "status": "done",
        "story_points": 5
      }
    }
  ],
  "edges": [
    {
      "from": "US-001",
      "to": "TASK-042",
      "relation": "implemented_by",
      "attributes": {
        "confidence": 1.0
      }
    }
  ]
}
```

**飞书文档存储**:
- 实体文档: `entities/US-001-微信扫码登录.docx`
- 关系存储: frontmatter `related: [TASK-042, CODE-015]`
- 交叉引用: `<mention-doc token="doxcnXXX">关联实体</mention-doc>`

### 查询语言

**图查询示例**:
```cypher
// 查找用户故事的所有实现路径
MATCH (us:UserStory {id: "US-001"})-[:implemented_by]->(t:Task)-[:has_code]->(cm:CodeModule)
RETURN us, t, cm

// 查找高耦合模块(God Nodes)
MATCH (cm:CodeModule)
WHERE cm.god_node_rank > 80
MATCH (cm)-[:imports]-(other:CodeModule)
RETURN cm, collect(other) as dependencies
ORDER BY cm.god_node_rank DESC

// 查找孤立实体(需要关注)
MATCH (e)
WHERE NOT (e)-[]->()
RETURN e.type, count(e) as isolated_count
```

---

## 🎓 最佳实践建议

### 1. 实体创建原则

- **最小化属性**: 只记录核心属性，避免冗余
- **标准化ID**: 使用统一的ID格式 (TYPE-NNN)
- **必需frontmatter**: 每个实体文档必须有type和id字段
- **关系显式化**: 优先使用显式关系，而非隐式推断

### 2. 关系建立原则

- **精确性**: 关系类型要具体，避免模糊的"related"
- **双向性**: 建立双向关系便于查询
- **时效性**: 关系建立时记录时间戳，便于追溯
- **可验证**: 关系要有明确的来源依据

### 3. 维护策略

- **增量更新**: 新增实体时立即建立关系
- **定期清理**: 定期检查孤立实体和过期关系
- **冲突解决**: 及时发现和解决实体定义冲突
- **质量监控**: 监控图谱质量指标，及时优化

---

## 📊 未来扩展方向

### 智能增强

- **关系预测**: 基于内容相似度推荐潜在关系
- **聚类分析**: 自动发现相似实体和模式
- **异常检测**: 识别异常的关系模式和孤立实体
- **趋势分析**: 分析关系演变趋势

### 多模态融合

- **文档图谱**: 文档内容的语义关联
- **代码图谱**: 代码结构+语义的联合分析
- **协作图谱**: 团队协作关系网络
- **知识图谱**: 统一的多模态知识图谱

### 可视化探索

- **交互式图谱**: Web界面动态浏览实体关系
- **时间轴视图**: 展示实体和关系的时间演变
- **层级视图**: 按层级或类型展示关系网络
- **路径分析**: 可视化实体间的关联路径

---

## 🏁 总结

这个实体关系体系设计的核心价值在于：

1. **完整性**: 覆盖研发过程的所有关键实体
2. **可追溯性**: 双向的完整追溯链路
3. **智能化**: 结合Graphify的代码分析和LLM的语义理解
4. **实用性**: 支持实际研发场景的查询和分析

通过这个体系，研发团队可以真正实现**知识的系统化沉淀**，而不仅仅是文档的堆积。每一个决策、每一行代码、每一次协作都有迹可循，形成**活的知识网络**。

---

**文档版本**: v1.0
**最后更新**: 2026-05-12
**维护者**: 研发团队
**相关文档**: schema/entities.yaml, SKILL.md, CLAUDE.md
