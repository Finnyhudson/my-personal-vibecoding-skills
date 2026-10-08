# 代码短样例

三个短样例只示意写法，不是可运行脚手架，也不暗示必须建类或注册表。

## 1. 薄业务编排

主入口按业务顺序自上而下，每行对应一个阶段，细节在各自模块。

```python
def run_daily_report(date):
    raw = recall_items(date)          # 召回
    filtered = filter_items(raw)      # 筛选
    chosen = choose_items(filtered)   # 选择
    drafts = write_drafts(chosen)     # 写作
    check_release(drafts)             # 发布检查
    render_report(drafts)             # 渲染
    return drafts
```

要点：

- 编排层只做顺序和衔接，读到这里就能看清整条业务链路。
- 每个阶段的具体判断都在自己的模块里，不在这里展开。
- 这里的阶段名来自业务，不是技术分层。

## 2. settings 里的取值理由与 Prompt 版本

业务常量与 Prompt 版本集中放一处，并写清为什么是这个值。

```python
# 单个事件最多保留 5 条证据，超过后信噪比下降、人工复核成本反而上升
MAX_EVIDENCE_PER_ITEM = 5

# 召回窗口取 7 天，覆盖周末停更后周一补发的情况
RECALL_WINDOW_DAYS = 7

# 改写 Prompt 只换版本，代码通过常量引用，旧版本目录保持不动
DRAFT_PROMPT_VERSION = "draft_v3"
```

要点：

- 注释解释取值原因，不复述变量名。
- 常量集中在一处，改值时只改一个地方。
- Prompt 版本用常量引用，方便新旧版本对照回放。

## 3. 业务阶段模块

一个阶段一个职责，兜底与输入校验只对应明确的业务需要，失败处理显式。

> 下面例子里的"标题缺失跳过""时间窗口"仅假设该业务已确认，不是所有项目的通用默认。

```python
def filter_items(raw_items):
    """筛掉与当日业务无关的条目。"""
    kept = []
    for item in raw_items:
        if not item.get("title"):
            continue  # 标题缺失无法判断，跳过
        if item["published_at"] < recall_start_date():
            continue
        kept.append(item)
    return kept
```

要点：

- 只做"筛选"这一件事，不顺手做排序、去重或渲染。
- 只校验业务所需的边界输入（如缺标题、时间范围外），不做泛化防御或层层检查。
- 辅助阶段失败应隔离并说明对整体产物的影响；核心阶段失败不要静默吞掉。
