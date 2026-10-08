# my-personal-vibecoding-skills

个人维护的 AI coding agent skills 集合，用于跨机器/跨项目复用。

## 让 agent 帮我完成本机配置

把下面这句话连同仓库地址交给一个能读写文件、能执行命令的 agent：

> 读取这个仓库的 README，安装并加载 agent-setup 和 personal-code-prompt，按原则帮我完成本机智能体配置；先备份现有配置，保留不冲突的本机设置，需要密钥或替换模型时再问我。

仓库地址：https://github.com/Finnyhudson/my-personal-vibecoding-skills

已经克隆到本机时，直接把那个目录路径告诉 agent 也行；克隆和用现有检出都可以，agent 自己会找到仓库根目录。

### agent 执行步骤

1. 先检查 `agent-setup` 和 `personal-code-prompt` 是否已被当前 agent 识别。已识别且支持 skill 工具时，**实际调用工具加载这两个 skill**，再读 `agent-setup/PRINCIPLES.md`；不要把“读过文件”说成“已加载”。尚未识别时，先读仓库里的两个 `SKILL.md` 与 `PRINCIPLES.md`，用于完成安装前的目录检查；`PRINCIPLES.md` 是配置原则的唯一依据。
2. 只读检查本机现状：OpenCode 版本、实际生效的配置目录、oh-my-opencode-slim 版本、可用的 provider 和模型、已有的自定义设置。
3. 按 `PRINCIPLES.md` 落地：版本和格式与 `agent-setup/snapshot/` 一致时以快照为参考；不一致时不要硬套旧字段，按原则改成新格式，先查对应版本的官方文档。**版本和快照对不上不是任务终点**，继续按 skill 做。
4. 改动前先展示目标、涉及覆盖的范围和关键冲突；已有自定义按 skill 要求逐项确认，并先备份。
5. 安装 `agent-setup` 与 `personal-code-prompt` 的运行副本，把快照里的本机路径换成当前机器的路径。安装后实际加载两个 skill，再继续配置；若宿主必须重启才能识别新 skill，明确告诉用户重启后继续加载，不假装当前会话已加载。宿主没有 skill 工具时，完整读取两个 `SKILL.md` 及相关资源作为替代，并如实说明没有原生加载能力。
6. 密钥：让用户自己设置或输入环境变量；不进仓库，也不写进报告。缺哪个模型就列出来问用户，不猜替代。
7. 只做最小静态检查（配置能否解析、模型和变体是否对应、每个自定义 agent 是否有同名提示词文件、写代码的 agent 是否包含 `personal-code-prompt`）。报告改了什么、哪些没验证，让用户重启生效；未经授权不重启、不调用付费模型、不动入口或快捷方式。

### 关于 install.ps1

`install.ps1` 只是**已经装好匹配版本时**的可选快捷方式，不是跨版本主流程。它有多处交互会停下来等确认，不适合 agent 无人值守时直接跑，否则会挂在 `Read-Host`；agent 应优先按上面的 skill 步骤做，用户也可以选择自己手动运行脚本。

不要期待完全无人干预，也不要指望它在任意系统自动安装 OpenCode 或依赖。OpenCode 还没安装时，先向用户说明需要装什么、请求授权，得到同意再装。

## 目录结构

```
my-personal-vibecoding-skills/
├── README.md
├── install.ps1                  # 便捷安装到 OpenCode 2 配置目录（版本证据不满足则停）
├── sync.ps1                     # 仓库 <-> opencode 运行目录的同步脚本
├── personal-code-prompt/        # skill 1
│   ├── SKILL.md
│   ├── code-template.md         # 该 skill 自己的资源文件
│   ├── prompt-template.md
│   └── sources.md
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
.\sync.ps1 -Direction Push -Skill personal-code-prompt  # 只同步一个 skill
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
| `personal-code-prompt` | 个人项目的代码与 Prompt 编写约定 |
| `agent-setup` | 多 agent 配置的设计原则（`PRINCIPLES.md`）、当前配置快照（`snapshot/`，已去除密钥），以及在新机器或新版本 OpenCode 上照着配置的步骤 |

### 在新机器上恢复 agent 配置

1. 克隆本仓库，用 `sync.ps1 -Direction Push -Target <OpenCode 的 skills 目录>` 安装全部 skill。V2 的 skills 目录在它的配置目录下。
2. 设置快照里用到的密钥环境变量，变量名见 `agent-setup/snapshot/opencode-v2/opencode.jsonc` 中的 `{env:...}`。
3. 重启 OpenCode，对 agent 说「用 agent-setup 按原则配置本机」。

**不要提交任何真实密钥。**

## 便捷安装（install.ps1）

> 可选的手动快捷方式，不是跨版本主流程；交给 agent 配置请走上面的入口。

用 `install.ps1` 把 `snapshot/opencode-v2` 和仓库根目录的两个 skill 安装到 OpenCode 2 配置目录。

它**不是任何机器、任何版本都能一键跑通**：只有在能证明版本一致时才写入，否则一律在写入前停下。脚本只做安装，不安装 OpenCode 或依赖，不启动 OpenCode，不调用模型，不改启动脚本和快捷方式。

### 前提

- Windows PowerShell 5.1 或更晚。
- 目标机器已经装好 **OpenCode 2.0.23**（脚本读取实际 CLI 的版本）。
- 目标配置目录里已经声明并装好 **oh-my-opencode-slim 3.0.2**。
- 知道 OpenCode 2 的配置目录路径；脚本不会替你猜，必须由你给出或确认。

### 最短安装命令

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -ConfigDir "D:\path\to\opencode\config"
```

