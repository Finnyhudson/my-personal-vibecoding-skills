---
name: agent-setup
description: 在新机器或新版本的 OpenCode 上，按用户的多 agent 设计原则完成配置；也用于用户修改 agent 配置后同步本仓库。触发词：配置 agent、迁移配置、新机器配置、同步 agent 配置、agent-setup。
---

# agent-setup

本技能根据同目录下的 `PRINCIPLES.md` 配置 OpenCode 和 oh-my-opencode-slim。`PRINCIPLES.md` 是唯一依据；同目录下的 `snapshot/` 只是它在旧版本上的一种写法，供参考。

文件位置：
- 本技能目录：`PRINCIPLES.md`、`snapshot/opencode-v2/`（配置快照，密钥已换成占位符）、`snapshot/machine-specific/`（本机启动脚本，仅供参考）。
- `personal-code-prompt` 技能不在快照里，它是 skills 仓库 `my-personal-vibecoding-skills` 中与本技能并列的另一个技能，要一起安装。
- 运行目录里的本技能只是副本。修改原则或快照时，改的是 skills 仓库里的源文件，再用仓库根目录的 `sync.ps1` 同步。

## 何时用

- 在新机器或新版本的 OpenCode 上建立这套配置。
- 对比现有配置和原则的差异，并补齐缺少的部分。
- 用户改完 agent 配置后，把改动同步回本仓库。

## 配置步骤

1. **先了解本机情况**，只读不改：
   - OpenCode 的版本，以及实际生效的配置目录。注意环境变量 `OPENCODE_CONFIG_DIR` 和 XDG 目录。
   - 是否装了 oh-my-opencode-slim，版本是多少，当前用的是哪个 preset。
   - 有哪些 provider 和模型可以用，用 models 工具或 `/models` 查。
   - 本机已有的自定义设置。
2. **读 `PRINCIPLES.md`**，再看 `snapshot/` 里对应的文件。
3. **判断怎么落地**：
   - 版本和格式都和快照一致：以快照为基础，套用到本机。
   - 版本或格式不同：按原则改写成新格式，不要硬套旧字段。新格式的写法先查官方文档确认。
   - 模型不可用：列出缺少哪些模型，问用户换成什么，不要自己替换。
4. **本机已有修改时，先列出冲突再问用户**，不要直接覆盖。和原则没有冲突的部分，做最小修改。
5. **密钥**：快照里的密钥是 `{env:变量名}` 这样的占位符，要提醒用户设置对应的环境变量，或者填上自己的密钥。不要输出、提交或复制任何真实密钥。
6. **本机路径**：`snapshot/machine-specific/` 里的启动脚本只能参考，路径要按本机情况调整。
7. **检查**：只做静态检查，包括配置能否解析、模型和变体是否对应正确、每个自定义 agent 是否都有同名的提示词文件、写代码的 agent 的技能白名单里是否有 `personal-code-prompt`。不要自动调用付费模型，也不要重启正在运行的服务。
8. **汇报**：说明改了什么、保留了本机哪些差异、哪些需要用户确认，以及怎么重启生效。重启后，可以派一个很小的任务，确认带模型名的 agent 拿到了完整的提示词。
9. **压缩**：原生压缩是否可用取决于代理和上游，换了环境就要在用户同意后重新实测，不能直接沿用 `PRINCIPLES.md` 里的结论。

## 同步回仓库

用户改了 agent 配置或原则后：

1. 在 skills 仓库（`my-personal-vibecoding-skills`）的 `agent-setup/` 下，把改动写进 `PRINCIPLES.md`，只改受影响的段落，并更新「最后更新」的日期。
2. 把改过的配置文件复制到 `agent-setup/snapshot/`，复制前先去掉密钥，并确认快照里没有残留真实密钥。
3. 用 `git diff` 给用户看改了什么，经用户同意后再提交和推送。
4. 需要时用 `sync.ps1 -Direction Push -Skill agent-setup -Target <运行目录的 skills 文件夹>` 更新运行副本，重启后生效。
