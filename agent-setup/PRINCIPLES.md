# 多 agent 配置的设计原则

本文件是这套配置的唯一依据。`snapshot/` 里的文件只是这些原则在某个具体版本上的写法。OpenCode、插件或配置格式变了，以本文件为准重新落地，不要照抄旧格式。

最后更新：2026-10-11。当时的环境是 OpenCode V2 2.0.25 和 oh-my-opencode-slim 3.0.2。

### 推理档位必须有明确参数

agent 的 `variant` 名称与模型定义中的实际请求参数要对应，不能只列 `high: {}` 之类的空档位。当前 finnscode 的 OpenAI SDK 配置在各档位显式设置 `reasoningEffort`，值与档位名一致；其他渠道或 SDK 应按其支持的参数填写，不机械套用。2026-10-11 补齐后，用户在上游网关确认本轮非 Claude 专家的档位显示正确；Opus、Sonnet 因额度不足未参与本轮调用验证。`service_tier` 与推理档位独立，不因设置推理档位而开启 Fast/Priority。

## 一、角色与分工

- **orchestrator**：负责安排工作、派活、汇总结果和对用户汇报，不是默认干活的人。只有用户明确说「你自己做」「别派」时才亲自动手，这时这条规则优先于插件自带的委派规则。所有文字沟通一律用简体中文，包括对用户的回复、orchestrator 派给专家的任务说明，以及专家的进度说明、提问和交回的结果，方便用户直接看懂子会话；即使提示词、专家结果或工具输出是英文也一样。这条写在所有 agent 共用的 `AGENTS.md` 里，orchestrator 提示词里再补一句。代码、命令、路径、模型名、字段名和报错保持原样，只有用户明确要求才换语言。专家提示词里规定的固定英文格式标签（如 fixer 的 `summary`）保留，因为 orchestrator 依赖这套格式读取结果。
- **explorer**：只读，负责在代码里找东西，返回文件和行号，加上简短结论。
- **oracle**：只读，负责架构、调试思路和审查。只在问题复杂、拿不准或用户要求时才参与，不是固定步骤。
- **librarian**：负责查外部资料，每条结论都要带来源。
- **fixer**：在划定的范围内写代码，不做研究，也不做设计决定。
- **designer**：负责界面和交互。
- **validator**：只核对业务规则有没有落实，不做测试、审查或修复。
- council 和 observer 已禁用。

## 二、模型分配

- 一个 agent 只对应一个模型，不开 fallback。模型出错时，由用户决定是重试还是换模型。
- 默认角色用便宜、快的模型，带模型名的版本默认用来对比或点名使用；自动轮换的例外（fixer、explorer/librarian、validator 三组）见下面表格后的说明：

| 角色 | 默认模型 | 带模型名的版本 |
|---|---|---|
| 主会话 | GPT-6.1 Sol medium | — |
| oracle | GPT-6.1 Sol max | oracle-opus（Claude Opus 5.5 high）、oracle-astra（GPT-6 Astra medium） |
| explorer | clinepass DeepSeek V4.1 Flash high | explorer-gemini（Gemini 3.8 Flash high）、explorer-luna（GPT-6 Luna max） |
| librarian | clinepass DeepSeek V4.1 Flash high | librarian-gemini、librarian-luna（同上） |
| fixer | clinepass DeepSeek V4.1 Flash high | fixer-grok（Grok 4.7 high）、fixer-sol（GPT-6.1 Sol Fast high）、fixer-sonnet（Claude Sonnet 5.5 high） |
| designer | Gemini 3.8 Flash high | — |
| validator | Grok 4.7 high | validator-sol（GPT-6.1 Sol Fast xhigh） |

- 带模型名的版本默认只在用户点名使用或要求跨模型比较时才派，平时不消耗 token。**例外有三组会自动轮换：fixer 组、explorer/librarian 组、validator 组，规则如下。**
- **fixer 组（fixer-grok、fixer-sol）**：实现任务按难度分流，改动涉及多个文件、需要分几步依次完成，或默认 fixer 已经试过但没改成时，交给这两个之一；单文件小改和机械替换仍交给默认 fixer。两者等量交替使用：每个新的较难任务交给上一次没用的那个，需要并行时尽量平分，不只用其中一个；同一任务的返工或后续仍交给原来那个，因为它已有上下文。交替只在当前会话内记得，新会话或压缩后从哪个开始不固定。原因是 DeepSeek Flash 做 fixer 风险最高，而 Grok 和 Sol 更适合长时间、多步骤的编程任务，交替使用也能比较两者表现。模型或服务报错不算「没改成」，仍按专家失败规则由用户决定。fixer-grok 和 fixer-sol 都用 high，是用户为可靠性做的选择。
- **explorer 组和 librarian 组**：各自按「默认 → Gemini → Luna」的顺序循环，即 explorer 组按 clinepass DeepSeek V4.1 Flash high → explorer-gemini（Gemini 3.8 Flash high）→ explorer-luna（GPT-6 Luna max）→ 回到默认，librarian 组同理（librarian → librarian-gemini → librarian-luna）。每个新的独立检索任务交给轮换顺序中的下一个，不再只在点名时才用变体；需要并行多个独立任务时按该顺序尽量平分，且不重复检索同一内容。同一任务的补充或继续沿用原会话原专家，不推进轮换。用户点名时遵从用户；用户要求同一问题跨模型比较时，保留各专家独立同题检索，不并入普通轮换。轮换顺序只在当前会话内保持，不建立持久化调度、脚本或系统。
- **validator 组（validator、validator-sol）**：每次需要业务规则核对时，在默认 @validator（Grok 4.7 high）与 @validator-sol（GPT-6.1 Sol Fast xhigh）之间交替，每个新的核对任务交给本会话上一次未使用的那个；需要并行核对不同任务时尽量平分；用户指定时按指定执行；同一核对任务的补充或继续沿用原专家。交替顺序只在当前会话内保持，新会话起始专家不固定。两者仅核对用户已确认的业务规则，核对范围、只读权限与逐次命令授权限制不变。
- 新增自定义 agent 时，一定要配一个同名的提示词文件，否则插件只会给它一句「你是某某专家」。

