# 2026-09-21 0.1.1 发布候选 Pure 直接计时资格：通过

源码候选 `fd2a8f7b400c4c80d6aaaf1e71fdd1ac5ff422ab` 相对实际发布的 `0.1.0` 包源码通过正式 Pure 资格。
一批完整测量覆盖 24 个 case × 11 轮 × baseline/candidate，共 528 个计时进程，另有 48 个预检进程。
全部 C/B 中位数比值不超过 `1.05`，48 个单侧 CV 均不超过 `5%`；没有第二批。

最差项 `yjsonStringDecodeLargeProfileArray` 为 `+3.539109%`。
Deep Nested string decode 为 `+0.321852%`，bytes decode 为 `+0.150699%`。
正值表示候选更慢。通过 5% 回退门槛不等于每项更快，也不构成新的优化倍数声明。

## 协议与范围

使用 `YJSON_PURE_DIRECT_V1`、`direct_timing_protocol: 1`；固定工作量、最低预热、segments 和 exact case 不变。
逐个复核了 576 份 stdout、direct sidecar、GNU time RSS 和 ready/continue 握手记录；每个进程通过且只有一条有效 direct marker。
奇数轮 baseline 先执行，偶数轮 candidate 先执行，没有删样本或跨批拼接。

Linux x86_64、Cangjie STS `1.1.3`、`cjProcessorNum=1`、`cjHeapSize=128MB`。
业务、GC main/helper、GC pool/schmon 分别绑定 CPU 1、2、3，并监测 sibling 49、50、51。
30 秒筛选中六个逻辑 CPU 均低于 1%；正式运行保留逐秒监测。两侧构建前后源码干净，身份不变。
结果不外推到其他平台、默认并发配置或 Native provider。七库 SDKBench 结果使用另一协议，不比较绝对延迟或拼接样本。

## 完整正式结果

时延为 11 个独立进程 ns/op 的中位数，表中换算为 µs/op；CV 使用 sample standard deviation。
RSS 为每侧 11 份 sidecar 的实际最大值，不是托管堆存活量；本协议没有 RSS 门禁。

| Case | Baseline median (µs/op) | Candidate median (µs/op) | C/B | 变动 | Candidate wins | Baseline CV | Candidate CV | Baseline max RSS (KB) | Candidate max RSS (KB) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `yjsonStringEncodeLargeInt64Map` | 6.969666 | 6.468901 | 0.928151 | -7.184920% | 11/11 | 0.773% | 1.153% | 190696 | 190120 |
| `yjsonStringDecodeLargeInt64Map` | 14.207919 | 14.343308 | 1.009529 | +0.952914% | 0/11 | 0.257% | 0.331% | 188372 | 187544 |
| `yjsonBytesDecodeLargeInt64Map` | 16.950528 | 17.035952 | 1.005040 | +0.503962% | 1/11 | 0.273% | 0.663% | 190636 | 190100 |
| `yjsonStringEncodeDeepNestedProfiles` | 23.340814 | 23.152971 | 0.991952 | -0.804785% | 8/11 | 0.935% | 0.904% | 147724 | 148476 |
| `yjsonStringDecodeDeepNestedProfiles` | 110.314409 | 110.669459 | 1.003219 | +0.321852% | 5/11 | 0.338% | 0.508% | 188976 | 188812 |
| `yjsonBytesDecodeDeepNestedProfiles` | 116.809892 | 116.985924 | 1.001507 | +0.150699% | 5/11 | 0.379% | 0.274% | 188716 | 188368 |
| `yjsonStringEncodePerson` | 1.067178 | 1.039382 | 0.973954 | -2.604567% | 10/11 | 1.363% | 1.799% | 132164 | 135900 |
| `yjsonStringDecodePerson` | 3.502776 | 3.561141 | 1.016663 | +1.666256% | 0/11 | 0.529% | 1.072% | 190556 | 190104 |
| `yjsonStringEncodeLargeProfileArray` | 20.364877 | 20.127933 | 0.988365 | -1.163496% | 10/11 | 0.323% | 1.330% | 164984 | 165540 |
| `yjsonStringDecodeLargeProfileArray` | 40.481421 | 41.914102 | 1.035391 | +3.539109% | 0/11 | 0.100% | 1.370% | 135868 | 137616 |
| `parseStringRecords64k` | 1290.628601 | 1288.531505 | 0.998375 | -0.162486% | 5/11 | 2.726% | 2.611% | 190396 | 190136 |
| `parseBytesRecords64k` | 1415.287467 | 1392.300519 | 0.983758 | -1.624189% | 6/11 | 2.096% | 4.285% | 190364 | 190032 |
| `parseStringRecords1m` | 24771.241850 | 24570.552015 | 0.991898 | -0.810173% | 9/11 | 0.925% | 0.995% | 187764 | 187692 |
| `parseBytesRecords1m` | 26554.105920 | 26311.952200 | 0.990881 | -0.911926% | 6/11 | 0.694% | 1.198% | 188084 | 188072 |
| `yjsonStringEncodeProfileBundle` | 3.553527 | 3.529567 | 0.993257 | -0.674251% | 7/11 | 1.201% | 1.315% | 135980 | 136080 |
| `yjsonStringDecodeProfileBundle` | 5.929061 | 5.991366 | 1.010508 | +1.050834% | 4/11 | 2.605% | 2.071% | 190220 | 190072 |
| `yjsonBytesEncodeProfileBundle` | 4.018430 | 3.999485 | 0.995286 | -0.471440% | 10/11 | 0.735% | 0.545% | 159664 | 160060 |
| `yjsonBytesDecodeProfileBundle` | 6.583782 | 6.536233 | 0.992778 | -0.722214% | 8/11 | 0.991% | 0.875% | 180852 | 181776 |
| `yjsonStringEncodeEscapedUnicodeString` | 0.794602 | 0.796148 | 1.001945 | +0.194532% | 5/11 | 1.165% | 1.746% | 190432 | 190212 |
| `yjsonBytesEncodeEscapedUnicodeString` | 0.635905 | 0.640802 | 1.007701 | +0.770052% | 3/11 | 1.437% | 1.226% | 190724 | 190280 |
| `decodePersonChunk4k` | 24.545758 | 23.234684 | 0.946586 | -5.341350% | 11/11 | 0.357% | 0.768% | 159864 | 166048 |
| `decodeRecords64kChunk4k` | 6351.044373 | 5921.552869 | 0.932375 | -6.762534% | 11/11 | 0.379% | 0.626% | 135800 | 135772 |
| `encodePersonMemory` | 7.010206 | 7.162759 | 1.021762 | +2.176151% | 1/11 | 1.142% | 1.562% | 190704 | 190332 |
| `encodeRecords64kMemory` | 561.607169 | 558.529778 | 0.994520 | -0.547962% | 7/11 | 1.192% | 1.116% | 188008 | 189408 |

## 身份、基线纠正与证据

| 项目 | 值 |
| --- | --- |
| Candidate measured commit / tree | `ce39e57ba6ade281d232bc0d82abfafdf91f5bb5` / `4826abc45cac6fdff757ce6ee36dd50219b2eded` |
| Baseline measured commit / tree | `eef197c7fd0124e1b2cfd105bdaad2d0ae894d97` / `2a54750a266d771f0cf5d5e25691c42bd69d9e7b` |
| Candidate product SHA-256 | `9e22b132f38b28f15ef698a373247ac91ad4bdbe922bd8fae42c1b09cdcf30cf` |
| Baseline product SHA-256 | `e367e12cfdc9af4857c60589878370d63d011af4edac5df36174aebe87ae8fc8` |
| Shared effective harness SHA-256 | `4d34fcb5e5a160e46c293efd996ac9fc416aa2858d316d163e1cf7c22bba1cc3` |

测量提交属于隔离冻结树；候选产品、有效 harness 和版本依赖绑定与上述主仓库源码候选一致，不要求 Git tree 相同。
实际发布基线为 runtime `89c22a933cbd7e5cdc9b0f8df725ca6e1cda2372`、macro `fec0adce41f73d037d876cbac7a28aee8108bb5c`。
下载校验后的九个发布包中，43 个 runtime 和 2 个宏源文件均与该身份逐字节一致。
两侧使用相同的当前测量 harness；不是将旧包的历史测量值拿来对比。

