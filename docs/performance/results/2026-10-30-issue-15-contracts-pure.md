# 2026-10-30 Issue #15 修复候选 Pure 测量：通过

生产源码 `0d4d39a3e92ccaf4d3d0a37367160973dad21dbd`、宏 `2bfd34c08c421c04a0cd8e3d1326140849f1f21b`
通过同 SDK 的完整 Pure 回退门禁。24 项各执行 11 轮 baseline/candidate，
共 528 个正式计时进程及 48 个预检进程；所有 C/B 均不超过原有 `1.05` 门槛。
最高比率为 `1.043291`，最大单侧 CV 为 `2.275%`。
这是正确性修复的回退资格，不是加速或零开销声明。

完整记录见[证据索引](../../../benchmarks/results/full-seven-library/2026-10-30-issue-15-contracts/README.md)，
跨库结果见[七库报告](2026-10-30-issue-15-contracts-seven-library.md)，修复范围见
[Issue #15 实施记录](../../implementation/issue-15.md)。本页不表示候选已经发布。

## 测量条件

- SSH 服务器 Linux x86_64，Cangjie STS `1.2.0` 与匹配 stdx；显式 `-O2`，保留 CHIR 函数内联。
- `YJSON_PURE_DIRECT_V1`，`--gate-mode release --rounds 11 --rebuild --enforce`；未改变固定工作量、阈值或预热协议。
- `cjHeapSize=128MB`、`cjProcessorNum=1`。完整矩阵业务 CPU 3、GC main/helper CPU 5、GC pool/schmon CPU 6；
  单独 HEAD 对照使用 CPU 1/3/4。每批先取 30 秒空闲窗口，所有所选核心及其 SMT 线程均低于 1%。
- 基线仍为 STS 迁移后、旧包装清理前的运行时；本次只统一测量 harness 和本地 path 依赖 overlay。
  修复前 HEAD、发布基线和候选不是同一源码，不能混为一个对照。
- 四个归档快照各有 200 个测量输入文件。生产仓库保留真实宏 Git pin；本地宏依赖只用于隔离的 Pure 快照。
- 两侧先清理并重新构建，再交替执行。逐进程核验调用数、直接计时、预热、测试成功、绑核和 RSS sidecar；没有正式计时重试。

## 完整结果

延迟为 11 轮中位数，单位 µs/op；CV 使用样本标准差。C/B 大于 1 表示候选更慢。
RSS 原始数据完整保留，但本轮没有额外 RSS 门槛。Person 编码和 ProfileBundle bytes 编码仍有
约 4% 的代价，均在既有回退预算内，不能描述为所有路径都更快。

| 用例 | 基线 µs/op | 候选 µs/op | C/B | 候选胜轮 | 基线 CV | 候选 CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `yjsonStringEncodeLargeInt64Map` | 6.554873 | 6.613115 | 1.008885 | 0/11 | 0.331% | 0.621% |
| `yjsonStringDecodeLargeInt64Map` | 14.634876 | 14.281791 | 0.975874 | 11/11 | 0.545% | 0.373% |
| `yjsonBytesDecodeLargeInt64Map` | 17.344494 | 17.824137 | 1.027654 | 0/11 | 0.263% | 0.740% |
| `yjsonStringEncodeDeepNestedProfiles` | 23.642318 | 23.743549 | 1.004282 | 2/11 | 0.812% | 0.332% |
| `yjsonStringDecodeDeepNestedProfiles` | 113.202456 | 111.912569 | 0.988605 | 10/11 | 1.434% | 0.422% |
| `yjsonBytesDecodeDeepNestedProfiles` | 118.046493 | 116.992505 | 0.991071 | 8/11 | 0.824% | 0.574% |
| `yjsonStringEncodePerson` | 1.120069 | 1.168558 | 1.043291 | 0/11 | 1.146% | 1.415% |
| `yjsonStringDecodePerson` | 3.557926 | 3.658434 | 1.028249 | 2/11 | 0.904% | 2.275% |
| `yjsonStringEncodeLargeProfileArray` | 20.582577 | 20.892450 | 1.015055 | 2/11 | 1.374% | 1.770% |
| `yjsonStringDecodeLargeProfileArray` | 42.889280 | 40.133403 | 0.935744 | 11/11 | 0.375% | 0.585% |
| `parseStringRecords64k` | 1298.679274 | 1289.160687 | 0.992671 | 7/11 | 1.171% | 1.258% |
| `parseBytesRecords64k` | 1396.807696 | 1393.296497 | 0.997486 | 6/11 | 2.164% | 2.088% |
| `parseStringRecords1m` | 26275.940745 | 25867.834850 | 0.984468 | 10/11 | 0.584% | 1.049% |
| `parseBytesRecords1m` | 26918.458985 | 27336.118325 | 1.015516 | 3/11 | 0.818% | 1.384% |
| `yjsonStringEncodeProfileBundle` | 3.705792 | 3.688703 | 0.995389 | 7/11 | 0.515% | 0.782% |
| `yjsonStringDecodeProfileBundle` | 6.199489 | 6.182736 | 0.997298 | 5/11 | 1.943% | 2.106% |
| `yjsonBytesEncodeProfileBundle` | 4.082963 | 4.252927 | 1.041628 | 1/11 | 1.880% | 0.640% |
| `yjsonBytesDecodeProfileBundle` | 7.062751 | 6.837841 | 0.968156 | 11/11 | 0.699% | 0.522% |
| `yjsonStringEncodeEscapedUnicodeString` | 0.780570 | 0.808695 | 1.036032 | 0/11 | 0.872% | 1.323% |
| `yjsonBytesEncodeEscapedUnicodeString` | 0.641923 | 0.648326 | 1.009976 | 2/11 | 1.774% | 0.787% |
| `decodePersonChunk4k` | 23.815489 | 23.917304 | 1.004275 | 4/11 | 0.737% | 0.759% |
| `decodeRecords64kChunk4k` | 6007.041883 | 6085.550414 | 1.013069 | 1/11 | 0.646% | 0.571% |
| `encodePersonMemory` | 6.846920 | 6.851692 | 1.000697 | 4/11 | 1.925% | 1.029% |
| `encodeRecords64kMemory` | 556.138813 | 554.013289 | 0.996178 | 6/11 | 1.100% | 1.007% |

## 修复前 HEAD 的 Deep Nested 对照

此项额外检查冻结的修复前 HEAD `c474263c72615f30b030bf9e8cf86b4573fbef12`，
不替代上面的 24 项发布基线矩阵。两项各完成 11 轮、共 44 个计时进程；比率接近 1，
未触及既有回退门槛，不作加速声明。

| 用例 | 修复前 HEAD µs/op | 候选 µs/op | C/B | 候选胜轮 | 修复前 HEAD CV | 候选 CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `yjsonStringDecodeDeepNestedProfiles` | 112.888320 | 112.903267 | 1.000132 | 6/11 | 0.525% | 1.287% |
| `yjsonBytesDecodeDeepNestedProfiles` | 117.874397 | 117.860774 | 0.999884 | 5/11 | 0.588% | 0.379% |

## 输入身份

| 输入 | 身份 |
| --- | --- |
| 生产产品源码 SHA-256 | `e53700605a8d479abd69b504a138278dc0f9e7be1df6bcd5a8332d0e6e7e5368` |
| 生产 harness SHA-256 | `3f1c2c1de5ae803f99e344a9a283057674ff2de72154cb66389b5b6d833dc8c5` |
| Pure 发布基线快照 | `02047192356c310af93fcaad54fc22c5a3c95001` |
| Pure 修复前 HEAD 快照 | `e254f79f0de98f1a36736cb9bcfab581412342fd` |
| Pure 最终候选快照 | `ff86080a044c3379a8ced866e0f07b92f98e59b1` |
| 所有快照共同的 Pure harness SHA-256 | `31b09e332b6533333bc55ec12c140e3bf209930d6cd4a3bf21541f2c08fecf5a` |
| 语料 SHA-256 | `db9b0242e01fb4cfa2468245f8be5329a0967052412b7340f12c468c6202a70f` |
| 发布基线可执行文件 SHA-256 | `ed57999b7d53e75e20ca22159dd7eec27b8b7c4c00009be398b5dc8795bd721d` |
| 最终候选可执行文件 SHA-256 | `ed46bc1c93b3a902974259546963d77c88a04e7bb5fe34479f609fc989efa701` |

归档保存实际命令、提交与 tree、前后产品清单、工具链摘要、产物摘要和退出码。
源码包不含 Git 历史或可执行文件；额外保留第一方 Apache-2.0 许可及 yyjson 自带许可。

## 首次失败保留

初次修复源码 `3a677a6fa5eafd339566c98a8e68a10323aca361` 的完整 24 项运行退出 1：
Person 编码约为基线的 1.953 倍，ProfileBundle 编码约 1.50 倍，多项超过回退门槛。
该批原始样本和源码快照按失败状态保留，没有删行、改阈值或回写为通过。

之后改为具体类型字段状态、只缓存已证明稳定的肯定 compact 能力，以及按输入字节数证明默认预算安全的短路径。
动态能力和较大输入继续执行原有检查；功能回归通过后，重新冻结源码并执行本页完整矩阵。
六组独立三轮诊断不计为正式资格，未采用的 writer/cursor 实验不进入候选。

本结果不证明 Native provider、默认并发配置、其他平台或另一 SDK；
也不与七库 SDKBench/JMH 样本合并。方法见[性能方法](../methodology.md)。
