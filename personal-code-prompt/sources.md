# 来源、依据与修订记录

本文件写给维护本 skill 的人，包括被要求修改本 skill 的 agent。执行日常编码或 Prompt 任务时不需要读取。

## 来源

1. 本地原 skill `prompt-engineering`（SKILL.md、prompt-template.md）：本 skill 继承其核心原则并改写为个人自包含版本，属于原则与选择的继承，不是原样复制。原 `prompt-engineering` 已不再维护，仅作为历史来源；本 skill 不依赖任何现存旧目录。
2. 晨报项目：仅作为业务分层与流程样例来源，并非已完全规范化，不作为规范依据。

## 规则依据

"性质"一列区分两类：有外部资料支持的方向，和作者的个人取舍。个人取舍不是缺陷，但修改时要知道它没有外部依据可以引用。

| 规则 | 依据 | 性质 |
|---|---|---|
| 函数 20–80 行只作阅读提示，不按行数硬拆 | [1] §3.18：偏好小而聚焦的函数，不设硬上限，超过约 40 行时考虑能否在不破坏结构的前提下拆分 | 方向有外部依据；20–80 的区间是个人偏好 |
| 业务语言命名、薄编排、注释写 why | [2]："Readability counts""Explicit is better than implicit""Simple is better than complex" | 外部依据 |
| 核心失败不隐藏，辅助失败显式隔离 | [2]："Errors should never pass silently. Unless explicitly silenced." | 方向有外部依据；核心/辅助分级是个人做法 |
| 格式契约单一定义源，不强制 Pydantic | [3]：REST API 接受 JSON Schema，Python/JS SDK 另可用 Pydantic/Zod 定义并解析；[4]：openai-python 的结构化输出解析辅助 | 外部依据 |
| 一个 Prompt 做好一个核心判断 | [7]："Each prompt should do one thing well"；同文也指出拆分会增加调用和延迟 | 方向有外部依据；"强相关附带标注可合并"是个人取舍 |
| 基于旧版对照迭代，输入贴近真实分布并覆盖边界情况 | [5]：eval-driven development，评估数据要贴近真实生产分布；[6]：测试用例贴近真实任务分布、覆盖边界情况，按测试结果迭代 Prompt | 外部依据 |
| 模型调用留痕 | [5]：建议开发期记录日志，供后续挖掘评估用例 | 外部依据 |
| 小范围真实回放，不建评估平台、不做自动评分、不固定样本数 | [5][6] 都倾向更大规模、可自动评分的测试集 | **个人取舍，与外部建议有出入**：个人项目优先控制维护成本；样本量小的风险由"只作定性判断"和"必查原本正确的结果是否变差"部分弥补 |
| 确认流程、防御性代码克制、删除规则需确认 | 无 | **作者明确选择**，见下方维护约束 |

## 链接

以下链接于 2026-10-14 核对可访问。[3][5][6] 的旧地址（platform.openai.com、docs.claude.com）会跳转到下列新地址。

1. Google Python Style Guide（§3.18 Function length）：https://google.github.io/styleguide/pyguide.html
2. PEP 20 – The Zen of Python：https://peps.python.org/pep-0020/
3. OpenAI Structured Outputs：https://developers.openai.com/api/docs/guides/structured-outputs
4. openai-python helpers.md：https://github.com/openai/openai-python/blob/main/helpers.md
5. OpenAI Evaluation best practices：https://developers.openai.com/api/docs/guides/evaluation-best-practices
6. Anthropic Develop tests：https://platform.claude.com/docs/en/test-and-evaluate/develop-tests
7. Anthropic Best practices for prompt engineering：https://claude.com/blog/best-practices-for-prompt-engineering

## 维护约束

修改本 skill 时遵守以下几条：

- 下面三条是作者明确做出的选择，不能以"更合理""更高效"为由自行放宽或反转。要改，先在方案里单独列出，得到作者确认后再改：
  1. 业务行为、架构、Prompt 改动走"出方案 → 用户确认 → 实施"，未授权不运行核对；
  2. 兜底和输入校验必须对应明确的业务需要、失败情形和处理结果；
  3. 删除规则需经用户确认。
