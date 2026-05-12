# 飞书(Lark) CLI 配置指南

## 📋 步骤1: 初始化配置

打开新的终端窗口，运行：

```bash
lark-cli config init --new
```

这会：
1. 生成一个验证URL
2. 等待你在浏览器中完成认证
3. 自动保存配置到本地

**重要**: 保持这个命令运行，不要中断！

## 🌐 步骤2: 浏览器认证

1. 命令会显示一个URL，类似：
   ```
   Please open the following URL in your browser:
   https://open.feishu.cn/open-apis/authen/v1/authorize...
   ```

2. 在浏览器中打开这个URL

3. 登录飞书账号

4. 授权lark-cli访问你的飞书云文档

## ✅ 步骤3: 验证配置

认证完成后，lark-cli会自动保存配置。验证：

```bash
lark-cli auth whoami
```

应该显示你的飞书用户信息。

## 🚀 步骤4: 初始化Wiki

配置成功后，回到项目目录运行：

```bash
cd C:\Users\alick\code\ai\agent\feishu_kb\Kimi_Agent_LLMwiki\llm-wiki-agile
./bin/wiki-init --name "LLM-Knowledge-Base"
```

## 🔧 故障排除

### 问题1: "not configured" 错误
**解决**: 确保完成了步骤1和步骤2，且浏览器认证成功

### 问题2: 认证超时
**解决**: 重新运行 `lark-cli config init --new`

### 问题3: 权限不足
**解决**: 确保你的飞书账号有访问云文档的权限

## 📚 相关文档

- lark-cli文档: https://github.com/larksuite/node-lark-cli
- 飞书开放平台: https://open.feishu.cn/

---

**下一步**: 完成配置后回来，我们继续初始化wiki！