`-ConfigDir` 指向 OpenCode 2 的配置目录本身（即 `.../config/opencode`）。

不传 `-ConfigDir` 时，脚本先看 `OPENCODE_CONFIG_DIR`；都没有就把默认位置只当作候选项列出，**无论候选有几个都必须由你确认**（或直接输入另一个绝对目录），不会自动选中，也不按文件名猜 V1。

### 版本证据（不满足就停）

脚本只在下面三条都能从真实证据成立时才写入：

- OpenCode 版本：运行实际选定的 CLI `--version`，必须等于 2.0.23。先过这一关。
- 插件缓存目录：用同一个 CLI 运行 `opencode debug paths cache`。按 v2 文档，这条命令只读本地路径，不启动 server、不打开数据库。输出必须是恰好一个有效的绝对目录，否则停止。脚本不再推测任何缓存路径。
- oh-my-opencode-slim 版本：读取目标配置里 `plugin` 与 `plugins` 的声明（字符串或 `{package, options}`，两者会被合并）。必须恰好一条、精确固定为 `oh-my-opencode-slim@3.0.2`；有重复冲突、未固定（标签/范围）或没有声明都会停止。

然后按 v2.0.23 的 npm 缓存规则检查包：`<cache>\npm\oh-my-opencode-slim@3.0.2\<最大数字 generation>\node_modules\oh-my-opencode-slim\package.json`。固定版本命中缓存时会复用最大 generation，所以只认最大数字 generation；若它没有有效 package（name/version 不是 `oh-my-opencode-slim@3.0.2`）就停止，**不会**降级到旧的 generation。

脚本会把「CLI 路径与版本」「配置目录及其来源」「CLI 返回的缓存目录」「配置里的 plugin 声明」「解析到的 generation 和插件包路径与版本」都打印出来；其中配置目录是你给出或确认的，不是脚本探测到的。

### 运行环境限制（安装前必须确认）

上面解析到的是：**在同一启动环境里通过选定 CLI 启动 OpenCode 时，这份配置将加载的插件包**。它不证明一个已经在运行的服务所使用的插件版本——独立启动的服务可能有不同的环境变量。因此写入前脚本会要求你明确确认：今后将通过这个 CLI、这份配置和这个缓存环境启动或重启 OpenCode；不确认就停止并交给 `agent-setup`。脚本不会自动改服务、入口，也不会替你重启。

### 脚本会做什么

1. 定位目标配置目录（显式/环境变量，否则由你确认候选或输入绝对路径）。
2. 先用选定 CLI 过 2.0.23 门禁，再让同一 CLI 报缓存目录，并按上面的规则核对插件声明与包；任一不满足就**在写入之前停止**。
3. 展示目标、覆盖范围和本地改动过的冲突文件，并要求你确认启动环境；确认后先把要覆盖的文件备份到带日期的目录，再写入：
   - 配置：`opencode.jsonc`、`AGENTS.md`、`oh-my-opencode-slim.json`、`oh-my-opencode-slim\`、`plugins\handoff.ts`
   - 两个 skill：`skills\agent-setup\`、`skills\personal-code-prompt\`
4. 不复制 `snapshot/machine-specific/` 启动脚本，不改入口或快捷方式；快照里的本机绝对路径只有在属于用户目录时才替换为当前用户目录，遇到无法安全适配的路径就停止。
5. 提示配置里用到的 API key 环境变量（`FINNSCODE_API_KEY`、`COMMANDCODE_API_KEY`、`COPILOT_API_KEY`），用隐藏输入设置到用户环境变量；已有值默认保留，真实 key 既不显示也不写文件。
6. 静态解析 `opencode.jsonc` 和 `oh-my-opencode-slim.json`，最后提示重启。

已存在的同名文件如果和快照内容不同，会作为「本地改动」单独列出并需要你确认，不会静默覆盖，也不会删除无关文件。

### 备份与恢复

- 每次安装前，被覆盖的文件会备份到配置目录同级的 `opencode-backup-<yyyyMMdd-HHmmss>\`，并保留相对路径；只新增、不被覆盖的文件不需要备份。
- 恢复时，把备份目录里的文件按相同相对路径拷回配置目录：

```powershell
Copy-Item .\opencode-backup-20261008-120000\* "D:\path\to\opencode\config" -Recurse -Force
```

### 停下时怎么办（版本或证据不匹配出口）

如果脚本报版本不匹配，或报读不到恰好一个有效缓存目录、读不到唯一固定的插件声明、最大 generation 里没有有效包，说明本机的版本或证据和快照对不上，脚本不会写任何东西。这时不要硬套快照，改用 `agent-setup` skill：它会按 `PRINCIPLES.md` 把配置适配到本机版本。模型是否可用安装脚本不检测，重启后需要你在本机自行确认。
