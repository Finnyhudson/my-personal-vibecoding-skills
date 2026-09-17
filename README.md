# my-personal-vibecoding-skills

个人维护的 AI coding agent skills 集合，用于跨机器/跨项目复用。

## 目录结构

```
my-personal-vibecoding-skills/
├── prompt-engineering/
│   ├── SKILL.md              # 方法论 + 工作流指令 + 检查清单
│   └── prompt-template.md    # 可直接填充的 prompt 结构模板
└── (新增 skill 直接加同级目录)
```

每个 skill 是一个独立目录，目录名与 `SKILL.md` frontmatter 中的 `name` 一致。

## 新增 skill

1. 新建 `<skill-name>/` 目录
2. 创建 `SKILL.md`，frontmatter 至少包含 `name` 和 `description`
3. `description` 需要同时说明**做什么**和**何时触发**，并前置用户可能说的关键词

## 接入 opencode

两处**各自独立维护**，不是链接关系：

| 位置 | 角色 |
|------|------|
| `D:\repos\my-agent-skills\`（本仓库本地检出） | git 版本管理源，做版本记录和跨机同步 |
| `~/.config/opencode/skills/<skill>/` | opencode 实际加载的运行副本 |

opencode 默认扫描 `~/.config/opencode/skills/`，因此**不要**再配置 `skills.paths` 指向本仓库，否则同名 skill 会被注册两次。

### 同步方向

仓库改动后（新版本要先落仓库）：

```powershell
Copy-Item -Path "D:\repos\my-agent-skills\prompt-engineering\*" `
  -Destination "$env:USERPROFILE\.config\opencode\skills\prompt-engineering\" -Force
```

opencode 运行副本改动后（回写到仓库以便提交）：

```powershell
Copy-Item -Path "$env:USERPROFILE\.config\opencode\skills\prompt-engineering\*" `
  -Destination "D:\repos\my-agent-skills\prompt-engineering\" -Force
```

skill 内容变化后需要重启 opencode 才会生效。

### 注意

两份独立文件存在漂移风险：改了一边忘记同步，运行副本与仓库就会不一致。每次修改后建议用 `git status` 确认仓库侧是否有未提交差异。

## Skills 列表

| Skill | 用途 |
|-------|------|
| `prompt-engineering` | 编写、优化、审查 LLM/Agent prompt |