- 改写时保持原有平实的语气，不加"绝不""一律""严格"之类的强调词。规则靠写清楚适用条件起作用，强调词容易让模型机械执行。
- 改了 SKILL.md 里的规则，同步检查 `code-template.md`、`prompt-template.md` 中对应的样例和要点，三处说法保持一致。
- 只改被要求改的文件；顺带发现的其他问题列在方案里，不直接动手。
- 每次修订在下方追加记录：改了什么、来源、原因。

## 修订记录

### 2026-10-14

以原版为底，参考两份外部改版（GPT 改版、Gemini 改版）对比后合并。

**采纳**

| 改动 | 来源 | 原因 |
|---|---|---|
| 同步规则补上"返回校验" | Gemini 改版 | 原版正文漏了，检查清单里却有 |
| "五件套"改为"不凑固定数量的文件" | Gemini 改版 | 原对话里的说法，新读者看不懂 |
| Few-shot"只放边界对照案例"写入 SKILL.md | Gemini 改版 | 原来只在模板里 |
| 增加规则优先级（硬边界与写法指导） | GPT 改版，有改写 | 规则冲突时有取舍依据；GPT 原文把"版本组织"列为指导原则，与作者的版本规则冲突，未保留这一项 |
| 效果验证增加三项检查和"模型有波动，只作定性判断" | GPT 改版 | 原版没有检查原本正确的结果是否变差 |
| 输入里没有候选时由代码拦下 | GPT 改版的思路，改为代码拦截 | GPT 原文只写"按既定失败策略"，含糊；放到代码里与"确定性逻辑交给代码"一致 |
| 模型调用留痕 | 新增 | bad case 分层定位的前提 |
| 外部调用超时、格式纠错重试次数上限 | 新增 | 原版没有规定重试次数和重试用尽后的处理 |
| 旧版本目录经确认后清理 | 新增 | 只增不删与"不留死代码"冲突 |
| 已有项目先沿用现有约定 | 新增 | 避免把个人约定强加到已有代码上 |
| description 补上"非个人项目以该仓库约定为准"和 bad case 触发词 | 新增 | 触发范围宽，避免在别人的仓库里套用；原 description 漏了 bad case 场景 |
| 写明"阅读代码和文件不需要额外授权" | 澄清 | 原意如此，写明后避免过度询问 |
| 隔离只在辅助分支边界做一次 | 澄清 | 防止把"隔离"理解成层层 try/except |
| `filter_items` 去掉时间窗口检查，换成来源白名单，说明 `get` 与 `[]` 的区别 | 新增 | 时间窗口属于召回阶段；原样例宽严不一致且没有说明 |
| 新增"辅助分支隔离""模型调用阶段"两个样例，编排样例接入辅助栏目 | 新增 | 规则反复强调，原样例没有演示 |
| settings 样例增加来源白名单、超时、重试次数 | 新增 | 与新样例对应 |
| 判断步骤第 3 条改为指向核心原则里的"不属于"情形 | 新增 | 原措辞"是否命中排除条件"与正面准入冲突 |
| prompt-template 增加纠错文字示例 | 新增 | 原来只有规则，没有写法 |
| sources.md 改为依据表、维护约束、修订记录，链接更新为跳转后的地址 | 新增 | 便于后续维护时区分外部依据与个人取舍 |

**未采纳**

| 改动 | 来源 | 原因 |
|---|---|---|
| 明确要求实施即直接改，本地检查无需授权 | GPT 改版 | 反转了作者的确认流程 |
| 防御性代码改为"针对可预见的实际风险" | GPT 改版 | 放宽了作者的克制原则，"可预见"过于主观 |
| 删除过时规则无需确认 | GPT 改版 | 放宽了作者的规则清理流程 |
| 版本目录仅在语义变化时新建 | GPT 改版 | 改变了作者的版本规则 |
| description 收窄为仅在明确要求时使用 | GPT 改版 | 会导致基本不触发 |
| "清单外"改为"上游给出的候选清单" | GPT 改版 | 语义偏移：原版的清单指 Prompt 自己定义的准入范围或类别，改后丢了"不符合任何类别"的出口 |
| 轻量改动（含用户指定改法的单点修复）可直接实施 | Gemini 改版 | 原版只免除业务验收，没有免除确认；且与"Prompt 改动走完整流程"冲突 |
| 防御性代码条目的压缩写法 | Gemini 改版 | 丢了"失败情形和处理结果"，读起来比原版更死板 |
| 加入"绝不 / 一律 / 严格"等强调词 | Gemini 改版 | 容易让模型机械执行 |
