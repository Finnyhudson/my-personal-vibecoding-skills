# my-personal-vibecoding-skills

这是我的 OpenCode 多 agent 配置（设计原则 + 配置快照 + 安装脚本）以及两个 skill，依赖 [oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim) 才能工作。`agent-setup/PRINCIPLES.md` 是这套配置的唯一依据，`agent-setup/snapshot/` 只是这些原则在某个版本上的写法；需要细节时以原则为准。

## 快速开始：选一条路

| 路线 | 适用情况 | 怎么做 |
|---|---|---|
| A. 交给 agent（默认） | 想按原则把本机适配到最新版本/格式 | 把下面 A 节那句提示词交给一个能读写文件、能执行命令的 agent |
| B. 手动运行 install.ps1 | 插件正好是 3.0.4，只想少做几步手工操作 | 自己按 B 节运行 `install.ps1` |

## A. 让 agent 帮我配置

把下面这句话连同仓库地址交给一个能读写文件、能执行命令的 agent：

> 读取这个仓库的 README，安装并加载 agent-setup 和 personal-code-prompt，按原则帮我完成本机智能体配置；先备份现有配置，保留不冲突的本机设置，需要密钥或替换模型时再问我。

仓库地址：https://github.com/Finnyhudson/my-personal-vibecoding-skills

已经克隆到本机时，直接把那个目录路径告诉 agent 也行（本机现有检出在 `D:\PycharmProjects\my-personal-vibecoding-skills`）；克隆和用现有检出都可以，agent 自己会找到仓库根目录。agent 会按 `agent-setup/SKILL.md` 的步骤执行，改动前先备份现有配置，遇到和本机已有设置冲突的地方会先列出来问你，不会静默覆盖。

启动阶段的要求：agent 必须先**实际调用 skill 工具加载** `agent-setup` 和 `personal-code-prompt`，不能把「读过文件」说成「已加载」；配置步骤同样在 `agent-setup/SKILL.md` 里。如果宿主需要重启才能识别新 skill，agent 要明确说明，并告诉你在重启后继续，而不是假装当前会话已经加载。

## B. 手动运行 install.ps1

`install.ps1` 只是**插件版本为 3.0.4 时**的可选快捷方式，不是跨版本主流程；要按原则适配本机，请走路线 A。

### 前提

- Windows PowerShell 5.1 或更新。
- 目标机器已经装好 **OpenCode 2**：快照在 2.0.25 上验证过，但**不限定 OpenCode 版本**——脚本只打印实际 CLI 报出的版本，读不到才停止。
- 目标配置目录里已经声明并装好 **oh-my-opencode-slim@3.0.4**（插件版本精确固定）。
- 知道 OpenCode 2 的配置目录路径；脚本不会替你猜，必须由你给出或确认。
- 脚本有多处交互会停下来等确认，**不适合无人值守**，agent 直接跑会挂在 `Read-Host`。

### 最短安装命令

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -ConfigDir "D:\path\to\opencode\config"
```

`-ConfigDir` 指向 OpenCode 2 的配置目录本身（即 `.../config/opencode`）。

不传 `-ConfigDir` 时，脚本先看 `OPENCODE_CONFIG_DIR`；都没有就把默认位置只当作候选项列出，**无论候选有几个都必须由你确认**（或直接输入另一个绝对目录），不会自动选中，也不按文件名猜 V1。

### 脚本会问你什么

- 目标目录与覆盖范围：展示要写入的文件、要覆盖的文件，以及和快照内容不同的「本地改动」文件，这些会单独列出并要求你确认，不会静默覆盖。
- 启动环境确认：写入前必须确认今后将通过这个 CLI、这份配置和这个缓存环境启动或重启 OpenCode。
- 环境变量：提示你设置配置里引用的环境变量，见「密钥与环境变量」一节。

### 脚本能力边界

只做安装：不装 OpenCode 或依赖，不启动 OpenCode，不调用模型，不改入口和快捷方式，不复制 `snapshot/machine-specific/`，不检测模型是否可用。

### 备份与恢复

- 每次安装前，被覆盖的文件会备份到配置目录同级的 `opencode-backup-<yyyyMMdd-HHmmss>\`，并保留相对路径；只新增、不被覆盖的文件不需要备份。
- 恢复时，把备份目录里的文件按相同相对路径拷回配置目录：

```powershell
Copy-Item .\opencode-backup-20261008-120000\* "D:\path\to\opencode\config" -Recurse -Force
```

### 停下时改走 A

如果脚本报插件版本和快照不一致，或报读不到恰好一个有效缓存目录、读不到唯一固定的插件声明、最大 generation 里没有有效包，说明本机的版本或证据和快照对不上，脚本不会写任何东西。这时不要硬套快照，改走路线 A：交给 agent，由它按 `PRINCIPLES.md` 把配置适配到本机版本。

## 密钥与环境变量

快照里的密钥和网关地址都写成 `{env:...}` 占位符，变量名必须与快照一致：

- 密钥：`FINNSCODE_API_KEY`、`COMMANDCODE_API_KEY`、`COPILOT_API_KEY`
- 网关地址：`FINNSCODE_BASE_URL`、`COMMANDCODE_BASE_URL`

密钥用**隐藏输入**，地址（`*_BASE_URL`）用**可见输入**，因为地址不是密钥；已有值默认保留。地址变量缺失时，配置里的地址会被替换成空字符串，所以必须**在重启前**设置好。

**不要提交任何真实密钥。** 真实 key 既不显示也不写文件。运行 `install.ps1` 时会提示你设置配置里引用的全部环境变量（值不打印）；其余安装方式（含路线 A）由 agent 提醒你设置。

## 仓库结构

```
my-personal-vibecoding-skills/
├── README.md
├── install.ps1                    # 插件 3.0.4 时的便捷安装脚本
├── sync.ps1                       # 仓库 <-> OpenCode 运行目录的 skill 同步脚本
├── agent-setup/                   # 多 agent 配置原则与快照
│   ├── SKILL.md
│   ├── PRINCIPLES.md              # 设计原则（唯一依据，以它为准）
│   └── snapshot/
│       ├── opencode-v2/           # 当前配置快照，密钥已换成 {env:...}
│       │   ├── opencode.jsonc
│       │   ├── AGENTS.md
│       │   ├── oh-my-opencode-slim.json
│       │   ├── oh-my-opencode-slim/   # 各 agent 的提示词文件
│       │   └── plugins/handoff.ts
│       └── machine-specific/      # 本机启动脚本，仅供参考，安装脚本不复制
└── personal-code-prompt/          # 代码与 Prompt 约定
    ├── SKILL.md
    ├── code-template.md
    ├── prompt-template.md
    └── sources.md
