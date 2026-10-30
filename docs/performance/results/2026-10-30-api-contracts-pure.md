# 2026-10-30 API 注释候选 Pure 测量：通过

生产源码 `ac4f8b987910a473ada7d77f10ce6cd3c12d2248` 通过同 SDK 的 Pure 回退门禁。
24 项各执行 11 轮 baseline/candidate，共 528 个正式计时进程和另外 48 个预检进程。
所有候选/基线中位数比率不超过 `1.05`；最大为 `1.017936`，最大单侧 CV 为 `3.207%`。
这不是性能优化声明。

完整原始记录与输入见[证据索引](../../../benchmarks/results/full-seven-library/2026-10-30-api-contracts/README.md)，
两批对比见[七库报告](2026-10-30-api-contracts-seven-library.md)。测量发生于 2026-10-29 UTC；本页不表示 yjson 已发布。

## 测量条件

- Linux x86_64、STS `1.2.0`、匹配 stdx；两侧实际使用显式 `-O2`，CHIR 函数内联保持启用。
- `YJSON_PURE_DIRECT_V1`，`--gate-mode release --rounds 11 --rebuild --enforce`，阈值及工作量不变。
- `cjProcessorNum=1`、`cjHeapSize=128MB`；业务 CPU 1、GC main/helper CPU 5、GC pool/schmon CPU 6。
- 两侧使用相同宏 D819 和 path 依赖 overlay；生产候选保留真实 Git pin。
- 基线保留 STS 迁移后、旧包装清理前的运行时；只同步测量 harness 与宏依赖。
- 每个进程核验有效计时声明、调用数、预热、所选测试成功状态、绑核与 RSS sidecar；没有计时重试。

## 完整结果

延迟为 11 个样本的中位数，单位 µs/op；CV 使用样本标准差。正的变动表示候选更慢。
RSS 是每侧原始 GNU time sidecar 的最大 kbytes，本协议没有 RSS 门槛。

| 用例 | 基线 µs/op | 候选 µs/op | C/B | 变动 | 候选胜轮 | 基线 CV | 候选 CV | 基线最大 RSS KB | 候选最大 RSS KB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `yjsonStringEncodeLargeInt64Map` | 6.568804 | 6.544041 | 0.996230 | -0.376977% | 10/11 | 0.389% | 0.386% | 170104 | 170112 |
| `yjsonStringDecodeLargeInt64Map` | 14.100683 | 14.128258 | 1.001956 | +0.195559% | 3/11 | 0.323% | 0.579% | 165660 | 165980 |
| `yjsonBytesDecodeLargeInt64Map` | 16.854880 | 16.698170 | 0.990702 | -0.929757% | 10/11 | 0.390% | 0.500% | 169936 | 170288 |
| `yjsonStringEncodeDeepNestedProfiles` | 23.894632 | 23.686776 | 0.991301 | -0.869886% | 8/11 | 0.497% | 0.694% | 127332 | 127712 |
| `yjsonStringDecodeDeepNestedProfiles` | 112.378705 | 112.307347 | 0.999365 | -0.063498% | 4/11 | 1.532% | 1.114% | 169812 | 169876 |
| `yjsonBytesDecodeDeepNestedProfiles` | 117.382040 | 117.305063 | 0.999344 | -0.065577% | 5/11 | 0.479% | 0.592% | 169880 | 169736 |
| `yjsonStringEncodePerson` | 1.109232 | 1.129127 | 1.017936 | +1.793623% | 5/11 | 1.554% | 0.914% | 117540 | 117264 |
| `yjsonStringDecodePerson` | 3.545942 | 3.553181 | 1.002041 | +0.204141% | 5/11 | 1.236% | 1.467% | 170124 | 169968 |
| `yjsonStringEncodeLargeProfileArray` | 20.472163 | 20.643394 | 1.008364 | +0.836411% | 0/11 | 0.221% | 0.815% | 146708 | 145192 |
| `yjsonStringDecodeLargeProfileArray` | 41.151218 | 41.631965 | 1.011682 | +1.168246% | 0/11 | 0.377% | 0.348% | 117296 | 117268 |
| `parseStringRecords64k` | 1289.770251 | 1280.743771 | 0.993001 | -0.699852% | 5/11 | 1.578% | 1.003% | 170244 | 170304 |
| `parseBytesRecords64k` | 1386.561878 | 1395.206110 | 1.006234 | +0.623429% | 4/11 | 1.636% | 2.164% | 170036 | 170304 |
| `parseStringRecords1m` | 26019.624060 | 25833.872375 | 0.992861 | -0.713891% | 7/11 | 0.997% | 0.642% | 168976 | 168260 |
| `parseBytesRecords1m` | 27096.763070 | 27042.639975 | 0.998003 | -0.199740% | 8/11 | 1.216% | 0.944% | 168592 | 168748 |
| `yjsonStringEncodeProfileBundle` | 3.754378 | 3.721488 | 0.991239 | -0.876051% | 9/11 | 1.248% | 0.427% | 117696 | 117588 |
| `yjsonStringDecodeProfileBundle` | 6.150689 | 6.198145 | 1.007716 | +0.771566% | 5/11 | 3.207% | 1.904% | 169860 | 170112 |
| `yjsonBytesEncodeProfileBundle` | 4.156298 | 4.137645 | 0.995512 | -0.448794% | 8/11 | 0.490% | 0.630% | 137868 | 139388 |
| `yjsonBytesDecodeProfileBundle` | 7.039551 | 6.904124 | 0.980762 | -1.923793% | 10/11 | 1.324% | 1.199% | 156960 | 160860 |
| `yjsonStringEncodeEscapedUnicodeString` | 0.772517 | 0.778364 | 1.007569 | +0.756928% | 5/11 | 1.332% | 0.556% | 170348 | 170372 |
| `yjsonBytesEncodeEscapedUnicodeString` | 0.628283 | 0.638174 | 1.015743 | +1.574263% | 4/11 | 1.531% | 1.650% | 170220 | 170212 |
| `decodePersonChunk4k` | 23.818281 | 23.933287 | 1.004828 | +0.482846% | 4/11 | 0.898% | 0.684% | 146448 | 146856 |
| `decodeRecords64kChunk4k` | 6092.197197 | 6112.646150 | 1.003357 | +0.335658% | 4/11 | 0.629% | 0.596% | 117116 | 117372 |
| `encodePersonMemory` | 6.841171 | 6.865271 | 1.003523 | +0.352282% | 4/11 | 1.732% | 1.487% | 169816 | 169872 |
| `encodeRecords64kMemory` | 566.700637 | 557.119382 | 0.983093 | -1.690708% | 8/11 | 1.488% | 0.949% | 168528 | 169044 |

