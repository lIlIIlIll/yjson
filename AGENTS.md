# AGENTS.md

## 项目边界与来源

- 开始改动前阅读 `README.md`、`CONTRIBUTING.md`、`docs/architecture.md`、`docs/maintainers/testing.md` 和当前任务。以当前公开声明、测试和实际仓颉 SDK 为准，不套用历史 1.x/2.x API。
- `yjson` 的纯仓颉运行时、`JsonNode` 可变树、`JsonDocument` 只读视图、`JsonValueView` 算法与可选 Native 后端各有独立语义。跨后端的选项、错误和限制须保持契约一致。
- `yjson_macros` 是独立模块/仓库。宏展开代码与运行时 `generated-support v1` 契约必须配套验证，不应在单一仓库擅自修改或假设另一仓库已发布变更。
- 严格维持 JSON 数值精度、UTF-8/转义、输入/输出预算、嵌套限制、流所有权和诊断；不得以放宽限制、缩短测试或修改 golden/快照迎合实现。

## 实现与验证

- 保持代码改动聚焦；公开 API 变更同步接口清单和真实消费方测试。性能结论遵循 `docs/performance/methodology.md`，不能用速度代替正确性。
- 按 `docs/maintainers/testing.md` 运行受影响模块的测试；修改运行时或 codec 时运行 `cjpm test --no-color` 并补外部消费方测试。只修改文档/清单时至少执行 `python3 scripts/check_api_inventory.py`、`python3 scripts/test_stage_source_tree.py`、`python3 scripts/test_release_temp_tree.py`。
- 区分真实运行的编译、测试、标准语料、Native、性能、远端 CI 与发布证据；无法执行时说明阻碍，不能把未执行的验证当作通过。

## Code Review 专项不变量

- 检查 DOM 可变树与只读 Document 的行为差别，及 JSON Schema / Pointer / Path / Patch 对共享 `JsonValueView` 的使用是否在成功、失败、缺失与边界输入上保持一致。
- 对 codec 和宏生成代码，覆盖缺失/空值、nullable/optional、默认值、数值溢出/精度、转义/Unicode、多态、重复键及调用方可见的稳定错误，而非只验证一个示例。
- 对流式读写检查跨块分割、部分 UTF-8、取消、EOF、调用方流的关闭责任、累计预算、错误定位；对 Native 路径同时检查纯仓颉回退及资源释放。

## Code Review Rules

- 每条阻塞性意见应给出可触发输入/执行序列、违反的具体契约、影响及相关代码；不要把纯风格、未经验证的假设或已有问题的无关优化升级为阻塞缺陷。
- 对同一根因，在**一次审查**中检查相邻的正反、缺失/空值、边界、回退和对称路径；合并同一不变量的反例，而非分多轮逐个提出。只检查受影响的调用链，不穷举无关情况。
- 对照输入生产者、解码/校验者和最终使用方；确认修复同时保留合法输入与失败语义。可访问 Review Thread 时先去重，后来发现的真实回归仍必须指出。
- 后续提交重点复核当前修复、相关不变量与引入的回归；区分当前 PR 引入/加重的问题、历史缺陷和可独立跟进的建议。不得仅因审查次数多就跳过真实阻塞问题。

## Review 反馈处理与收敛

- 先验证每条 Review 意见并按根因归类；同组边界情况集中修复并补回归/参数化测试。避免“修一条、Push 一次”的循环。
- 聚合一轮实现与受影响测试后再推送；记录已修复、证据反驳、仍阻塞及范围外跟进的具体原因。
- 合并前核对最新 HEAD 上实际完成的复审与 CI；旧 SHA 的 Review、评论数归零或本地构建通过不能替代最新提交的证据。自动复审是否触发由 Codex 设置管理，`AGENTS.md` 本身不会触发 Review。
- 当前 PR 的真实阻塞缺陷与 Issue 验收必须满足；非阻塞独立改进可单开 Issue。不能用固定轮数或“全部 Thread 清零”作为唯一条件，也不应自动合并。
