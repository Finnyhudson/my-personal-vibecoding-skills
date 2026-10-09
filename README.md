# my-personal-vibecoding-skills

个人维护的 AI coding agent skills 集合，用于跨机器/跨项目复用。

## 仓库里有什么

| 内容 | 是什么 | 解决什么问题 |
|---|---|---|
| `agent-setup/` | 我的多 agent 配置：设计原则、当前配置快照（已去掉密钥）、以及让 agent 照着配置的步骤 | 换机器或 OpenCode 升级后，能按同一套思路把配置恢复出来 |
| `personal-code-prompt/` | 我写代码和写 Prompt 的约定 | 让写代码的 agent 按我的习惯做事，而不是按模型自己的偏好 |
| `install.ps1` | 版本完全匹配时的便捷安装脚本 | 同版本机器上少做几步手工操作 |
| `sync.ps1` | 仓库与 OpenCode 运行目录之间的 skill 同步脚本 | 保持两边 skill 内容一致 |

### agent-setup 和原生 oh-my-opencode-slim 的区别

[oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim)（下称 omo-slim）是 OpenCode 的多 agent 插件，提供 orchestrator、explorer、oracle、librarian、fixer、designer 等角色和它们的内置提示词。**agent-setup 不替代它**，而是在它之上叠加我自己的用法。没有 omo-slim，agent-setup 无法单独工作。

| 方面 | 原生 omo-slim | 加上 agent-setup 之后 |
|---|---|---|
| 模型 | 按 preset 推荐，可配 fallback 链 | 每个 agent 固定一个模型，不开 fallback；出错由我决定重试或换模型 |
| 模型版本 agent | 无 | 增加 fixer-grok / fixer-sol / fixer-sonnet、explorer-gemini / explorer-luna、librarian-gemini / librarian-luna、oracle-opus / oracle-astra、validator-sol，平时只在点名或要求跨模型比较时使用；例外是 fixer-grok 和 fixer-sol，多文件、多步骤或默认 fixer 没改成的实现任务在两者之间轮流分配 |
| orchestrator 何时自己动手 | 内置规则：简单的自己做，复杂的派出去 | 只有我明确说「你自己做 / 别派」时才自己做 |
| explorer → oracle | 都经过 orchestrator，没有专门约定 | explorer 结果原样转给 oracle；oracle 只在结论依赖具体代码时定点读，不重扫全仓；缺信息时返回「Need from explorer」补查 |
| 多个专家分析同一件事 | 无专门规则 | 分析类角色拿同一个完整问题、互不看结论、汇报时分开写一致和分歧；写代码的角色仍按模块分工 |
| 业务改动核对 | 无 | 新增 validator：改动业务行为时，先请我确认规则清单，再逐条核对 |
| 范围与验证 | 按插件默认 | 只做明确要求的事；验证只做最小必要的，不自动跑测试或审计 |
| 对我汇报 | 内置「没被问就不总结」 | 完成时用完整句子说明结果、超范围改动的原因、验证情况和需要我做什么 |
| 各模型提示词 | 内置通用写法 | 按各厂商官方建议调整（例如 GPT 写明指令优先级、Gemini 把限制放最后、DeepSeek fixer 连续失败两次就停） |
| 上下文压缩 | 不涉及 | 记录哪些模型用原生压缩、哪些改用 summary 及原因 |

具体规则以 `agent-setup/PRINCIPLES.md` 为准。

### personal-code-prompt 的内容

核心原则：**能确定的事用代码保证，需要语义理解的事才交给模型。**

