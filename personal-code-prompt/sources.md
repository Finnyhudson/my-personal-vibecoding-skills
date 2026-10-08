# 来源与继承边界

本文件说明这套约定的来源，以及哪些是继承改写、哪些只是一个项目的样例。

1. 本地原 skill `prompt-engineering`（SKILL.md、prompt-template.md）：本 skill 继承其核心原则并改写为个人自包含版本，属于原则与选择的继承，不是原样复制；原 skill 仍可独立使用，两者不互相依赖。
2. 晨报项目：仅作为业务分层与流程样例来源，并非已完全规范化，不作为规范依据。
3. Google Python Style Guide §3.18：小而聚焦的函数、无硬上限、约 40 行时自问是否该拆分；本 skill 的 20–80 行属个人偏好。https://google.github.io/styleguide/pyguide.html
4. PEP 20：可读、简单、显式。https://peps.python.org/pep-0020/
5. OpenAI structured outputs 与 openai-python helpers：受支持的 SDK 可直接发送并解析 schema，单一定义源是推荐做法、并不强制 Pydantic。https://platform.openai.com/docs/guides/structured-outputs ；https://github.com/openai/openai-python/blob/main/helpers.md
6. OpenAI 评估最佳实践与 Anthropic 测试开发文档支持以基线逐次迭代；Anthropic prompt engineering 最佳实践支持"一个 prompt 做好一件事"；具体采用小范围真实回放属个人选择。https://platform.openai.com/docs/guides/evaluation-best-practices ；https://docs.claude.com/en/docs/test-and-evaluate/develop-tests ；https://claude.com/blog/best-practices-for-prompt-engineering
