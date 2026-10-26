# 性能测试

比较性能时，要先确认使用的是同一种 API、数据模型、输入数据和机器环境。类型编解码、
可修改的 `JsonNode`、只读的 `JsonDocument`、可选后端和流式读写需要分别测量。

## 当前候选状态

`0.2.0` 候选以 STS `1.2.0` 迁移后的同 SDK 源码作基线。生产候选 `5576cdd` 的
Pure 直接计时完成 24 个用例 × 11 轮 A/B，共 528 个正式样本和另外 48 个预检进程；
全部通过 `candidate/baseline <= 1.05`，最大回退约 1.39%，最大单侧 CV 约 4.02%。
旧候选 `0e1753c` 的失败批保留，不改判为通过。

七库第一次调用因缺少语料目录配置在预检退出，正式计时样本为零。首批有效测量的 770 个
单元和汇总重放已通过独立复核，第二批与最终 strict 仍待完成；不能用旧 SDK 的历史七库
结果代替。运行时配置、当前结果和
适用边界见[本轮 Pure 报告](results/2026-10-26-cjdoc-020-pure.md)。本次不发布 yjson，
不声明跨 SDK 或未重测 Native 性能。

发布前至少完成以下检查：

- Pure 基线与候选版本的 11 轮 A/B 测试，交替运行并反转顺序；
- Native 与 Pure 在独立进程中的 11 轮对比；
- yjson、stdx.json、cjfast_json 的同一批次、相同数据的对比；
- DOM、类型编解码和流式读写分别列出结果；
- 校验和、RSS，以及不同配置下的重复测试；
- 完整保留每一轮样本，并将 CV 超过 5% 的行标记为 noisy；该标签本身不阻断普通 Release。

普通 Release 的 Pure 对比使用 `--gate-mode release`，验收完整结果和回退，不把 CV
稳定性作为失败条件，也不要求 candidate 提升。只有 Release notes 明确声明性能优化时，
才使用 `--gate-mode optimization --target-case ...` 额外验证目标提升和稳定性。

具体阈值见[性能方法](methodology.md)。实现设计结论见
[性能设计结论](../performance.md)。

当前证据分开阅读：

- [本轮 Pure A/B](results/2026-10-26-cjdoc-020-pure.md)：同 SDK、实际 O2 的完整 24 项结果、RSS、输入身份和独立复核。
- [0.2.0 候选验证记录](../../release/0.2.0/evidence.md)：首次失败、新候选通过及剩余门禁。

## 历史证据

以下页面记录了旧版本或开发快照的结果，可用来查看历史数据或选择测试基线：

- [历史七库报告](results/2026-09-13-release-seven-library.md)：各批原始结果和 stable/noisy 状态按原身份保留。
- [历史 Pure A/B](results/2026-09-13-linux-release-pure.md)：包含旧 SDK 发布候选与更早的失败记录。
- [三库历史结果](results/2026-09-13-release-three-library.md)：不证明当前候选或 Native 性能。
- [`c844aa9` 维护性候选](../../benchmarks/results/full-seven-library/2026-09-18-maintainability-c844aa9/README.md)：七库完整，Pure 第二批两项超过 `1.05`，不改判为通过。

- [2026-09-05 T9 A/B qualification](results/2026-09-05-t9-ab-qualification.md)
- [2026-09-05 T9 矩阵(diagnostic)](results/2026-09-05-t9-matrix-bb43321.md)
- [2.0.0 性能验收](results/2026-08-27-yjson-2.0.0.md)
- [2026-08-26 Native acceleration](results/2026-08-26-native-acceleration.md)
- [2026-08-25 Linux release baseline](results/2026-08-25-linux-release-three-library.md)

历史页面按各自的源码、SDK 和运行环境保留，不证明当前候选通过。

## 如何读表

- 比值统一为 `yjson median / peer median`；小于 1 表示 yjson 延迟更低；
- 延迟主要采用进程样本的中位数；
- CV 超过阈值的行保留并标为 noisy，不发布精确比例；
- 高 CV 的慢速用例也必须保留；
- 不同日期、运行时、SDK、输入或 API 的数字不能合并；
- 延迟不能用来推导分配量、RSS、内存峰值或吞吐量。

发布时保存原始样本、日志、清单、校验和及环境信息，不再改写。只有结果页标记为通过，
且能对应到已发布提交的结果，才能用于对外说明性能。
