# 代码短样例

以下样例只示意写法，不是可运行脚手架，也不暗示必须建类或注册表。注释里的数字和业务规则都是示意，实际取值按自己项目的测量和已确认的业务规则写。

## 1. 薄业务编排

主入口按业务顺序自上而下，每行对应一个阶段，细节在各自模块。

```python
def run_daily_report(date):
    raw = recall_items(date)              # 召回
    filtered = filter_items(raw)          # 筛选
    chosen = choose_items(filtered)       # 选择
    drafts = write_drafts(chosen)         # 写作
    extras = build_extras(chosen)         # 辅助栏目，失败时为 None，不影响主报
    check_release(drafts)                 # 发布检查，不通过直接抛错
    return render_report(drafts, extras)  # 渲染
```

要点：

- 编排层只做顺序和衔接，读到这里就能看清整条业务链路。
- 每个阶段的具体判断都在自己的模块里，不在这里展开。
- 这里的阶段名来自业务，不是技术分层。
- 失败分级在阶段内部处理（见样例 4、5），编排层不写 try/except，保持一行一个阶段。

## 2. settings 里的取值理由与 Prompt 版本

业务常量、失败处理参数与 Prompt 版本集中放一处，并写清为什么是这个值。

```python
# 单个事件最多保留 5 条证据，超过后信噪比下降、人工复核成本反而上升
MAX_EVIDENCE_PER_ITEM = 5

# 召回窗口取 7 天，覆盖周末停更后周一补发的情况
RECALL_WINDOW_DAYS = 7

# 只收这几个来源：其他来源以转载为主，重复多且常缺原始链接
ALLOWED_SOURCES = {"source_a", "source_b", "source_c"}

# 模型调用超时 90 秒：写作阶段正常请求最慢约 40 秒，留出余量；超时按所在阶段的失败处理
MODEL_TIMEOUT_SECONDS = 90

# 格式纠错最多重试 2 次：格式错误通常一次纠正即可，再多只增加成本
MAX_FORMAT_RETRIES = 2

# 改写 Prompt 只换版本，代码通过常量引用，旧版本目录保持不动
CHOOSE_PROMPT_VERSION = "choose_v2"
DRAFT_PROMPT_VERSION = "draft_v3"
```

要点：

- 注释解释取值原因，不复述变量名。
- 常量集中在一处，改值时只改一个地方。
- 超时、重试次数这类失败处理参数也放这里，同样写理由。
- Prompt 版本用常量引用，方便新旧版本对照回放。

## 3. 业务阶段模块

一个阶段一个职责，兜底与输入校验只对应明确的业务需要，失败处理显式。

> 下面例子里的"标题缺失跳过""来源白名单"仅假设该业务已确认，不是所有项目的通用默认。

```python
def filter_items(raw_items):
    kept = []
    for item in raw_items:
        if not item.get("title"):
            continue  # 已确认规则：标题缺失无法判断主题，跳过
        if item["source"] not in ALLOWED_SOURCES:
            continue
        kept.append(item)
    return kept
```

要点：

- 只做"筛选"这一件事，不顺手做排序、去重或渲染；时间窗口属于召回阶段，这里不重复检查。
- 两个字段的取法不同是有意的：标题缺失是上游的已知常态，按确认规则跳过，所以用 `get`；`source` 由召回阶段保证，缺失说明上游出了错，用 `[]` 让它直接报错，不在这里兜住。
- 只校验业务所需的边界输入，不做泛化防御或层层检查。

## 4. 辅助分支隔离

辅助分支失败不拖垮主产物，但失败要留下记录，并且在最终产物里看得出缺了什么。

```python
def build_extras(chosen):
    # 辅助栏目失败不影响主报：只在这一处兜住，主报照常发布，渲染时标注本期缺少辅助栏目
    try:
        return write_extras(chosen)
    except Exception:
        logger.exception("辅助栏目生成失败，主报照常发布")
        return None
```

要点：

- 只在辅助分支的边界捕获一次，内部不再层层 try/except。
- 失败要留记录（`logger.exception` 带堆栈），并让最终产物能看出缺了什么（这里由 `render_report` 在 `extras is None` 时标注），不能悄悄少一块。
- 这里捕获 `Exception` 是有意的：辅助分支无论什么原因失败，都不该拖垮主报；`KeyboardInterrupt` 不属于 `Exception`，不会被吞掉。
- 核心阶段（召回、筛选、选择、写作、发布检查）不这样写，失败直接抛出。

## 5. 模型调用阶段

格式契约的定义、发送、校验共用一个结构定义；纠错只说本次违反的那条；重试有上限；每次调用留痕。

```python
def choose_items(filtered):
    if not filtered:
        # 选择结果不允许为空：没有候选时由代码拦下，不让模型硬选
        raise StageFailed("选择阶段没有候选，主报无法生成")

    base_prompt = render_prompt(CHOOSE_PROMPT_VERSION, candidates=filtered)
    prompt = base_prompt
    for _ in range(MAX_FORMAT_RETRIES + 1):
        raw = call_model(prompt, schema=CHOOSE_SCHEMA, timeout=MODEL_TIMEOUT_SECONDS)
        problem = find_contract_violation(raw, CHOOSE_SCHEMA, filtered)
        log_model_call("choose", CHOOSE_PROMPT_VERSION, prompt, raw, problem)
        if problem is None:
            return parse_choices(raw)
        prompt = with_retry_note(base_prompt, problem)
    raise StageFailed(f"选择阶段格式纠错 {MAX_FORMAT_RETRIES} 次后仍不合规：{problem}")
```

要点：

- `CHOOSE_SCHEMA` 同时用于发送和校验，只有一个结构定义源；发送了 schema，Prompt 正文仍要说明各字段的语义。
- `find_contract_violation` 除了查结构，还核对回填的候选 ID 都来自输入，返回第一条具体违规；结构正确不等于语义正确。
- 纠错在原始 Prompt 上只追加本次违规说明，不把历次纠错越叠越长；纠错文字写法见 `prompt-template.md`。
- `log_model_call` 记录阶段名、Prompt 版本、渲染后的 Prompt、原始返回和校验结论，连同 settings 里的模型名与参数一起写一行 jsonl，供 bad case 定位使用。
- 选择是核心阶段：没有候选或重试用尽都直接抛错，不返回空列表假装成功。