## 三、协作规则

1. **explorer → oracle**：explorer 查过的内容，orchestrator 原样转给 oracle，不改写。oracle 以这些结果为起点；如果结论取决于具体代码、结果互相矛盾或可能已经过期，或者任务本身就是审查代码，oracle 就自己去读相关的那几处，但不重新搜索整个项目。不知道该去哪里找时，oracle 返回「Need from explorer」，由 orchestrator 让原来的 explorer 补查。补查一般不超过 2 轮。
2. **分析类角色给独立意见**：用户让多个 oracle、explorer 或 librarian 看同一件事时，每个都拿到同样完整的问题和材料，不拆开分。第一轮互相不看对方的结论。汇报时分开说明哪里一致、哪里有分歧，以及 orchestrator 的判断。
3. **写代码的角色按模块分工**：fixer 和 designer 各自负责不同的文件或模块，写入范围不重叠。
4. **业务改动必须核对**：只要改动会改变业务行为（日期、筛选、门禁、存档、计算口径等），不管是谁改的，都要核对。动手前，orchestrator 先把要求写成几条规则请用户确认；拿不到确认就写明「业务规则未核对」。validator 申请运行命令时，只批准事先写明的命令，每次只批一次。
5. **专家失败**：专家因模型或服务报错而失败时，orchestrator 不自己接手，也不擅自换模型，而是告诉用户哪条线失败了，由用户决定。
6. **派活要写清楚**：每个任务都要写明目标、范围、能不能改文件、允许做哪些验证。没有指定的验证就不做。

## 四、范围与验证

- 只做用户明确要求的事。不主动做架构调整、安全审计、重构、补测试，也不搭基础设施。
- 验证不是自动的，只做证明需求已经实现所需的最小检查。
- 改代码或改 Prompt 之前，先加载 `personal-code-prompt` 技能。写代码的 agent 的技能白名单里必须包含它。

## 五、对用户说话

- 先给结论，再讲原因和影响。用平常的话讲清楚发生了什么、影响什么、该怎么做。
- 完成任务时，用几句完整的话说明：结果是什么、做了哪些超出要求的改动以及原因、验证做到了哪一步、用户需要做什么。这不是每条回复都要加的结尾。
- 只有真正并列的内容才用列表。简短和清楚冲突时，选清楚。
- 用户正在配置 agent 时，agent 名称就是讨论的对象，可以直接用。

## 六、各模型提示词要点

依据是各厂商的官方指南，2026-10 查证。

- **GPT（Sol、Astra、Luna）**：严格按指令执行，规则矛盾时会停下来或提前交还，所以要写明「任务说明优先于技能文件」。能自己判断的事就判断，不要停下来问。结论用段落写。查代码、查资料用较低的思考档位就够。
- **Claude Opus**：容易委派过多、检查过多，回复也偏长。审查时要求先把问题全部列出来再排序，不要写「只报严重问题」。
- **Claude Sonnet**：适合范围明确的修改。发现无关问题只汇报，不顺手改。
- **DeepSeek Flash**：用它做 fixer 风险最大。改文件前先读，连续失败两次就停下报告。做 librarian 时每条结论都要带来源。不要在提示词里写「一步一步想」。
- **Gemini Flash**：「不要做什么」放在提示词最后。同一份提示词里只用一种分段格式。查资料时提醒它用当前日期。
- **Grok**：提示词要写详细，修改必须通过工具真正执行。

不照搬的官方建议：「一直做下去，不要问用户」和「改完必须跑测试」都和第四节冲突，所以不采用。

## 七、上下文压缩

- provider 默认用原生压缩（native）。
- Claude 系列和 clinepass DeepSeek 单独设为 summary。原因是代理链路不支持它们的原生压缩：DeepSeek 返回 0 个 checkpoint，Claude 走 CPA 时返回 501。
- 已实测可用：Sol 6.1、Grok 4.7 用 native；Sonnet 5.5、clinepass DeepSeek 用 summary。
- 换了代理或上游后，要重新测试原生压缩，不能默认它可用。

## 八、本地插件

- `handoff`：把当前会话交接到新会话，V2 版本在本地移植。
- 不加载旧的 `opencode-openai-compact`，它只支持 V1，V2 自带压缩已经够用。