## 输入身份

| 输入 | 身份 |
| --- | --- |
| 生产产品源码 SHA-256 | `4251be5ff98c50a91afdd162ae130d94f8bf2a70c85faf5da6a78304232771af` |
| 生产 harness SHA-256 | `9d457f09101cb4466a82b000d2494e9c12b2f495b5b16b4fef809811a60d8852` |
| Pure 基线快照 | `d5cf460a6c5cdfb25a07bd45e97bd04d7336ea87` |
| Pure 候选快照 | `641bc25d5a15062282feea45b9adba2185c9f434` |
| 两侧相同 Pure harness SHA-256 | `dc28db7743c93f1550bad1f31e15455bc213c486a54c131e6b0f9a8cd16de9a6` |
| 宏提交 | `d819745310f8cc6aa416e1298f706ea5138b7d16` |
| 语料 SHA-256 | `db9b0242e01fb4cfa2468245f8be5329a0967052412b7340f12c468c6202a70f` |
| 基线可执行文件 SHA-256 | `a2ef68c47f49dc60d5283e2f7feae2f8b6941bb728b2ff8987f3b3fa1ccccc1c` |
| 候选可执行文件 SHA-256 | `375b881d725e0ee5b81e7b0b2e602f24b736a5a8659829566dcb86325671ba3b` |
| 原始任务归档 SHA-256 | `36ab90c69f96157bef5743916ff9b020029550d5f2c30639d140877000f8a2ec` |

原始归档 2887 个文件逐成员校验，两个源码快照各 200 个测量前登记文件逐项匹配；公开
源码包仅移除 Git 存储，不修改源码。此前候选的失败与结果保留在[上一轮报告](2026-10-26-cjdoc-020-pure.md)。
本轮不证明默认运行时、Native provider、其他平台或另一 SDK。方法见[性能方法](../methodology.md)。

独立离线复核见[复核记录](../../../benchmarks/results/full-seven-library/2026-10-30-api-contracts/independent-validation.md)。