`0.1.0` tag 与实际发布源码不一致，已记录为 [issue #6](https://github.com/lIlIIlIll/yjson/issues/6)。
首次 tag-baseline 部分批次发现该问题后中止，完整保留在独立归档中；其样本不进入上表，历史 tag 和附件没有修改。

[本轮证据索引](../../../benchmarks/results/release-performance/2026-09-21-release-011/README.md)包含完整正式归档、独立复核、实际发布基线源码和中止批次。
正式归档 SHA-256：`e7bf130a48bad1d7ea81d79e87783e9ccb54bafb202cbde0e128b7a3ebeb9f85`。
候选源码胶囊由本轮七库证据共用。产品、harness 或版本绑定变化后不得复用本轮资格。

以下历史结果及失败记录按原身份保留，不参与本次发布统计。

---

## 历史记录：2026-09-20 评审修复候选 Pure 直接计时资格通过

候选 `c5ccfd6953ea57adedc4c642dbb51aa2fbb9a12a` 相对基线 `fce62c75ff03b61bed0bc72331d1c2e71b2f1b6b` 通过正式 Pure 资格。
一批完整测量覆盖 24 个 case × 11 轮 × baseline/candidate 两侧，共 528 个计时进程；另有 48 个不计入统计的预检进程。
24 个 `candidate/baseline` 中位数比值均不超过 `1.05`，48 个单侧 CV 均不超过 `5%`，没有第二批。

最差一项是 `yjsonStringDecodeLargeProfileArray`，变动为 `+2.064919%`。
Deep Nested string decode 为 `+0.415102%`，bytes decode 为 `-0.043659%`。
流式 `decodeRecords64kChunk4k` 为 `-4.819148%`，大型整数映射编码为 `-0.685422%`。
正值表示候选更慢，负值表示更快；通过 5% 门槛不等于所有用例都更快。

## 本轮协议与范围

使用 `YJSON_PURE_DIRECT_V1`，即 `direct_timing_protocol: 1`；固定工作量、最低预热、segments 和 exact case 不变。
每个进程只有一条有效 direct marker，且 unittest 为 `PASSED: 1`、`ERROR: 0`、`FAILED: 0`。
奇数轮 baseline 先执行，偶数轮 candidate 先执行；ready/continue 握手完成线程发现和绑定后才开始后续计时。
stdout、direct sidecar、GNU time RSS、线程放置和全部统计均已独立复核。

范围限于 Linux x86_64、Cangjie STS `1.1.3`、`cjProcessorNum=1`、`cjHeapSize=128MB`。
业务、GC main/helper、GC pool/schmon 分别绑定 CPU 1、2、4；同时检查 sibling 49、50、52。
30 秒空闲筛选中六个逻辑 CPU 均低于 1%，正式运行保留逐秒监测。双方构建前后源码干净，产品与 harness 身份不变。
本轮不证明默认并发配置、其他平台或真实 Native provider 的性能，也不构成发布许可。

七库使用独立 SDKBench 协议；即使用例同名，也不能与本页拼接样本或比较绝对延迟。
七库矩阵和完整性状态见[七库报告](2026-09-13-release-seven-library.md)。

## 本轮完整正式结果

时延是 11 个独立进程 `ns/op` 的中位数，表中换算为 µs/op。CV 使用 sample standard deviation。
RSS 是每侧 11 份 GNU time sidecar 的实际最大值，不是托管堆存活量；本协议没有 RSS 门禁。

| Case | Baseline median (µs/op) | Candidate median (µs/op) | C/B | 变动 | Candidate wins | Baseline CV | Candidate CV | Baseline max RSS (KB) | Candidate max RSS (KB) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `yjsonStringEncodeLargeInt64Map` | 6.492377 | 6.447877 | 0.993146 | -0.685422% | 6/11 | 1.626% | 0.709% | 190848 | 190084 |
| `yjsonStringDecodeLargeInt64Map` | 14.179830 | 14.334539 | 1.010911 | +1.091050% | 1/11 | 1.583% | 2.608% | 189228 | 188200 |
| `yjsonBytesDecodeLargeInt64Map` | 16.888977 | 17.065586 | 1.010457 | +1.045706% | 1/11 | 0.997% | 1.129% | 190616 | 189876 |
| `yjsonStringEncodeDeepNestedProfiles` | 23.090366 | 23.246656 | 1.006769 | +0.676864% | 4/11 | 2.126% | 1.905% | 147920 | 147912 |
| `yjsonStringDecodeDeepNestedProfiles` | 109.906837 | 110.363062 | 1.004151 | +0.415102% | 1/11 | 0.226% | 0.379% | 189184 | 188796 |
| `yjsonBytesDecodeDeepNestedProfiles` | 116.594481 | 116.543576 | 0.999563 | -0.043659% | 4/11 | 0.357% | 0.466% | 188660 | 188392 |
| `yjsonStringEncodePerson` | 1.055472 | 1.039299 | 0.984676 | -1.532363% | 8/11 | 1.840% | 1.546% | 133176 | 135888 |
| `yjsonStringDecodePerson` | 3.524545 | 3.556235 | 1.008991 | +0.899125% | 2/11 | 0.600% | 1.094% | 190608 | 190244 |
| `yjsonStringEncodeLargeProfileArray` | 21.209055 | 20.142585 | 0.949716 | -5.028370% | 10/11 | 1.055% | 2.442% | 161260 | 165516 |
| `yjsonStringDecodeLargeProfileArray` | 41.027617 | 41.874804 | 1.020649 | +2.064919% | 1/11 | 0.821% | 0.907% | 132872 | 137432 |
| `parseStringRecords64k` | 1290.860585 | 1307.679401 | 1.013029 | +1.302915% | 3/11 | 2.048% | 2.653% | 190328 | 190024 |
| `parseBytesRecords64k` | 1446.189602 | 1438.200567 | 0.994476 | -0.552420% | 4/11 | 2.983% | 2.344% | 190212 | 189940 |
| `parseStringRecords1m` | 24093.742120 | 24395.734625 | 1.012534 | +1.253406% | 1/11 | 1.083% | 0.851% | 187904 | 187572 |
| `parseBytesRecords1m` | 26647.670810 | 26538.357005 | 0.995898 | -0.410219% | 6/11 | 0.787% | 1.067% | 188112 | 187812 |
| `yjsonStringEncodeProfileBundle` | 3.506833 | 3.514906 | 1.002302 | +0.230193% | 5/11 | 1.095% | 0.717% | 135900 | 135852 |
| `yjsonStringDecodeProfileBundle` | 5.967494 | 6.057762 | 1.015127 | +1.512655% | 5/11 | 2.841% | 2.871% | 190432 | 189984 |
| `yjsonBytesEncodeProfileBundle` | 3.956155 | 3.977643 | 1.005431 | +0.543142% | 6/11 | 1.771% | 1.791% | 161404 | 161496 |
| `yjsonBytesDecodeProfileBundle` | 6.499907 | 6.617686 | 1.018120 | +1.812007% | 3/11 | 2.024% | 1.241% | 182112 | 181180 |
| `yjsonStringEncodeEscapedUnicodeString` | 0.798419 | 0.798570 | 1.000189 | +0.018946% | 6/11 | 1.727% | 1.334% | 190468 | 190300 |
| `yjsonBytesEncodeEscapedUnicodeString` | 0.644688 | 0.643433 | 0.998053 | -0.194693% | 8/11 | 1.178% | 1.212% | 190624 | 190284 |
| `decodePersonChunk4k` | 24.515228 | 23.232005 | 0.947656 | -5.234390% | 11/11 | 0.680% | 1.932% | 160600 | 166808 |
| `decodeRecords64kChunk4k` | 6254.763266 | 5953.336971 | 0.951809 | -4.819148% | 11/11 | 0.498% | 1.029% | 135860 | 137556 |
| `encodePersonMemory` | 7.061110 | 7.109702 | 1.006882 | +0.688169% | 5/11 | 1.839% | 1.749% | 190788 | 190100 |
| `encodeRecords64kMemory` | 565.405160 | 567.588861 | 1.003862 | +0.386219% | 4/11 | 1.151% | 1.239% | 189360 | 189392 |

## 评审后的失败与修复

以下失败没有被本轮通过覆盖，也没有删除超限行、第三批重试或跨批拼接。

| 尝试 | 正式单元 | 结果 | 后续处理 |
| --- | ---: | --- | --- |
| review-v1 | 0 | 覆盖率修复改变候选源码；完成 11 个预检后中止 | 冻结新候选，旧预检不进入统计 |
| review-v2 A：`08e2c7a` | 528 | 流式解码 C/B `1.067956`；两侧 CV `3.399% / 6.224%` | noisy 触发唯一一次完整 B 批 |
| review-v2 B：`08e2c7a` | 528 | 同项 C/B `1.053621`；两侧 CV `0.646% / 1.896%` | 稳定失败，停止重试并修复源码 |
| review-v3 A：`d759d70` | 528 | 大型整数映射编码 C/B `1.076158`；两侧 CV `1.142% / 0.799%` | 稳定失败，无第二批；继续修复源码 |
| review-v4 传输预检：`598e1c5` | 0 | 两份 release 清单未跟踪，clean-source 检查在构建前拒绝 | 补全冻结提交；没有构建或计时样本 |
| 本轮 A：`c5ccfd6` | 528 | 全部比例与 CV 通过 | 无需复测 |

review-v2 的流式回退修复把 `readJsonString()` 的固定字符串预算读取移出逐字节循环，仍在原位置检查超限。
外部使用方测试覆盖原始与转义 Unicode 的字节预算边界，以及超限先于后续非法转义的错误顺序。
review-v3 的映射回退修复精简了 `jsonRawCompactStringEscapeIndex()` 的紧凑 key 扫描。
STS 1.1.3 产物的普通未转义字节循环由 22 条指令降为 16 条，去掉三次重复字符比较和三条 `cmov` 指令。

独立的五用例、11 轮源码修复诊断共 110 个进程：映射编码 after/before 为 `0.923777`。
该诊断比较的是 `d759d70` 与扫描修复，不是正式 baseline/candidate；没有任何诊断样本并入上表。
正式通过只来自本轮完整的 24-case 批次。

## 本轮身份与证据

| 项目 | 值 |
| --- | --- |
| Candidate commit / tree | `c5ccfd6953ea57adedc4c642dbb51aa2fbb9a12a` / `9fdaf2bf352dd78bb3db2686d986082e15887c8d` |
| Baseline commit / tree | `fce62c75ff03b61bed0bc72331d1c2e71b2f1b6b` / `97416ee14444470a3b5919b3646d1b3970e3f452` |
| Candidate product SHA-256 | `9e22b132f38b28f15ef698a373247ac91ad4bdbe922bd8fae42c1b09cdcf30cf` |
| Baseline product SHA-256 | `9c1e738dcf8e8a56314e433874555ff8830bac9652c57268658050199df0a847` |
| Shared effective harness SHA-256 | `7b65d3cfc50c50bfbeb4ddce20e84183619ea7081a775f2a8152336fb4a1e2ab` |

测量提交属于隔离冻结树；与主仓库源码提交 `67fb3aabfef11cb9d415b3f62b3c44f262228b59` 的产品和有效 harness 相同，不要求 Git tree 相同。
产品、harness 或发布依赖绑定变化后，不能复用本轮资格。

文件位置与核对命令见[本轮 Pure 证据索引](../../../benchmarks/results/release-performance/2026-09-20-maintainability-c5ccfd6/README.md)：

- `pure-direct-review-v4-evidence.tar.gz`：本轮全部原始进程、构建、CPU、退出码、独立复核、110 个诊断进程及反汇编；SHA-256 `33e9faddfcfbfeac43d0704f109b7d9bf0be08e5cc9c93bd82608fc84b0cab4a`。
- `pure-direct-review-failed-candidates.tar.gz`：三批共 1,584 个失败正式单元、144 个对应预检、11 个中止预检、构建前拒绝记录，以及失败候选的源码与复核；SHA-256 `72a32bcc7f0283cd0f80548bce7df9033d1486648980e7dfd56abd4aae6738b0`。
- `pure-direct-review-baseline-source.tar.gz`：175 个冻结基线文件；SHA-256 `13c16cec2f2447f9a761de16da7ef219f127d55f4b2de6bc62b1c8dfad9a6d13`。
- 候选源码复用[本轮七库证据目录](../../../benchmarks/results/full-seven-library/2026-09-20-maintainability-c5ccfd6/README.md)的 `candidate-source.tar.gz`：179 个冻结文件；SHA-256 `dd14466c63bcb0d99332ebe23c8167bd297dcdfe1fe35f43ab78d6887c8169a3`。
- 基线和候选的源码归档均重建出完整的 51 个产品输入和 28 个 harness 输入。
  日志仅规范化工作目录与 home 路径前缀；源码归档和计时值没有改写。
- 同一产品与 harness 的干净主仓库检出通过 `scripts/ci_fresh_checkout.sh` 全部 17 个 Linux 门禁；这不是托管 CI 或其他平台的通过声明。

原有 `7d086a6` 的通过、较早候选的失败及其归档保持不变，以下按历史身份保留。

---

## 历史记录：7d086a6 的 Pure 直接计时资格通过

候选 `7d086a69200cecb447c64e73fa2b5e61e584ddb7` 相对基线 `3d0ae8981db4c30926411568bedb7ba7d0607d95` 的 Pure 正式资格化通过。
唯一一批正式测量覆盖 24 个 case、11 轮和 baseline/candidate 两侧，共 528 个计时进程；另有 48 个不计入统计的预检进程。
24 个 `candidate/baseline` 中位数比值均不超过 `1.05`，48 个单侧 CV 均不超过 `5%`，因此没有第二批。

最差一项是 `yjsonStringEncodePerson`，候选比基线慢 `+3.290916%`。
Deep Nested string decode 变动为 `-0.229176%`，bytes decode 变动为 `+0.328934%`。
负值表示候选更快，正值表示候选更慢。

**测量范围是 Linux x86_64、Cangjie STS 1.1.3、`cjProcessorNum=1`、`128MB` 堆，以及三颗同 NUMA 节点物理核上的固定线程布局。**
业务线程、GC main/helper 和 GC pool/schmon 分别绑定 CPU 1、4、7；CPU 选择同时检查其 sibling 49、52、55，正式测量期间保留逐秒监测。
这些结果只说明本次 Pure workload，不代表默认运行时配置、其他操作系统、Native provider 或产品整体。

### 门禁和直接计时协议

本次使用 `YJSON_PURE_DIRECT_V1`，即 `direct_timing_protocol: 1`。
每个进程恰好提供一条直接计时 marker；runner 核对固定 operations、正 elapsed、最低预热、segments、唯一成功用例、线程布局和 GNU time RSS sidecar。
奇数轮先运行 baseline，偶数轮先运行 candidate；每个进程在 ready/continue 握手完成线程发现和绑定后才继续。
日志中的 `YJSON_FIXED_WORK_V1` 行只声明冻结工作量，不表示本次使用 SDKBench `fixed_work_protocol`，两个协议没有混合汇总。

正式批次退出码为 0，所有 528 个正式进程与 48 个预检进程均为 `PASSED: 1`、`ERROR: 0`、`FAILED: 0`。
独立复核从每份 stdout、direct sidecar 和 RSS sidecar 重算 24 组中位数、样本 CV、比值和胜负轮数，结果与 summary 一致。
`release` 比例门槛通过，且没有 noisy case。

前三次尝试没有产生正式样本，也没有并入本表：v1 因必需 manifest 未跟踪而在构建前被拒绝，v2 因 provenance 收集缺少 `os` import 在构建前失败，v3 因 SDK progress 输出覆盖直接 marker 而在首个预检中失败。
归档将三次失败分别保存在 `v1-manifest-missing`、`v2-import-missing` 和 `v3-progress-collision` 下。

### 完整正式结果

时延是 11 个独立进程 `ns/op` 的中位数。`C/B` 和“变动”都以 candidate/baseline 计算。
CV 使用 11 个进程样本的 sample standard deviation。RSS 是该 case 11 份 GNU time sidecar 的实际最大值，不是托管堆存活量；本次没有定义 RSS 门禁。

| Case | Baseline median (µs/op) | Candidate median (µs/op) | C/B | 变动 | Candidate wins | Baseline CV | Candidate CV | Baseline max RSS (KB) | Candidate max RSS (KB) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `yjsonStringEncodeLargeInt64Map` | 6.421900 | 6.629162 | 1.032274 | +3.227420% | 0/11 | 1.040% | 1.181% | 190660 | 190672 |
| `yjsonStringDecodeLargeInt64Map` | 14.662147 | 14.869477 | 1.014140 | +1.414048% | 3/11 | 0.799% | 1.052% | 185176 | 183580 |
| `yjsonBytesDecodeLargeInt64Map` | 17.255833 | 17.604358 | 1.020198 | +2.019754% | 1/11 | 0.521% | 0.944% | 190520 | 189312 |
| `yjsonStringEncodeDeepNestedProfiles` | 23.989776 | 24.134416 | 1.006029 | +0.602927% | 4/11 | 1.198% | 1.641% | 145980 | 146008 |
| `yjsonStringDecodeDeepNestedProfiles` | 109.680932 | 109.429570 | 0.997708 | -0.229176% | 6/11 | 1.277% | 0.247% | 189568 | 189120 |
| `yjsonBytesDecodeDeepNestedProfiles` | 115.449114 | 115.828865 | 1.003289 | +0.328934% | 3/11 | 0.419% | 0.405% | 188680 | 188928 |
| `yjsonStringEncodePerson` | 1.051170 | 1.085763 | 1.032909 | +3.290916% | 0/11 | 0.843% | 1.191% | 133684 | 133036 |
| `yjsonStringDecodePerson` | 3.512187 | 3.485537 | 0.992412 | -0.758799% | 8/11 | 0.495% | 0.877% | 190564 | 190704 |
| `yjsonStringEncodeLargeProfileArray` | 21.670052 | 20.766743 | 0.958315 | -4.168471% | 11/11 | 0.775% | 1.464% | 161036 | 164572 |
| `yjsonStringDecodeLargeProfileArray` | 41.399777 | 40.598721 | 0.980651 | -1.934929% | 10/11 | 0.921% | 0.664% | 133808 | 133068 |
| `parseStringRecords64k` | 1291.260145 | 1304.338590 | 1.010128 | +1.012844% | 3/11 | 2.435% | 2.029% | 190444 | 190320 |
| `parseBytesRecords64k` | 1434.213514 | 1412.012721 | 0.984521 | -1.547942% | 6/11 | 2.278% | 3.479% | 190332 | 190436 |
| `parseStringRecords1m` | 24079.189220 | 24187.383170 | 1.004493 | +0.449326% | 4/11 | 1.140% | 1.031% | 187740 | 187812 |
| `parseBytesRecords1m` | 26608.303240 | 26401.046485 | 0.992211 | -0.778918% | 7/11 | 1.209% | 1.231% | 187800 | 188196 |
| `yjsonStringEncodeProfileBundle` | 3.614230 | 3.681845 | 1.018708 | +1.870800% | 1/11 | 0.373% | 0.902% | 135680 | 132404 |
| `yjsonStringDecodeProfileBundle` | 6.002002 | 6.050574 | 1.008093 | +0.809265% | 4/11 | 2.450% | 3.134% | 190436 | 190404 |
| `yjsonBytesEncodeProfileBundle` | 4.201021 | 4.257856 | 1.013529 | +1.352874% | 2/11 | 1.921% | 0.753% | 157544 | 156592 |
| `yjsonBytesDecodeProfileBundle` | 6.709776 | 6.724470 | 1.002190 | +0.219005% | 6/11 | 0.989% | 1.205% | 179184 | 180008 |
| `yjsonStringEncodeEscapedUnicodeString` | 0.802182 | 0.794988 | 0.991032 | -0.896848% | 7/11 | 1.338% | 1.899% | 190608 | 190872 |
| `yjsonBytesEncodeEscapedUnicodeString` | 0.658605 | 0.646221 | 0.981197 | -1.880283% | 6/11 | 1.686% | 0.817% | 190580 | 190892 |
| `decodePersonChunk4k` | 25.583594 | 25.657355 | 1.002883 | +0.288317% | 4/11 | 1.334% | 2.822% | 160840 | 159232 |
| `decodeRecords64kChunk4k` | 6343.445047 | 6474.796141 | 1.020707 | +2.070659% | 0/11 | 0.712% | 1.575% | 133800 | 132796 |
| `encodePersonMemory` | 6.997257 | 6.879593 | 0.983184 | -1.681581% | 7/11 | 3.312% | 3.269% | 190512 | 190436 |
| `encodeRecords64kMemory` | 568.087999 | 566.457253 | 0.997129 | -0.287059% | 8/11 | 0.416% | 0.549% | 188380 | 189092 |

### 身份和完整证据

- candidate 产品源码摘要：`1c3d85aca3fec86594d1732bb8779728cd42e7e5b7656b720bd0f934390cb2c9`；tree `53527121b6bdca31586505ec838b5b092cd15924`。
- baseline 产品源码摘要：`9c1e738dcf8e8a56314e433874555ff8830bac9652c57268658050199df0a847`；tree `f053b4d9dfa7192ae7bdf1c47861cad170d5a56e`。
- 双方共享的 28 文件 effective harness：`43461d89631bd104fc93f32b0319dfc3d386c5a6a1266cd47bec4d1e2559268f`。
- 完整清洗归档：`pure-direct-v4-evidence.tar.gz`，SHA-256 `87cfacd795641eb3da62a43b471e46048e41edce3ccf3c5f1fdb8aae31ea1c78`。它包含构建日志、CPU 选择和监测、48 个预检与 528 个正式进程的 stdout/direct/RSS、线程布局、ready/continue、provenance、退出码、qualification state、三次失败尝试、独立复核和内部 checksums。文件位置与核对命令见 [Pure 证据索引](../../../benchmarks/results/release-performance/2026-09-20-maintainability-7d086a6/README.md)。
- baseline 冻结源码：`pure-direct-v4-baseline-source.tar.gz`，SHA-256 `a60d4a95a274d85bf620d541eadd4ac399ef82a22be3ab716eaf88721c420611`；同目录的 `pure-direct-v4-baseline-source-manifest.json` 绑定 51 个产品输入和 28 个 harness 输入。
- candidate 冻结源码复用[七库证据目录](../../../benchmarks/results/full-seven-library/2026-09-20-maintainability-7d086a6/README.md)中的 `candidate-source.tar.gz`，SHA-256 `19866a87e5f1a4d69392e7e63fd3ffdff5d51780ecb7dbfaa46d5314ca7ad0d7`，不重复复制。
- `pure-direct-v4-validation.json` 和 `pure-direct-v4-checksums.txt` 记录 archive member 安全、隐私扫描、源码绑定和重算结果。二者也位于 Pure 证据目录。

本次直接计时资格化替代旧 SDKBench 协议作为当前候选的 Pure 性能判据，但不改写历史失败。
下文保留旧候选、旧 harness 和旧协议的全部阈值、测量和失败结论。

---

## 历史记录：2026-09-18 单并发固定工作量 Pure A/B 门禁未通过

候选 `f4aed80847e77fee12a156e8644f65ab34c64092` 的两批完整验收均未通过 `candidate/baseline <= 1.05`。
第一批有 4 项超限和 7/24 noisy case，按[性能方法](../methodology.md)完成唯一一次整批复测。
第二批仍有 2 项超限和 8/24 noisy case。两批分别保留，没有第三批、单行补跑或样本拼接。

**这是单核绑定、`cjProcessorNum=1`、`128MB` 堆下的结果，不代表默认运行时配置，也不是发布声明。**
单并发方案使完整测量不再因统计阶段 OOM 中止，但没有使性能门禁通过。
[七库证据](2026-09-13-release-seven-library.md)完整性不能替代本页的回退结论。

## 基线与测量协议

基线产品来自主仓库 `2303a064ce2244fe08014f2b3fa08fa71931ceb8` 和宏仓库 `5961c2f448f989fb23a9731265ce025aad8bffaf`。
隔离基线为 `e53b5bbd8587094f5e796971450323e233fb01d0`，双方使用相同的 26 文件 harness。
它包括两种运行器、固定工作量校验器及归一化后的 Native C 构建布局。宏使用本地源码，生产 Git pin 未改。
这是相同 C 构建闭包下的 runtime/macro Pure A/B，不是 RF-009 C 抽取或真实 Native provider 的性能证明。

两批均为 24 case × 11 轮 × 2 侧，使用 `--gate-mode release --rebuild --enforce`，没有 optimization target。
每批 528 个计时子进程均退出 0，日志均为 `PASSED: 1`、`ERROR: 0`、`FAILED: 0`。
失败来自比例门禁，不是未处理异常或测量不完整。

每个 case 的 batch size 和 batch 数固定，双方所有轮次一致。统一 batch 上限为 65,536；
`encodePersonMemory` 的有效工作量为 65,536 × 1。provider 生命周期和计时 body 未改。
`release` CLI 的退出判据是比例门禁；CV 决定稳定性标记和一次完整复测，不用于删除超限结果。

## Gate 结论

| 批次 | Cases × 轮次 | CLI 退出码 | 全部 C/B <= 1.05 | Noisy cases | 正式结论 |
| --- | --- | ---: | --- | ---: | --- |
| 第一批 | 24 × 11 | 1 | false | 7/24 | 未通过；按 noisy 规则完整复测一次 |
| 第二批 | 24 × 11 | 1 | false | 8/24 | 未通过；停止重试 |

所有超过门槛的行如下。CV 超过 5% 的比例不作为稳定回退幅度的声明，但仍计入失败。

| 批次 | Case | C/B | Baseline CV | Candidate CV |
| --- | --- | ---: | ---: | ---: |
| 第一批 | `yjsonStringDecodeLargeInt64Map` | 1.056158 | 1.324% | 4.201% |
| 第一批 | `yjsonBytesDecodeLargeInt64Map` | 1.053887 | 5.510% | 6.131% |
| 第一批 | `yjsonBytesDecodeDeepNestedProfiles` | 1.060529 | 8.107% | 4.116% |
| 第一批 | `encodePersonMemory` | 1.066667 | 16.603% | 15.520% |
| 第二批 | `yjsonBytesDecodeLargeInt64Map` | 1.067525 | 5.976% | 6.608% |
| 第二批 | `yjsonStringEncodeEscapedUnicodeString` | 1.058111 | 10.789% | 11.401% |

Large Map string decode 第一批两侧 CV 均低于 5%，C/B 为 `1.056158`；第二批为 `1.035073`。
Large Map bytes decode 两批均超限，但两侧 CV 都超过 5%。现有数据不足以把差异确定为源码、产物布局或运行时噪声中的某一种原因。

## Deep Nested

第一批 bytes decode 的 C/B 为 `1.060529`，超过门槛。第二批三个 case 均满足 `C/B <= 1.05`，
但不能覆盖第一批失败，也不能据此宣称已经证明 Deep Nested 不回退。

| Case | 第一批 C/B | 第一批 baseline/candidate CV | 第二批 C/B | 第二批 baseline/candidate CV |
| --- | ---: | --- | ---: | --- |
| `yjsonStringEncodeDeepNestedProfiles` | 1.004286 | 1.527% / 2.189% | 0.999211 | 6.134% / 7.524% |
| `yjsonStringDecodeDeepNestedProfiles` | 0.956482 | 6.825% / 6.826% | 1.017604 | 6.359% / 2.813% |
| `yjsonBytesDecodeDeepNestedProfiles` | 1.060529 | 8.107% / 4.116% | 1.004768 | 5.128% / 6.167% |

## 第一批完整结果

时延单位为 µs/op。RSS 为该 case 的 11 份 GNU time sidecar 中的最大值，不等于托管堆存活量。

| Case | Baseline median | Candidate median | C/B | Improvement | Wins | Baseline CV | Candidate CV | Baseline max RSS KB | Candidate max RSS KB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `yjsonStringEncodeLargeInt64Map` | 12.522 us | 12.514 us | 0.999x | 0.1% | 8/11 | 0.20% | 0.22% | 190876 | 190220 |
| `yjsonStringDecodeLargeInt64Map` | 46.169 us | 48.762 us | 1.056x | -5.6% | 0/11 | 1.32% | 4.20% | 166676 | 163516 |
| `yjsonBytesDecodeLargeInt64Map` | 53.445 us | 56.325 us | 1.054x | -5.4% | 5/11 | 5.51% | 6.13% | 169444 | 159980 |
| `yjsonStringEncodeDeepNestedProfiles` | 57.863 us | 58.111 us | 1.004x | -0.4% | 6/11 | 1.53% | 2.19% | 158828 | 159824 |
| `yjsonStringDecodeDeepNestedProfiles` | 376.024 us | 359.660 us | 0.956x | 4.4% | 8/11 | 6.82% | 6.83% | 185240 | 188828 |
| `yjsonBytesDecodeDeepNestedProfiles` | 357.648 us | 379.296 us | 1.061x | -6.1% | 2/11 | 8.11% | 4.12% | 185992 | 188240 |
| `yjsonStringEncodePerson` | 3.208 us | 3.245 us | 1.012x | -1.2% | 6/11 | 2.31% | 3.09% | 162208 | 159120 |
| `yjsonStringDecodePerson` | 10.601 us | 10.430 us | 0.984x | 1.6% | 6/11 | 2.15% | 3.50% | 189984 | 189884 |
| `yjsonStringEncodeLargeProfileArray` | 54.574 us | 54.652 us | 1.001x | -0.1% | 4/11 | 2.37% | 1.91% | 165948 | 164204 |
| `yjsonStringDecodeLargeProfileArray` | 135.910 us | 113.337 us | 0.834x | 16.6% | 8/11 | 10.67% | 10.18% | 164148 | 162388 |
| `parseStringRecords64k` | 2571.680 us | 2600.128 us | 1.011x | -1.1% | 0/11 | 0.24% | 0.32% | 188164 | 190460 |
| `parseBytesRecords64k` | 2589.312 us | 2620.544 us | 1.012x | -1.2% | 0/11 | 0.16% | 0.29% | 188252 | 188128 |
| `parseStringRecords1m` | 50060.672 us | 50893.312 us | 1.017x | -1.7% | 3/11 | 1.53% | 1.47% | 188004 | 187208 |
| `parseBytesRecords1m` | 50866.944 us | 51439.872 us | 1.011x | -1.1% | 5/11 | 2.10% | 2.15% | 187680 | 187820 |
| `yjsonStringEncodeProfileBundle` | 14.212 us | 12.796 us | 0.900x | 10.0% | 9/11 | 8.10% | 7.75% | 171804 | 162940 |
| `yjsonStringDecodeProfileBundle` | 23.010 us | 23.296 us | 1.012x | -1.2% | 4/11 | 3.30% | 3.60% | 172408 | 162732 |
| `yjsonBytesEncodeProfileBundle` | 13.619 us | 13.507 us | 0.992x | 0.8% | 9/11 | 0.82% | 0.62% | 165600 | 164284 |
| `yjsonBytesDecodeProfileBundle` | 26.873 us | 26.913 us | 1.002x | -0.2% | 5/11 | 0.34% | 0.29% | 163360 | 163200 |
| `yjsonStringEncodeEscapedUnicodeString` | 1.826 us | 1.854 us | 1.016x | -1.6% | 5/11 | 7.42% | 8.70% | 164912 | 173292 |
| `yjsonBytesEncodeEscapedUnicodeString` | 1.787 us | 1.795 us | 1.005x | -0.5% | 4/11 | 0.95% | 1.22% | 167436 | 183656 |
| `decodePersonChunk4k` | 30.208 us | 30.208 us | 1.000x | 0.0% | 2/11 | 0.64% | 1.50% | 189184 | 189192 |
| `decodeRecords64kChunk4k` | 17749.760 us | 17809.856 us | 1.003x | -0.3% | 1/11 | 0.21% | 0.17% | 190148 | 190132 |
| `encodePersonMemory` | 3.840 us | 4.096 us | 1.067x | -6.7% | 5/11 | 16.60% | 15.52% | 189964 | 189472 |
| `encodeRecords64kMemory` | 584.192 us | 584.704 us | 1.001x | -0.1% | 4/11 | 0.88% | 0.64% | 189644 | 189852 |

## 第二批完整结果

口径与第一批相同，表格直接由各自 summary 生成，不拼接样本。

| Case | Baseline median | Candidate median | C/B | Improvement | Wins | Baseline CV | Candidate CV | Baseline max RSS KB | Candidate max RSS KB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `yjsonStringEncodeLargeInt64Map` | 12.502 us | 12.506 us | 1.000x | -0.0% | 6/11 | 0.68% | 0.29% | 191004 | 190816 |
| `yjsonStringDecodeLargeInt64Map` | 46.297 us | 47.920 us | 1.035x | -3.5% | 1/11 | 1.40% | 4.67% | 160728 | 167912 |
| `yjsonBytesDecodeLargeInt64Map` | 52.614 us | 56.167 us | 1.068x | -6.8% | 2/11 | 5.98% | 6.61% | 167320 | 163908 |
| `yjsonStringEncodeDeepNestedProfiles` | 58.915 us | 58.868 us | 0.999x | 0.1% | 5/11 | 6.13% | 7.52% | 159856 | 163412 |
| `yjsonStringDecodeDeepNestedProfiles` | 357.420 us | 363.712 us | 1.018x | -1.8% | 3/11 | 6.36% | 2.81% | 188688 | 188584 |
| `yjsonBytesDecodeDeepNestedProfiles` | 372.464 us | 374.240 us | 1.005x | -0.5% | 4/11 | 5.13% | 6.17% | 186592 | 188668 |
| `yjsonStringEncodePerson` | 3.252 us | 3.206 us | 0.986x | 1.4% | 7/11 | 2.59% | 2.73% | 169028 | 158616 |
| `yjsonStringDecodePerson` | 10.524 us | 10.661 us | 1.013x | -1.3% | 5/11 | 3.02% | 2.13% | 189676 | 189908 |
| `yjsonStringEncodeLargeProfileArray` | 54.437 us | 54.486 us | 1.001x | -0.1% | 5/11 | 1.70% | 2.61% | 163092 | 165076 |
| `yjsonStringDecodeLargeProfileArray` | 119.432 us | 111.507 us | 0.934x | 6.6% | 10/11 | 10.51% | 0.91% | 163320 | 162900 |
| `parseStringRecords64k` | 2572.480 us | 2597.376 us | 1.010x | -1.0% | 1/11 | 0.30% | 0.19% | 188056 | 190412 |
| `parseBytesRecords64k` | 2590.368 us | 2615.232 us | 1.010x | -1.0% | 0/11 | 0.36% | 0.29% | 188148 | 188112 |
| `parseStringRecords1m` | 49838.336 us | 50670.208 us | 1.017x | -1.7% | 4/11 | 1.57% | 1.88% | 187256 | 187600 |
| `parseBytesRecords1m` | 50459.712 us | 51408.896 us | 1.019x | -1.9% | 1/11 | 1.63% | 1.62% | 187432 | 187508 |
| `yjsonStringEncodeProfileBundle` | 14.258 us | 13.929 us | 0.977x | 2.3% | 6/11 | 5.36% | 7.78% | 159712 | 163780 |
| `yjsonStringDecodeProfileBundle` | 23.418 us | 23.236 us | 0.992x | 0.8% | 8/11 | 1.49% | 3.11% | 168164 | 172604 |
| `yjsonBytesEncodeProfileBundle` | 13.592 us | 13.537 us | 0.996x | 0.4% | 9/11 | 0.34% | 0.31% | 167364 | 173252 |
| `yjsonBytesDecodeProfileBundle` | 26.892 us | 26.920 us | 1.001x | -0.1% | 5/11 | 1.26% | 1.48% | 163440 | 172060 |
| `yjsonStringEncodeEscapedUnicodeString` | 1.917 us | 2.029 us | 1.058x | -5.8% | 6/11 | 10.79% | 11.40% | 169860 | 166632 |
| `yjsonBytesEncodeEscapedUnicodeString` | 1.788 us | 1.784 us | 0.998x | 0.2% | 6/11 | 0.83% | 0.37% | 160548 | 171096 |
| `decodePersonChunk4k` | 30.208 us | 30.464 us | 1.008x | -0.8% | 3/11 | 0.64% | 0.79% | 189100 | 189140 |
| `decodeRecords64kChunk4k` | 17750.976 us | 17781.504 us | 1.002x | -0.2% | 3/11 | 0.21% | 0.22% | 190296 | 190296 |
| `encodePersonMemory` | 3.840 us | 3.840 us | 1.000x | 0.0% | 4/11 | 20.54% | 17.32% | 189344 | 190180 |
| `encodeRecords64kMemory` | 584.448 us | 585.984 us | 1.003x | -0.3% | 4/11 | 0.70% | 1.82% | 189692 | 189804 |

## 身份与环境

| 项目 | 值 |
| --- | --- |
| Candidate commit/tree | `f4aed80847e77fee12a156e8644f65ab34c64092` / `6ec406c7f6ed04c6314b6165468a1ce0f46eee4f` |
| Baseline commit/tree | `e53b5bbd8587094f5e796971450323e233fb01d0` / `412cc6bd971195b6aa9d4d5c1ebbf2a33ce77595` |
| Candidate product SHA-256 | `1c3d85aca3fec86594d1732bb8779728cd42e7e5b7656b720bd0f934390cb2c9` |
| Baseline product SHA-256 | `9c1e738dcf8e8a56314e433874555ff8830bac9652c57268658050199df0a847` |
| Effective harness SHA-256 | `721fec53e1a190c71e2996396474870f2516add82ca0be4a94ab143465d0ffba` |
| Runner SHA-256 | `77424e07b82aa3399e706808ee8490d02e482c10aab4799b9fc8b6533ea9ce5d` |
| Corpus SHA-256 | `db9b0242e01fb4cfa2468245f8be5329a0967052412b7340f12c468c6202a70f` |
| 两批 CPU | CPU 0，sibling 48；每批独立 30 秒 idle sample 均为 `0.0%` |
| SDK | Cangjie STS `1.1.3`；`cjc`/`cjpm` `1.1.3` |
| C toolchain | Clang 14.0.0；GNU ar 2.38 |
| 仓颉运行时 | `cjHeapSize=128MB`、`cjProcessorNum=1` |
| Baseline binary SHA-256 | `e7e1829e52040b5078568bdea89ea1b8a2e14a1a890aae6427d380db3146c625` |
| Candidate binary SHA-256 | `c9a52f3f60f2ea4eda27647c24a16d55ba83a0ee2a111f396cf1952347d67b0a` |

两批各自重建双方程序，对应侧的产物摘要跨批次相同。构建前后源码干净，产品与 harness 身份未变。
全部构建与计时持有同一排他锁，没有与七库计时并行。

## 证据与复核

原始数据位于 `benchmarks/results/release-performance/2026-09-18-maintainability-f4aed80/`：

| 文件 | SHA-256 |
| --- | --- |
| `pure-fixed-work-cj1-v1-a.tar.gz` | `bdda867494f0462bc36c1c6eb2648f9bb689df050c5a3e0f20c90c7a05f67d57` |
| `pure-fixed-work-cj1-v1-b.tar.gz` | `0b04fcc2df387aba2f887edce91f2ca3a7f6ce2ba98e4ff20561c7860783d0fd` |
| `pure-fixed-work-cj1-v1-metadata.tar.gz` | `3042ab6c60ac5471ab47c1999418f844dd30024400704369d0a578437ef12cb6` |

`checksums.txt` 校验三个归档。两份原始批次各保留 2,647 个文件；metadata 归档保存逐文件
`batch-a.raw-files.sha256`、`batch-b.raw-files.sha256`、`metadata-files.sha256` 和执行退出码。
复核时在对应解压目录执行 `sha256sum -c <校验清单>`。本轮核对 5,321 条逐文件摘要，
并从全部 1,056 个 CSV、日志、固定工作量和 RSS 单元重算统计与门禁，结论仍为两批失败。
归档与原始输出字节一致。报告随 source-only 发布树分发，原始归档只保存在仓库。

## 已封存方案

旧 `c844aa9` 第二批失败、初版固定采样基线 OOM、被中止的七库部分批次和 65,536 上限首次预检 OOM 均不改判。
单并发是随后批准的新协议，不证明 SDK 分配器的准确失败机制已定位或修复。

<details>
<summary>c844aa9 原报告（封存，非当前配置）</summary>

### 2026-09-18 维护性重构候选 Pure A/B：门禁未通过

当前候选 `c844aa9519ec9bd9bffa3e45fceb3d5d45fb974a` 的正式验收尚未通过。首批 24 项均满足 `candidate/baseline <= 1.05`，但有 11 项任一侧 CV 超过 5%，因此按[性能方法](../methodology.md)完整复测一次。第二批有两项超过回退门槛，且仍有 13 项 noisy；保留两批全部样本，停止重试，不使用首批通过覆盖第二批失败。

这是维护性重构候选，不是发布声明。两批均为完整 24 case、11 轮、`128MB` heap、`--gate-mode release --rebuild --enforce`，没有 optimization target。每批包含 528 个独立计时进程，均保留 raw CSV、日志和 GNU `/usr/bin/time -v` RSS sidecar。原始数据位于 `benchmarks/results/release-performance/2026-09-18-maintainability-c844aa9/`，包括 `pure-batch-a-fixed.tar.gz`、`pure-batch-b.tar.gz` 与 `checksums.txt`。这些原始证据保存在仓库，不随 source-only 发布树分发。

### 基线与范围

基线产品来自主仓库 `2303a064ce2244fe08014f2b3fa08fa71931ceb8` 与宏仓库 `5961c2f448f989fb23a9731265ce025aad8bffaf`。隔离基线提交为 `bbf3033b8bf08052c71c1b60a33dcc73d8db0f88`。双方使用相同的 22 项 benchmark 构建输入，包括归一化后的 Native C 布局；宏使用本地实际源码，生产 Git pin 不变。

因此，这是相同 C 构建闭包下 runtime/macro 的 Pure A/B，不是 RF-009 C 抽取的直接 A/B，也不是实际 Native provider 的性能测量。此前 `0.1.0` 发布候选的验收与[历史发布证据](../../../release/0.1.0/evidence.md)属于不同源码身份，不能替代本轮结果；历史原始归档未修改。

### Gate 结论

| 批次 | Cases × 轮次 | 退出码 | 全部 C/B <= 1.05 | Noisy cases | 正式结论 |
| --- | --- | ---: | --- | ---: | --- |
| 第一批 | 24 × 11 | 0 | true | 11/24 | 本批通过；触发一次完整复测 |
| 第二批 | 24 × 11 | 1 | false | 13/24 | 未通过；停止重试 |

第二批的失败项如下。比值是原始统计结果，不是稳定回退幅度的声明；CV 超限不能用于删除这些失败行。

| Case | C/B | Baseline CV | Candidate CV |
| --- | ---: | ---: | ---: |
| `yjsonBytesDecodeProfileBundle` | 1.052521 | 5.914% | 3.789% |
| `encodePersonMemory` | 1.050870 | 20.611% | 5.676% |

两项所有进程日志均为 `PASSED: 1`、`ERROR: 0`、`FAILED: 0`，失败来自比例门禁，不是测试或进程错误。两批对应的 baseline/candidate 二进制摘要各自相同，构建前后源码干净且身份不变。当前证据不足以确定稳定的代码回退根因；不改门槛、不挑行、不把诊断统计换成正式 gate。

### Deep Nested

三个 Deep Nested case 在两批中均满足 `C/B <= 1.05`。下表保留每侧 CV；noisy 行不作为稳定精确比例。

| Case | 第一批 C/B | 第一批 baseline/candidate CV | 第二批 C/B | 第二批 baseline/candidate CV |
| --- | ---: | --- | ---: | --- |
| `yjsonStringEncodeDeepNestedProfiles` | 0.991422 | 0.518% / 1.119% | 1.001916 | 1.461% / 1.273% |
| `yjsonStringDecodeDeepNestedProfiles` | 1.001976 | 3.997% / 8.092% | 1.004256 | 3.343% / 4.380% |
| `yjsonBytesDecodeDeepNestedProfiles` | 1.007614 | 2.336% / 2.904% | 0.992752 | 7.028% / 3.676% |

### 第一批完整结果

时延单元格包含单位；`C/B` 越小越好。RSS 单位为 kbytes，每列为该 case 的 11 个 sidecar 的最大值。

| Case | Baseline median | Candidate median | C/B | Improvement | Wins | Baseline CV | Candidate CV | Baseline max RSS KB | Candidate max RSS KB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `yjsonStringEncodeLargeInt64Map` | 5.260 us | 5.359 us | 1.019x | -1.9% | 5/11 | 1.62% | 1.58% | 191428 | 191304 |
| `yjsonStringDecodeLargeInt64Map` | 26.235 us | 26.159 us | 0.997x | 0.3% | 6/11 | 1.21% | 3.54% | 190024 | 190872 |
| `yjsonBytesDecodeLargeInt64Map` | 26.478 us | 26.171 us | 0.988x | 1.2% | 8/11 | 7.49% | 1.40% | 190868 | 190824 |
| `yjsonStringEncodeDeepNestedProfiles` | 41.960 us | 41.600 us | 0.991x | 0.9% | 9/11 | 0.52% | 1.12% | 191576 | 190952 |
| `yjsonStringDecodeDeepNestedProfiles` | 302.251 us | 302.848 us | 1.002x | -0.2% | 7/11 | 4.00% | 8.09% | 189844 | 190176 |
| `yjsonBytesDecodeDeepNestedProfiles` | 306.496 us | 308.830 us | 1.008x | -0.8% | 4/11 | 2.34% | 2.90% | 190776 | 190172 |
| `yjsonStringEncodePerson` | 1.549 us | 1.542 us | 0.995x | 0.5% | 4/11 | 3.54% | 1.93% | 189936 | 190252 |
| `yjsonStringDecodePerson` | 7.424 us | 7.024 us | 0.946x | 5.4% | 7/11 | 3.79% | 6.45% | 190860 | 190308 |
| `yjsonStringEncodeLargeProfileArray` | 26.564 us | 25.249 us | 0.950x | 5.0% | 11/11 | 1.48% | 1.13% | 190864 | 190796 |
| `yjsonStringDecodeLargeProfileArray` | 73.130 us | 73.702 us | 1.008x | -0.8% | 2/11 | 0.72% | 0.62% | 191252 | 190836 |
| `parseStringRecords64k` | 2222.088 us | 2134.168 us | 0.960x | 4.0% | 6/11 | 5.28% | 5.90% | 187960 | 190480 |
| `parseBytesRecords64k` | 2209.713 us | 2267.894 us | 1.026x | -2.6% | 3/11 | 5.72% | 5.63% | 188400 | 188424 |
| `parseStringRecords1m` | 30132.992 us | 30739.200 us | 1.020x | -2.0% | 6/11 | 14.89% | 9.02% | 187308 | 187836 |
| `parseBytesRecords1m` | 29299.552 us | 29687.808 us | 1.013x | -1.3% | 7/11 | 5.94% | 8.03% | 187364 | 187312 |
| `yjsonStringEncodeProfileBundle` | 6.949 us | 6.994 us | 1.006x | -0.6% | 5/11 | 0.67% | 1.98% | 191412 | 191208 |
| `yjsonStringDecodeProfileBundle` | 15.647 us | 15.430 us | 0.986x | 1.4% | 9/11 | 2.14% | 1.53% | 191108 | 190144 |
| `yjsonBytesEncodeProfileBundle` | 9.003 us | 9.079 us | 1.008x | -0.8% | 5/11 | 2.00% | 2.24% | 190900 | 190428 |
| `yjsonBytesDecodeProfileBundle` | 18.038 us | 17.895 us | 0.992x | 0.8% | 6/11 | 4.05% | 2.94% | 190600 | 190608 |
| `yjsonStringEncodeEscapedUnicodeString` | 1.447 us | 1.396 us | 0.965x | 3.5% | 7/11 | 4.12% | 7.80% | 191828 | 191104 |
| `yjsonBytesEncodeEscapedUnicodeString` | 1.348 us | 1.316 us | 0.976x | 2.4% | 8/11 | 9.20% | 1.63% | 190404 | 190768 |
| `decodePersonChunk4k` | 64.358 us | 63.354 us | 0.984x | 1.6% | 8/11 | 1.45% | 7.80% | 190256 | 190256 |
| `decodeRecords64kChunk4k` | 11421.764 us | 11392.930 us | 0.997x | 0.3% | 7/11 | 0.92% | 0.88% | 137464 | 141332 |
| `encodePersonMemory` | 9.323 us | 9.515 us | 1.021x | -2.1% | 3/11 | 20.06% | 12.88% | 190928 | 190792 |
| `encodeRecords64kMemory` | 1307.706 us | 1294.521 us | 0.990x | 1.0% | 8/11 | 3.45% | 3.39% | 187216 | 187064 |

### 第二批完整结果

口径与首批相同。两批分别列出，不拼接样本。

| Case | Baseline median | Candidate median | C/B | Improvement | Wins | Baseline CV | Candidate CV | Baseline max RSS KB | Candidate max RSS KB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `yjsonStringEncodeLargeInt64Map` | 5.200 us | 5.326 us | 1.024x | -2.4% | 1/11 | 1.79% | 1.56% | 190996 | 191184 |
| `yjsonStringDecodeLargeInt64Map` | 25.496 us | 26.184 us | 1.027x | -2.7% | 2/11 | 3.51% | 2.35% | 190808 | 191408 |
| `yjsonBytesDecodeLargeInt64Map` | 27.101 us | 27.159 us | 1.002x | -0.2% | 6/11 | 7.04% | 5.79% | 190988 | 190648 |
| `yjsonStringEncodeDeepNestedProfiles` | 41.757 us | 41.837 us | 1.002x | -0.2% | 6/11 | 1.46% | 1.27% | 191040 | 191124 |
| `yjsonStringDecodeDeepNestedProfiles` | 300.777 us | 302.057 us | 1.004x | -0.4% | 7/11 | 3.34% | 4.38% | 191040 | 189840 |
| `yjsonBytesDecodeDeepNestedProfiles` | 304.698 us | 302.490 us | 0.993x | 0.7% | 6/11 | 7.03% | 3.68% | 191148 | 190852 |
| `yjsonStringEncodePerson` | 1.547 us | 1.532 us | 0.991x | 0.9% | 6/11 | 3.93% | 3.18% | 191020 | 190868 |
| `yjsonStringDecodePerson` | 7.202 us | 7.526 us | 1.045x | -4.5% | 2/11 | 8.00% | 3.23% | 191132 | 190620 |
| `yjsonStringEncodeLargeProfileArray` | 26.879 us | 25.600 us | 0.952x | 4.8% | 11/11 | 1.44% | 1.46% | 190580 | 190604 |
| `yjsonStringDecodeLargeProfileArray` | 72.960 us | 74.290 us | 1.018x | -1.8% | 0/11 | 0.30% | 1.60% | 190952 | 190796 |
| `parseStringRecords64k` | 2200.318 us | 2234.016 us | 1.015x | -1.5% | 5/11 | 6.88% | 5.39% | 190188 | 187916 |
| `parseBytesRecords64k` | 2308.191 us | 2241.973 us | 0.971x | 2.9% | 5/11 | 4.14% | 4.05% | 188268 | 188316 |
| `parseStringRecords1m` | 30432.000 us | 29482.304 us | 0.969x | 3.1% | 6/11 | 14.61% | 9.72% | 187476 | 187788 |
| `parseBytesRecords1m` | 30249.669 us | 29208.320 us | 0.966x | 3.4% | 7/11 | 10.89% | 8.67% | 187448 | 187428 |
| `yjsonStringEncodeProfileBundle` | 6.967 us | 6.933 us | 0.995x | 0.5% | 5/11 | 0.67% | 0.87% | 190512 | 190516 |
| `yjsonStringDecodeProfileBundle` | 15.479 us | 15.460 us | 0.999x | 0.1% | 6/11 | 3.15% | 16.93% | 190416 | 191204 |
| `yjsonBytesEncodeProfileBundle` | 9.037 us | 9.117 us | 1.009x | -0.9% | 4/11 | 3.63% | 1.27% | 190748 | 190520 |
| `yjsonBytesDecodeProfileBundle` | 17.147 us | 18.048 us | 1.053x | -5.3% | 3/11 | 5.91% | 3.79% | 190312 | 190496 |
| `yjsonStringEncodeEscapedUnicodeString` | 1.454 us | 1.446 us | 0.994x | 0.6% | 6/11 | 7.88% | 2.15% | 191476 | 191232 |
| `yjsonBytesEncodeEscapedUnicodeString` | 1.406 us | 1.317 us | 0.937x | 6.3% | 9/11 | 7.55% | 5.12% | 190336 | 191000 |
| `decodePersonChunk4k` | 63.253 us | 62.587 us | 0.989x | 1.1% | 7/11 | 4.31% | 6.32% | 190328 | 190552 |
| `decodeRecords64kChunk4k` | 11422.993 us | 11401.873 us | 0.998x | 0.2% | 5/11 | 1.19% | 16.52% | 135764 | 189596 |
| `encodePersonMemory` | 9.467 us | 9.948 us | 1.051x | -5.1% | 4/11 | 20.61% | 5.68% | 190948 | 190648 |
| `encodeRecords64kMemory` | 1289.181 us | 1296.057 us | 1.005x | -0.5% | 4/11 | 2.18% | 2.29% | 187120 | 186688 |

### 身份与环境

| 项目 | 值 |
| --- | --- |
| Candidate commit/tree | `c844aa9519ec9bd9bffa3e45fceb3d5d45fb974a` / `76432c607bd5be972c1008d3a98905f35aa8f423` |
| Baseline commit/tree | `bbf3033b8bf08052c71c1b60a33dcc73d8db0f88` / `b8c16a42f0ef07745a1645518124414affb50c1f` |
| Candidate product SHA-256 | `1c3d85aca3fec86594d1732bb8779728cd42e7e5b7656b720bd0f934390cb2c9` |
| Baseline product SHA-256 | `9c1e738dcf8e8a56314e433874555ff8830bac9652c57268658050199df0a847` |
| Effective harness SHA-256 | `8c8e193c4f676484f020a0fcc997204a89993df90aa5cddb3005d2dd095ca251` |
| Runner SHA-256 | `57fcc05affbb415b9515101263bdb52456e9ba5addde0de100c39ddacfd5ca22` |
| Corpus SHA-256 | `db9b0242e01fb4cfa2468245f8be5329a0967052412b7340f12c468c6202a70f` |
| CPU 第一批 | CPU 0，sibling 48；30 秒 idle sample 均 `0.0%` |
| CPU 第二批 | CPU 10，sibling 58；30 秒 idle sample 均 `0.0%` |
| SDK | Cangjie STS `1.1.3`；`cjc`/`cjpm` `1.1.3` |
| C toolchain | Clang 14.0.0；GNU ar 2.38 |
| Heap | `128MB` |
| RSS | GNU `/usr/bin/time -v`；`kbytes` |

首批 sibling 48 的监测最大占用为 `0.99%`，第二批 sibling 58 为 `0.0%`。两批使用各自新选出的空闲物理核；不能把跨批次差异直接归因于源码。全部正式构建与计时持有同一排他锁，没有与七库计时并行。

### 复核

先核对归档外 `checksums.txt`，再在各解压批次目录执行 `sha256sum -c checksums.txt`。归档内保留 `provenance.json`、CPU 采样与逐秒监测、源码及工具链身份、每轮 CSV/日志/RSS、执行退出码和 summary。按 `scripts/json_pure_perf_compare.py` 的同一逻辑重算仍得到首批通过、第二批失败；跨 Python 版本的派生浮点差异使用仓库既有 `check_json_numeric_equivalence.py` 规则，原始样本、正式门槛与文档数值均未修改。

</details>
