# Wiki目录迁移说明

## 📋 迁移信息

**迁移日期**: 2026-05-12
**原因**: 用户指定新的飞书目录位置

## 🔄 目录变更

### 原目录
- **URL**: https://navinfo.feishu.cn/drive/folder/fldcnN3YQbFLhtd2AtMw9Noc0ee
- **Token**: fldcnN3YQbFLhtd2AtMw9Noc0ee
- **用途**: 初始wiki目录

### 新目录
- **URL**: https://navinfo.feishu.cn/drive/folder/Pz7tf4jcHlVtyNdoOzUcqQ4Undg
- **Token**: Pz7tf4jcHlVtyNdoOzUcqQ4Undg
- **用途**: 新的wiki主目录

## ✅ 迁移内容

### 飞书文档结构
- ✅ 7个子文件夹 (10-product, 20-design, 30-development, 40-process, 50-research, entities, concepts, syntheses)
- ✅ Index目录文档
- ✅ Log操作日志

### 配置更新
- ✅ `config/wiki-config.json` - 更新指向新目录
- ✅ wiki_folder_token: Pz7tf4jcHlVtyNdoOzUcqQ4Undg
- ✅ wiki_url: https://navinfo.feishu.cn/drive/folder/Pz7tf4jcHlVtyNdoOzUcqQ4Undg

## 🔧 保持不变

### 本地环境
- ✅ `raw/` 目录结构
- ✅ 所有脚本 (`scripts/`, `bin/`)
- ✅ Git仓库配置
- ✅ 用户权限配置

### 外部系统
- ✅ GitHub仓库: https://github.com/alick-sun/llm-wiki-agile
- ✅ 用户身份: 孙翔东 (ou_d902cdd9526c3c683363acdb811798ee)
- ✅ 权限: space:folder:create, docx:document:create

## 📝 迁移验证

### 验证步骤
1. ✅ 新目录中7个子文件夹创建成功
2. ✅ Index和Log文档创建成功
3. ✅ 配置文件更新完成
4. ✅ 所有脚本命令正常工作

### 测试命令
```bash
# 验证配置
cat config/wiki-config.json

# 测试wiki操作
./bin/wiki-ingest test-user-story.md --type UserStory
./bin/wiki-query "我的wiki有哪些内容？"
```

## 🚀 后续使用

### 正常操作
所有wiki命令现在会自动使用新目录：
- `./bin/wiki-ingest` - 文档会添加到新目录
- `./bin/wiki-query` - 查询会在新目录中进行
- `./bin/wiki-sync-code` - 同步代码到新目录

### 配置文件
`config/wiki-config.json` 已自动更新，无需手动修改。

---

**迁移状态**: ✅ 完成
**新目录**: https://navinfo.feishu.cn/drive/folder/Pz7tf4jcHlVtyNdoOzUcqQ4Undg
