# my-personal-vibecoding-skills

个人维护的 AI coding agent skills 集合，用于跨机器/跨项目复用。

## 目录结构

```
my-personal-vibecoding-skills/
├── README.md
├── sync.ps1                     # 仓库 <-> opencode 运行目录的同步脚本
├── prompt-engineering/          # skill 1
│   ├── SKILL.md
│   └── prompt-template.md       # 该 skill 自己的资源文件
└── <skill-two>/                 # skill 2
    ├── SKILL.md
    └── references/
        └── examples.md
```

## 目录约定

**1. 目录名必须等于 `SKILL.md` frontmatter 里的 `name`**

```yaml
---
name: skill-two          # 必须和文件夹名一致
description: 做什么 + 何时触发
---
```

opencode 会校验这个一致性，不一致会加载失败。

**2. 扁平一层，不嵌套分类目录**

不要建 `writing/`、`dev/` 这类中间层。虽然 opencode 递归扫 `**/SKILL.md`，嵌套也能加载，但扁平结构在把这个仓库整体挂成 skill 源时不会有歧义。

**3. skill 的资源文件放它自己目录内**

用相对路径引用，跟着 skill 走。子目录深度不限。

## 新增 skill

1. 建目录写文件：

   ```powershell
   New-Item -ItemType Directory -Path "D:\repos\my-agent-skills\<skill-name>"
   # 然后创建 <skill-name>\SKILL.md
   ```

2. 提交：

   ```powershell
   cd D:\repos\my-agent-skills
   git add -A
   git commit -m "Add <skill-name> skill"
   git push
   ```

3. 同步到运行目录：

   ```powershell
   .\sync.ps1 -Direction Push -Skill <skill-name>
   ```

## 接入 opencode

仓库和运行目录是**两份独立文件**，不是链接关系：

| 位置 | 角色 |
|------|------|
| `D:\repos\my-agent-skills\`（本仓库本地检出） | git 版本管理源，做版本记录和跨机同步 |
| `~/.config/opencode/skills/<skill>/` | opencode 实际加载的运行副本 |

opencode 默认扫描 `~/.config/opencode/skills/`，因此**不要**再配置 `skills.paths` 指向本仓库，否则同名 skill 会被注册两次。

如果 skill 放在 `~/.claude/skills/`，opencode 也会自动扫描那个目录，同步时用 `-Target` 指定即可。

## 同步（sync.ps1）

两份文件独立维护，靠脚本保持一致性。

```powershell
.\sync.ps1                                            # 只报告差异，不做改动（默认）
.\sync.ps1 -Direction Push                            # 仓库 -> 运行目录
.\sync.ps1 -Direction Pull                            # 运行目录 -> 仓库
.\sync.ps1 -Direction Push -Skill prompt-engineering  # 只同步一个 skill
.\sync.ps1 -Target "$env:USERPROFILE\.claude\skills"  # 同步到另一个 skill 目录
```

如果执行策略拦截，用：

```powershell
powershell -ExecutionPolicy Bypass -File .\sync.ps1
```

**参数**

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-Direction` | `Status` | `Status` 只报告 / `Push` 仓库→运行目录 / `Pull` 运行目录→仓库 |
| `-Target` | `~/.config/opencode/skills` | 运行目录 |
| `-Skill` | 全部 | 限定单个 skill 目录名 |
| `-Repo` | 脚本所在目录 | 仓库根目录 |

**行为说明**

- 比较时忽略 CRLF/LF 差异，行尾符变化不会被误报为内容不一致
- 二进制文件按原始字节比较
- **不会删除**只存在于一侧的文件，只报告 `repository only` / `runtime only`
- 运行目录里没有仓库对应物的 skill 报告为 `ORPHAN`，不参与同步——避免把第三方 skill 误拉进仓库

工作流：`.\sync.ps1` 查看差异 → 确认方向 → `-Direction Push` 或 `Pull` → `git status` 提交。

skill 内容变化后需要**重启 opencode** 才会生效。

## Skills 列表

| Skill | 用途 |
|-------|------|
| `prompt-engineering` | 编写、优化、审查 LLM/Agent prompt |
