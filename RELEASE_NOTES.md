# Release notes: 0.1.1

`0.1.1` 是 `0.1.x` 版本线的补丁版本，集中修复资源预算、失败恢复和 Native
启动校验，并拆分内部职责。九个发布包继续使用同一版本号。

## 行为修复

- 字节输入的 UTF-8 字符串预算按实际消耗字节计费。长 ASCII 前缀不再导致非 ASCII
  内容误报超限，转义后的 ASCII 后缀也会进入最终长度检查。
- Compact 文档的整数、字符串和数字数组在 `materialize(maxNodes)` 时，于创建每个元素前
  扣减节点预算。预算耗尽继续抛出 `work_limit_exceeded`。
- Native acceleration provider 的 `primitives()` 回调失败后恢复可配置状态并唤醒等待者，
  同时保留原始异常。底层回调抛出异常时会释放临时 raw-array handle。
- 第一方 Native provider 激活时校验实际链接库的 `YJ_JSON_ProbeV1()` 和基础能力位。
  ABI 或 CPU 能力不匹配时明确失败，不会把进程冻结为 Native 状态。

## 维护性变更

- Pure runtime 复用 generated codec 遍历协议，并集中 ASCII 转义和 Compact 数字回滚逻辑。
- JSON Pointer、Patch、Path 和 Schema 的等价语义、编译、format 及 filter 职责分离，
  对外入口保持不变。
- Native writer 原语与统计 ABI 槽位按职责整理。外部使用方门禁改为直接执行已构建二进制，
  runtime-freeze 门禁在首次编译失败时终止。
- 性能与证据工具加强候选身份、工作量、归档来源和退出状态校验。Pure 回退资格使用
  固定工作量的进程内直接测量；不同测量协议的样本不得拼接。

## 兼容性

- 已检入的 Cangjie public API 和 C ABI 快照相对 `0.1.0` 没有变化。
- generated-support v1 协议没有版本变更，九个包仍按 lockstep 方式配对。
- 快照不等同于二进制兼容证明。冻结的旧 consumer 链接和调用矩阵完成并写入
  [发布候选记录](release/0.1.1/evidence.md)前，本版本不声明二进制兼容。

## 验证与发布状态

固定发布工具链为 Cangjie STS `1.1.3`。候选提交、托管 CI、平台矩阵、产物摘要、
标签和 GitHub Release 状态以[发布候选记录](release/0.1.1/evidence.md)为准。

本版本不发布新的性能优化倍数，也不声明真实 Native provider 的加速效果。性能回退资格和
Deep Nested decode 保护需要使用独立、干净候选完成 A/B 测量；未执行的项目在候选记录中标为
`NOT RUN`。

## 历史版本

`0.1.0` 的发布证据保持在 [`release/0.1.0/evidence.md`](release/0.1.0/evidence.md)。
更早的 `1.x`、`2.0` tag、Release、性能报告和 evidence 是历史原型，不定义
`0.1.x` 的兼容性。