- **动手前**：先分清哪部分该由模型做、哪部分该由代码做；确认本次授权范围（能改哪些文件、能不能跑测试或外部请求）。
- **新项目起步**：依次确认目标与非目标、输入输出、真实业务步骤、模型与代码分工、失败处理，然后只建当前需要的文件。
- **写代码**：主入口按业务顺序薄编排；命名用业务语言；业务常量和 Prompt 版本集中放在 settings 并说明原因；遵循 YAGNI，不加没有需求的防御和框架；辅助步骤失败要隔离，核心步骤失败不隐藏。
- **写 Prompt**：一个 Prompt 只承担一个核心语义任务；用正面准入加「无结果」出口，不堆排除项；输入最小充分，输出最小必要；确定性的去重、排序、截断交给代码；格式契约要同时覆盖定义、发送和返回校验。
- **修改流程**：出方案 → 用户确认 → 实施 → 按确认的规则核对 → 汇总。
- **bad case**：先定位问题出在 Prompt、上游输入、代码、下游还是节点设计，确认是 Prompt 问题才改 Prompt；新版本放新目录，旧版不动。
- **效果验证**：经授权后，用同一批真实输入对比新旧版本的最终业务结果，不能只因格式正确就说效果变好。

附带资源：`code-template.md`（代码样例）、`prompt-template.md`（Prompt 模板与上下游分工）、`sources.md`（来源与继承边界）。

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
├── personal-code-prompt/        # 代码与 Prompt 约定
│   ├── SKILL.md
│   ├── code-template.md         # 该 skill 自己的资源文件
│   ├── prompt-template.md
│   └── sources.md
└── agent-setup/                 # 多 agent 配置原则与快照
    ├── SKILL.md
    ├── PRINCIPLES.md            # 设计原则（以它为准）
    └── snapshot/                # 当前配置快照，密钥已换成 {env:...}
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
- 目标机器已经装好 **OpenCode 2.0.25**（脚本读取实际 CLI 的版本）。
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

- OpenCode 版本：运行实际选定的 CLI `--version`，必须等于 2.0.25。先过这一关。
- 插件缓存目录：用同一个 CLI 运行 `opencode debug paths cache`。按 v2 文档，这条命令只读本地路径，不启动 server、不打开数据库。输出必须是恰好一个有效的绝对目录，否则停止。脚本不再推测任何缓存路径。
- oh-my-opencode-slim 版本：读取目标配置里 `plugin` 与 `plugins` 的声明（字符串或 `{package, options}`，两者会被合并）。必须恰好一条、精确固定为 `oh-my-opencode-slim@3.0.2`；有重复冲突、未固定（标签/范围）或没有声明都会停止。

然后按 v2.0.25 的 npm 缓存规则（与 v2.0.23 相同）检查包：`<cache>\npm\oh-my-opencode-slim@3.0.2\<最大数字 generation>\node_modules\oh-my-opencode-slim\package.json`。固定版本命中缓存时会复用最大 generation，所以只认最大数字 generation；若它没有有效 package（name/version 不是 `oh-my-opencode-slim@3.0.2`）就停止，**不会**降级到旧的 generation。

脚本会把「CLI 路径与版本」「配置目录及其来源」「CLI 返回的缓存目录」「配置里的 plugin 声明」「解析到的 generation 和插件包路径与版本」都打印出来；其中配置目录是你给出或确认的，不是脚本探测到的。

### 运行环境限制（安装前必须确认）

上面解析到的是：**在同一启动环境里通过选定 CLI 启动 OpenCode 时，这份配置将加载的插件包**。它不证明一个已经在运行的服务所使用的插件版本——独立启动的服务可能有不同的环境变量。因此写入前脚本会要求你明确确认：今后将通过这个 CLI、这份配置和这个缓存环境启动或重启 OpenCode；不确认就停止并交给 `agent-setup`。脚本不会自动改服务、入口，也不会替你重启。

### 脚本会做什么

1. 定位目标配置目录（显式/环境变量，否则由你确认候选或输入绝对路径）。
2. 先用选定 CLI 过 2.0.25 门禁，再让同一 CLI 报缓存目录，并按上面的规则核对插件声明与包；任一不满足就**在写入之前停止**。
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