```

`personal-code-prompt` 的核心原则：**能确定的事用代码保证，需要语义理解的事才交给模型。**

## 维护

### 目录约定

- **目录名必须等于 `SKILL.md` frontmatter 里的 `name`**，否则 opencode 校验不一致会导致加载失败。
- 扁平一层，不嵌套分类目录；skill 的资源文件放它自己目录内，用相对路径引用。
- opencode 默认扫描运行目录的 `skills/`，因此**不要**再配置 `skills.paths` 指向本仓库，否则同名 skill 会被注册两次。

### 同步（sync.ps1）

仓库和运行目录是两份独立文件，靠脚本保持一致：

```powershell
.\sync.ps1                                              # 只报告差异，不做改动（默认）
.\sync.ps1 -Direction Push                              # 仓库 -> 运行目录
.\sync.ps1 -Direction Pull                              # 运行目录 -> 仓库
.\sync.ps1 -Direction Push -Skill personal-code-prompt  # 只同步一个 skill
.\sync.ps1 -Target "$env:USERPROFILE\.claude\skills"    # 同步到另一个 skill 目录
```

如果执行策略拦截，用 `powershell -ExecutionPolicy Bypass -File .\sync.ps1`。

行为说明：

- 比较时忽略 CRLF/LF 差异，行尾符变化不会被误报为内容不一致；二进制文件按原始字节比较。
- **不会删除**只存在于一侧的文件，只报告 `repository only` / `runtime only`。
- 运行目录里没有仓库对应物的 skill 报告为 `ORPHAN`，**不参与同步**，避免把第三方 skill 误拉进仓库。

skill 内容变化后需要**重启 opencode** 才会生效。

## 和原生 oh-my-opencode-slim 的区别

[oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim)（下称 omo-slim）是 OpenCode 的多 agent 插件，提供 orchestrator、explorer、oracle、librarian、fixer、designer 等角色和它们的内置提示词。**agent-setup 不替代它**，而是在它之上叠加我自己的用法。没有 omo-slim，agent-setup 无法单独工作。

| 方面 | 原生 omo-slim | 加上 agent-setup 之后 |
|---|---|---|
| 模型 | 按 preset 推荐，可配 fallback 链 | 每个 agent 固定一个模型，不开 fallback；模型出错由用户决定重试还是换模型 |
| 模型版本 agent | 无 | 增加 fixer-grok / fixer-sol / fixer-sonnet / fixer-astra、explorer-gemini / explorer-luna、librarian-gemini / librarian-luna、oracle-opus / oracle-astra、validator-sol；默认只在点名或要求跨模型比较时使用。自动轮换的例外现在只剩 validator 组（validator 与 validator-sol 交替），fixer、explorer、librarian 组改为按职责难度与并行需要按需派发 |
| orchestrator 何时自己动手 | 内置规则：简单的自己做，复杂的派出去 | 只有用户明确说「你自己做」「别派」时才亲自动手 |
| explorer → oracle 衔接 | 都经过 orchestrator，没有专门约定 | explorer 结果原样转给 oracle；oracle 只在结论依赖具体代码时才定点读，不重扫全仓；缺信息时返回「Need from explorer」补查 |
| 多个专家分析同一件事 | 无专门规则 | 分析类角色拿同一个完整问题、互不看结论、汇报时分开写一致和分歧；写代码的角色仍按模块分工 |
| 业务改动核对 | 无 | 新增 validator：改动业务行为时，先请用户确认规则清单，再逐条核对 |
| 范围与验证 | 按插件默认 | 只做明确要求的事；验证只做最小必要的，不自动跑测试或审计 |
| 对我汇报 | 内置「没被问就不总结」 | 完成时用完整句子说明结果、超范围改动的原因、验证情况和用户需要做什么 |
| 各模型提示词 | 内置通用写法 | 按各厂商官方建议调整（例如 GPT 写明指令优先级、Gemini 把限制放最后、DeepSeek fixer 连续失败两次就停） |
| 上下文压缩 | 不涉及 | provider 默认原生压缩；Claude 系列与 clinepass DeepSeek 单独设为 summary，并记录原因 |

其余细节以 `agent-setup/PRINCIPLES.md` 为准。

## 社区认可与友情链接
[LINUX DO](https://linux.do/) - 新的理想型社区
