# 2026-11-03 Issue #9 Pure 性能资格

生产测量提交为 `aa128768beaaa4383586ae306ab0c0d2f74ce172`，SDK 为 STS `1.2.0`。
完整 24 项发布对照与额外两项 Deep Nested 对照均通过原有 C/B≤1.05 门槛。
发布对照最大比率为 1.039888，最大单侧 CV 为 3.561%；没有触发噪声第二批条件。
这些结果不表示每项都变快，也不代替 correctness、最终 strict freshness 或发布资格。

[证据索引与可信重放命令](../../../benchmarks/results/full-seven-library/2026-11-03-issue-9-contracts/README.md)；[七库报告](2026-11-03-issue-9-contracts-seven-library.md)。

## 冻结输入

| 输入 | 身份 |
| --- | --- |
| 生产产品 SHA-256 | `a0ca74e163e77bf33a0c48267b2b0dc0f51e81b85178dc7a6eba1a20c0bd34c6` |
| 生产 harness SHA-256 | `0f16fde97703cf34328a37cbbdfa37ceb6d20d636e0a48f3ea8a2de2beefad8e` |
| Pure 共同 path/lock harness SHA-256 | `00c589d1558de5b88ffa139328faf943f25ae1fb48b41f494d80b1e779fe87ba` |
| 生产宏提交 | `2bfd34c08c421c04a0cd8e3d1326140849f1f21b` |
| SDK/STDX 清单 SHA-256 | `ea7984dc5c37c02acf7f7119c24d7633a3b655f0c71350a8aa910c87abe00b5a` |
| 三份语料清单 SHA-256 | `db9b0242e01fb4cfa2468245f8be5329a0967052412b7340f12c468c6202a70f` |

| 角色 | 运行时来源提交 | 实际测量快照提交 | 宏提交 |
| --- | --- | --- | --- |
| 发布基线 | `02047192356c310af93fcaad54fc22c5a3c95001` | `247fc8d4137ab75c11769b6654a849a9eaa0586f` | `d819745310f8cc6aa416e1298f706ea5138b7d16` |
| 本轮修复前 HEAD（BASE） | `ae44984c729ac5149fef051ab828fb11fa5a89a9` | `4adecf8cab5d9e55b4cefaef1758fb1c1978571e` | `2bfd34c08c421c04a0cd8e3d1326140849f1f21b` |
| C3 | `aa128768beaaa4383586ae306ab0c0d2f74ce172` | `8ddb5adf9616f8b159ca8825a733d626d1b537b3` | `2bfd34c08c421c04a0cd8e3d1326140849f1f21b` |

快照提交不等于生产提交。三侧实际 commit/tree、产品和 harness 完整清单、所有宏构建源码及
原始宏仓完整源码/许可证，均保存在 `pure-issue9-source-inputs.tar.gz`。
生产候选保留真实 Git pin；只有隔离测量快照使用相同形状的 path/lock overlay。
旧基线保留其原宏配对，不伪称三侧宏源码相同。首次错误配给当前宏的基线构建失败日志保留在诊断包，
恢复原配对后才开始正式测量；没有给基线运行时添加接口。

## 协议与验收

| 对照 | 用例 | 每侧独立进程轮数 | 计时单元 | 预检单元 | 比率门槛 |
| --- | ---: | ---: | ---: | ---: | --- |
| 发布基线 → C3 | 24 | 11 | 528 | 48 | 每项 C/B≤1.05 |
| BASE → C3 Deep Nested | 2 | 11 | 44 | 4 | 每项 C/B≤1.05 |

固定工作量、预热与线程角色绑核沿用冻结 runner；仓颉进程配置为 `cjProcessorNum=1`、
`cjHeapSize=128MB`。实际 clean rebuild 的 cjc/cjc-frontend argv 明确使用 `-O2`，
测量程序未禁用 CHIR 函数内联。strace 只审计构建，不包住计时进程。
发布对照使用 `--gate-mode release --rebuild --enforce`；两项 HEAD 对照不传 `--enforce`，
另行核验 gates、前后源码/宏/SDK 身份及全部原始单元。普通 Release 不要求候选提升。

CV 用样本标准差/均值计算；表中延迟是 11 个进程样本的中位数。
RSS 为各进程 GNU time 记录的峰值，不等于 JSON 分配量，也不等于 managed heap 配置。

## 完整发布对照

