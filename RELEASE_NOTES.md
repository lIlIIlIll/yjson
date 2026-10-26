# Release notes: 0.2.0 候选

`0.2.0` 正在准备九包候选，产品、宏、示例、文档与 CI 统一使用 Cangjie STS `1.2.0`
及匹配的 stdx。本轮交付候选与文档站点，不创建 yjson tag，也不发布九个包。
实际源码身份、测试、性能、PR、cjdoc 发布和 Pages 部署状态见
[候选实施记录](docs/implementation/cjdoc-020.md)。未执行或未通过的项目不构成发布资格。

## 升级与兼容政策

整个 `0.x` 阶段不保证 patch 或 minor 之间的源码、API、ABI、生成代码或旧 SDK 兼容。
升级时同步所用的第一方包，重新展开宏并在 STS `1.2.0` 下编译消费方。
不要只替换动态库或复用旧生成产物。破坏性变更仍须逐项说明并取得用户确认。

本候选已确认删除 `@JsonValue` 宏，原调用 `@JsonValue(...)` 改成 `@Json(...)`，不保留别名。
`@JsonAlias` 字段读取别名继续可用。当前 generated-support v1、ABI 错配检查、能力分派、
预算、错误与资源生命周期仍按当前候选契约验证；V1 名称不表示跨版本可混用。

旧消费方二进制的跨版本链接矩阵不再是未来候选的发布要求。下方 `0.1.1` 的有限 PASS
与历史产物保持原样，只适用于记录的 SDK、平台和文件，不外推到当前候选。

## 示例验证发现的行为修复

- `@JsonCodec` 无参 struct 的可变字段解码不再生成字段赋值编译错误。
- JSON Pointer URI fragment 正确使用两位大写十六进制编码空白、控制字符和 UTF-8 字节。
- Custom Native 及 yyjson 的 Custom Native 回退路径在 backend metadata 中报告候选包版本 `0.2.0`。

## 文档与性能候选

文档候选要求九包共用搜索、指南导航与交叉链接，补齐八个应用包的中文契约和逐入口
可执行示例，并交付 HTML、Markdown、Doc IR v16、质量报告和完整 Agent 离线包。
统一站点入口为根目录 `index.html`；不为旧 URL、旧 Doc IR 或旧目录布局建立兼容层。
工具目标 cjdoc `0.7.5` 尚未完成上游发布与资格冻结，不能将文档目标写成已验收结果。

Pure 基线为 STS `1.2.0` 迁移后、旧包装清理前的源码，基线与候选使用同一 SDK 和测量程序。
候选要求重新执行 24 个 Pure 用例各 11 轮及七库两批各 770 个单元，并通过严格证据检查。
旧 SDK 的历史结果不证明本候选性能通过，也不用于跨 SDK 性能声明。

## 回退

需要回退时，恢复经过验证的主仓和宏仓配对提交，按对应 SDK 重新生成并编译应用。
站点通过回退 PR 和重新部署保存的产物恢复；这种运维回退不提供跨版本混用保证。
Pages 仍只在精确 `main` 提交的全部必需门禁通过后部署。

## 0.1.1 历史发布说明

`0.1.1` 是 `0.1.x` 版本线的补丁版本，集中修复资源预算、失败恢复和 Native
启动校验，并拆分内部职责。九个发布包继续使用同一版本号。

### 行为修复

- 字节输入的 UTF-8 字符串预算按实际消耗字节计费。长 ASCII 前缀不再导致非 ASCII
  内容误报超限，转义后的 ASCII 后缀也会进入最终长度检查。
- Compact 文档的整数、字符串和数字数组在 `materialize(maxNodes)` 时，于创建每个元素前
  扣减节点预算。预算耗尽继续抛出 `work_limit_exceeded`。
- Native acceleration provider 的 `primitives()` 回调失败后恢复可配置状态并唤醒等待者，
  同时保留原始异常。底层回调抛出异常时会释放临时 raw-array handle。
- 第一方 Native provider 激活时校验实际链接库的 `YJ_JSON_ProbeV1()` 和基础能力位。
  ABI 或 CPU 能力不匹配时明确失败，不会把进程冻结为 Native 状态。

### 维护性变更

- Pure runtime 复用 generated codec 遍历协议，并集中 ASCII 转义和 Compact 数字回滚逻辑。
- JSON Pointer、Patch、Path 和 Schema 的等价语义、编译、format 及 filter 职责分离，
  对外入口保持不变。
- Native writer 原语与统计 ABI 槽位按职责整理。外部使用方门禁改为直接执行已构建二进制，
  runtime-freeze 门禁在首次编译失败时终止。
- 性能与证据工具加强候选身份、工作量、归档来源和退出状态校验。Pure 回退资格使用
  固定工作量的进程内直接测量；不同测量协议的样本不得拼接。

### 兼容性

- Cangjie public API 和 C ABI 声明快照与实际发布的 `0.1.0` 源码提交一致。
- generated-support v1 协议没有版本变更；升级时将所用的 yjson 包及宏包同步到 `0.1.1`。
- 固定 STS `1.1.3`、Linux x86_64 下，冻结的 `0.1.0` 消费者通过新库重链接与调用，
  三个动态包通过原应用替换 `.so` 运行。28 个冻结文件的摘要保持不变；该结论不外推到
  其他平台、SDK 或任意第三方程序。矩阵与源码见[兼容性证据](release/0.1.1/binary-compatibility.json)。
- Custom Native 及 yyjson 的 Custom Native fallback 元数据版本更新为 `0.1.1`；
  yyjson 引擎版本仍为 `0.12.0`。

### 验证与发布状态

固定发布工具链为 Cangjie STS `1.1.3`。候选提交、托管 CI、平台矩阵、产物摘要、
标签和 GitHub Release 状态以[发布候选记录](release/0.1.1/evidence.md)为准。

本版本不发布新的性能优化倍数，也不声明真实 Native provider 的加速效果。性能回退资格和
Deep Nested decode 保护需要使用独立、干净候选完成 A/B 测量；未执行的项目在候选记录中标为
`NOT RUN`。

### 历史版本

`0.1.0` 的发布证据保持在 [`release/0.1.0/evidence.md`](release/0.1.0/evidence.md)。
更早的 `1.x`、`2.0` tag、Release、性能报告和 evidence 是历史原型，不定义
`0.1.x` 的兼容性。
