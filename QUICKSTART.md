# 🎉 Wiki 初始化成功！

## 📊 当前状态

**Wiki名称**: LLM-Knowledge-Base
**初始化时间**: 2026-05-12
**访问链接**: https://navinfo.feishu.cn/drive/folder/RbCbfMRhWl3WnEddlb6c1RW5n4c

### ✅ 已创建结构

**飞书文档**:
- ✅ 主文件夹: LLM-Knowledge-Base
- ✅ 7个子文件夹: 10-product, 20-design, 30-development, 40-process, 50-research, entities, concepts, syntheses
- ✅ index 文档
- ✅ log 文档

**本地目录**:
- ✅ raw/ 目录结构 (7个分类)
- ✅ config/wiki-config.json 配置文件

---

## 🚀 快速开始

### 1. 添加第一个文档

#### 方式A: 从URL摄入
```bash
./bin/wiki-ingest https://your-prd-url --type ProductRequirement --title "用户认证系统PRD"
```

#### 方式B: 从本地文件
```bash
# 创建一个测试文档
cat > test-user-story.md << 'EOF'
---
type: UserStory
id: US-001
title: "微信扫码登录"
status: todo
priority: P1
tags: [登录, 微信, OAuth]
created_at: "2026-05-12"
---

## 用户故事

作为**用户**，我想要**使用微信扫码登录**，以便**快速进入系统**

### 验收标准
- [ ] 显示微信扫码界面
- [ ] 扫码后自动登录
- [ ] 未注册用户自动注册
EOF

# 摄入文档
./bin/wiki-ingest test-user-story.md --type UserStory
```

#### 方式C: 从飞书文档
```bash
./bin/wiki-ingest <飞书文档token或URL> --type Meeting
```

### 2. 查看Wiki

在浏览器中打开：
```
https://navinfo.feishu.cn/drive/folder/RbCbfMRhWl3WnEddlb6c1RW5n4c
```

你会看到所有创建的文件夹和文档。

### 3. 查询知识库

```bash
./bin/wiki-query "用户登录有哪些方式？"
```

这会：
- 搜索飞书文档
- 搜索代码图谱（如果有代码仓库）
- 综合答案并显示来源

### 4. 添加代码仓库（可选）

```bash
# 1. 克隆代码仓库
cd raw/30-development/git-repos
git clone https://github.com/your-username/your-repo.git

# 2. 同步到知识图谱
cd ../../..
./bin/wiki-sync-code.sh --repo your-repo
```

---

## 📝 可用的实体类型

### 产品类型 (10-product)
- `ProductRequirement` - PRD文档
- `UserStory` - 用户故事
- `Epic` - 史诗/主题
- `Task` - 开发任务
- `Bug` - 缺陷

### 设计类型 (20-design)
- `ArchitectureDecision` - 架构决策

### 流程类型 (40-process)
- `Meeting` - 会议记录
- `Sprint` - 迭代记录
- `Release` - 发布记录

### 研究类型 (50-research)
- 任何研究文章、论文

---

## 🎯 建议的工作流

### 工作流1: 产品文档管理
```bash
# 1. 摄入PRD
./bin/wiki-ingest prd-url --type ProductRequirement

# 2. 拆分为用户故事
./bin/wiki-ingest user-story-1.md --type UserStory
./bin/wiki-ingest user-story-2.md --type UserStory

# 3. 查询相关需求
./bin/wiki-query "用户认证相关的需求有哪些？"
```

### 工作流2: 会议记录管理
```bash
# 1. 记录会议
./bin/wiki-ingest meeting-notes.md --type Meeting

# 2. 关联决策
./bin/wiki-ingest decision-record.md --type ArchitectureDecision

# 3. 查询决策历史
./bin/wiki-query "关于架构设计的决策有哪些？"
```

### 工作流3: 知识探索
```bash
# 1. 添加多份文档
./bin/wiki-ingest doc1.pdf --type ProductRequirement
./bin/wiki-ingest doc2.md --type UserStory
./bin/wiki-ingest doc3.url --type Meeting

# 2. 跨文档查询
./bin/wiki-query "用户认证流程在整个系统中是如何实现的？"
```

---

## 🔧 常用命令

### 摄入文档
```bash
./bin/wiki-ingest <source> --type <EntityType> --title "Title"
```

### 查询知识
```bash
./bin/wiki-query "<question>"
```

### 同步代码
```bash
./bin/wiki-sync-code.sh --all          # 同步所有仓库
./bin/wiki-sync-code.sh --repo backend # 同步特定仓库
```

### 健康检查
```bash
./bin/wiki-lint                         # 检查wiki健康状态
./bin/wiki-lint --fix                   # 自动修复问题
```

---

## 📚 文档参考

- **完整文档**: README.md
- **安装指南**: INSTALL.md
- **会话记录**: SESSION.md
- **实体定义**: schema/entities.yaml

---

## 🎊 恭喜！

你的个人知识库已经完全就绪！

**下一步**:
1. 添加你的第一份文档
2. 尝试查询功能
3. 探索知识图谱的强大能力

有任何问题，随时询问！