| Case | Baseline µs/op | Candidate µs/op | C/B | Baseline CV | Candidate CV | Candidate wins / 11 | Baseline max RSS KiB | Candidate max RSS KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `yjsonStringEncodeLargeInt64Map` | 6.602 | 6.536 | 0.989985 | 0.435% | 0.460% | 10 | 170080 | 170300 |
| `yjsonStringDecodeLargeInt64Map` | 14.147 | 14.292 | 1.010222 | 0.388% | 0.470% | 1 | 164320 | 163436 |
| `yjsonBytesDecodeLargeInt64Map` | 16.943 | 16.940 | 0.999792 | 2.381% | 0.824% | 3 | 169056 | 168948 |
| `yjsonStringEncodeDeepNestedProfiles` | 23.606 | 24.074 | 1.019830 | 0.410% | 0.880% | 0 | 127720 | 127424 |
| `yjsonStringDecodeDeepNestedProfiles` | 112.996 | 111.938 | 0.990636 | 1.217% | 2.015% | 9 | 169640 | 170148 |
| `yjsonBytesDecodeDeepNestedProfiles` | 117.202 | 116.410 | 0.993243 | 0.418% | 0.861% | 9 | 169768 | 170020 |
| `yjsonStringEncodePerson` | 1.104 | 1.148 | 1.039888 | 2.593% | 1.937% | 1 | 117224 | 117324 |
| `yjsonStringDecodePerson` | 3.540 | 2.969 | 0.838760 | 1.691% | 1.260% | 11 | 170008 | 170452 |
| `yjsonStringEncodeLargeProfileArray` | 20.440 | 20.683 | 1.011885 | 0.075% | 0.133% | 0 | 146496 | 146304 |
| `yjsonStringDecodeLargeProfileArray` | 42.243 | 40.945 | 0.969262 | 0.406% | 0.199% | 11 | 117560 | 117348 |
| `parseStringRecords64k` | 1281.901 | 1280.394 | 0.998825 | 1.090% | 1.121% | 7 | 170284 | 170568 |
| `parseBytesRecords64k` | 1384.440 | 1396.949 | 1.009035 | 2.245% | 2.353% | 4 | 170092 | 170332 |
| `parseStringRecords1m` | 26096.746 | 25805.199 | 0.988828 | 2.283% | 1.224% | 8 | 168804 | 168748 |
| `parseBytesRecords1m` | 26826.665 | 26739.009 | 0.996733 | 1.067% | 1.317% | 5 | 168572 | 169040 |
| `yjsonStringEncodeProfileBundle` | 3.721 | 3.670 | 0.986352 | 0.673% | 0.484% | 10 | 117504 | 117584 |
| `yjsonStringDecodeProfileBundle` | 6.189 | 5.170 | 0.835384 | 2.024% | 2.093% | 11 | 169896 | 170560 |
| `yjsonBytesEncodeProfileBundle` | 4.150 | 4.292 | 1.034076 | 1.285% | 0.884% | 0 | 138464 | 136572 |
| `yjsonBytesDecodeProfileBundle` | 7.037 | 6.887 | 0.978553 | 0.759% | 0.876% | 9 | 156276 | 149712 |
| `yjsonStringEncodeEscapedUnicodeString` | 0.776 | 0.787 | 1.013367 | 1.451% | 0.522% | 1 | 170184 | 170516 |
| `yjsonBytesEncodeEscapedUnicodeString` | 0.637 | 0.653 | 1.024649 | 1.800% | 3.561% | 0 | 170240 | 170440 |
| `decodePersonChunk4k` | 23.844 | 23.588 | 0.989257 | 0.285% | 0.529% | 11 | 145132 | 147572 |
| `decodeRecords64kChunk4k` | 6048.027 | 6028.169 | 0.996716 | 0.445% | 0.758% | 6 | 117456 | 117832 |
| `encodePersonMemory` | 6.826 | 7.010 | 1.027003 | 1.588% | 1.927% | 2 | 169832 | 170108 |
| `encodeRecords64kMemory` | 565.648 | 558.943 | 0.988147 | 0.816% | 1.322% | 8 | 169384 | 168856 |

## BASE Deep Nested 对照

| Case | Baseline µs/op | Candidate µs/op | C/B | Baseline CV | Candidate CV | Candidate wins / 11 | Baseline max RSS KiB | Candidate max RSS KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `yjsonStringDecodeDeepNestedProfiles` | 113.597 | 113.249 | 0.996933 | 0.596% | 0.428% | 8 | 170044 | 169948 |
| `yjsonBytesDecodeDeepNestedProfiles` | 118.207 | 118.417 | 1.001774 | 0.544% | 0.570% | 4 | 169908 | 169684 |

两项均在原门槛内，不据此声明跨平台改善。该对照与上方发布基线对照分开统计，不拼接样本。

## 保留的失败与诊断

| 源码 | 正式结果 | 稳定超限 |
| --- | --- | --- |
| C1 `57cfddb61834fb1d3c5c2e573ff6d986124045e2` | FAIL，完整 24 项 × 11 轮 | 六项编码用例超过 1.05 |
| C2 `87f37a76ff02d1214158c787ca6732aaa97ecbd6` | FAIL，完整 24 项 × 11 轮 | Large Int64 Map encode C/B=1.096678 |

C1/C2 均为稳定回退，不作为噪声重跑。两个公开失败包分别保留全部 528 计时及 48 预检、原始日志、
RSS、sidecar、源码和构建审计；离线 verifier 的 PASS 仅表示重现成功，measurementStatus 仍为 FAIL。
C1 的补充宏构建源码保存在诊断包的 `c1-dependency-inputs/`，不改写原失败包。

父进程 GDB 栈采样是侵入式诊断，不作为计时。相邻 writer 变体的三轮隔离定位了固定上界常量实验的
Map 回退；C3 撤回该实验，仅保留经过非负及剩余 span 证明的一/二操作数容量短路。
八组诊断矩阵共 150 计时和 50 预检也由原始日志独立复算，统一标记 `DIAGNOSTIC_ONLY`，不代替正式资格。

## 公开证据边界

私有原包与公开包分别记录 SHA-256。公开投影仅匿名化 owner/PAX owner 及压缩头，全部普通文件载荷、
顺序和非 owner 属性逐项一致；不是下载包字节相同的声明。完整内容审计及逐项误报处置随校验和绑定。
可信 checkout 的程序重算原始 timing/RSS/sidecar、affinity、median/CV/ratio/wins、源码闭包及实际 execve；
归档中的程序只当作数据，没有执行。

本轮不发布 yjson，不外推到 Native 后端、其他 SDK/平台或默认并发配置。
最终交付仍以同一产品/harness 身份的 strict 及 PR Required 为准。
