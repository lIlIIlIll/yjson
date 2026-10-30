# 2026-10-30 API 注释候选七库测量

生产源码 `ac4f8b987910a473ada7d77f10ce6cd3c12d2248`、宏 `d819745310f8cc6aa416e1298f706ea5138b7d16` 完成两批测量。
每批独立重建四个仓颉程序和 Maven 程序，执行 `10 workloads × 7 libraries × 11 rounds = 770`
个单元，两批共 1540 个。第一批 9/10、第二批 7/10 workload 满足七库全部 `CV <= 5%`；
噪声行全部保留。yjson 的十项在两批中均满足该标准。

原始记录、源码和构建回执见[证据索引](../../../benchmarks/results/full-seven-library/2026-10-30-api-contracts/README.md)，
同 SDK 的回退结果见[Pure 报告](2026-10-30-api-contracts-pure.md)。测量发生于 2026-10-29 UTC。
本页不表示 yjson 已发布；干净检出 `d8859ee` 的完整 strict 检查与 40 项回归已通过。

## 测量条件

- Linux x86_64；Cangjie STS `1.2.0`、匹配的 stdx；仓颉测量构建使用 `-O2`，保留 CHIR 函数内联。
- JDK `17.0.20.1`、JMH `1.37`、Jackson `2.18.2`、fastjson2 `2.0.52`。
- 堆为 `128MB`、`cjProcessorNum=1`；七库单核绑定。每批重新采集 30 秒空闲窗口。
  第一批 CPU 4 / sibling 52，第二批 CPU 3 / sibling 51，相关线程均为 0.0%。
- workload 和库顺序轮换；每个外层轮次保留完整日志、RSS sidecar 和原始报告。
- 每批先执行 fixture 预检。yjson 使用相同 fixed-work protocol v1，十项工作量跨轮、跨批相同。
- 重新构建后及计时前后核验 SDK、生产源码、锁定依赖、测量适配和实际产物；不改工作量和阈值。

下表为 11 轮中位数，单位 **微秒/操作**；`Max CV` 为该行七库最大的样本 CV。
SDKBench、JMH 与 Pure 直接计时属于不同协议，不拼接样本。方法见[性能方法](../methodology.md)。

## 第一批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 0.391 | 1.040 | 0.900 | 0.999 | 0.901 | 0.181 | 0.066 | 2.95% |
| Address decode | 0.249 | 1.852 | 0.562 | 1.816 | 0.690 | 0.320 | 0.073 | 3.08% |
| Person encode | 1.062 | 4.051 | 5.684 | 2.228 | 3.745 | 0.563 | 0.270 | 1.70% |
| Person decode | 1.520 | 7.117 | 4.931 | 6.201 | 4.714 | 1.131 | 0.420 | 0.94% |
| Large Array encode | 18.587 | 38.060 | 80.456 | 37.657 | 34.570 | 9.096 | 4.156 | 3.18% |
| Large Array decode | 37.401 | 64.403 | 43.261 | 64.644 | 43.635 | 18.942 | 5.152 | 6.61% |
| Large Map encode | 3.738 | 25.676 | 46.724 | 29.536 | 27.784 | 1.717 | 1.730 | 1.89% |
| Large Map decode | 11.868 | 53.538 | 58.458 | 50.256 | 49.908 | 5.424 | 3.958 | 1.78% |
| Deep Nested encode | 20.697 | 29.907 | 51.368 | 29.038 | 26.063 | 4.576 | 2.453 | 2.45% |
| Deep Nested decode | 46.894 | 48.750 | 36.511 | 44.608 | 32.924 | 10.358 | 3.433 | 1.74% |

噪声单元：Large Array decode / jackson：6.61%。该 workload 保留原值。

## 第二批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 0.404 | 1.043 | 0.902 | 0.999 | 0.906 | 0.181 | 0.066 | 7.17% |
| Address decode | 0.249 | 1.868 | 0.562 | 1.783 | 0.691 | 0.323 | 0.071 | 3.27% |
| Person encode | 1.070 | 4.057 | 5.675 | 2.228 | 3.733 | 0.568 | 0.268 | 1.39% |
| Person decode | 1.536 | 7.115 | 4.929 | 6.195 | 4.695 | 1.129 | 0.419 | 1.27% |
| Large Array encode | 18.582 | 37.966 | 80.448 | 37.735 | 34.564 | 9.125 | 4.140 | 1.29% |
| Large Array decode | 37.416 | 64.376 | 43.277 | 64.556 | 43.651 | 18.938 | 5.107 | 5.02% |
| Large Map encode | 3.735 | 25.601 | 46.821 | 29.383 | 27.928 | 1.722 | 1.733 | 6.51% |
| Large Map decode | 11.876 | 53.624 | 58.784 | 50.266 | 49.766 | 5.393 | 3.991 | 1.77% |
| Deep Nested encode | 20.732 | 29.896 | 51.346 | 28.971 | 26.081 | 4.572 | 2.493 | 1.86% |
| Deep Nested decode | 46.830 | 48.643 | 36.399 | 44.246 | 32.868 | 10.362 | 3.424 | 1.22% |

噪声单元：Address encode / stdx_json：7.17%；Large Array decode / jackson：5.02%；Large Map encode / fastjson2：6.51%。README 简表只采用本批七库均稳定的七行。
没有第三批、单元重试或跨批拼接。

## 输入身份与复核

| 输入 | 身份 |
| --- | --- |
| 生产提交 | `ac4f8b987910a473ada7d77f10ce6cd3c12d2248` |
| 宏仓提交 | `d819745310f8cc6aa416e1298f706ea5138b7d16` |
| 产品源码 SHA-256 | `4251be5ff98c50a91afdd162ae130d94f8bf2a70c85faf5da6a78304232771af` |
| 有效 harness SHA-256 | `9d457f09101cb4466a82b000d2494e9c12b2f495b5b16b4fef809811a60d8852` |
| 九包版本与依赖身份 SHA-256 | `20ba99ff997c35bc277601c6fd8a4f76fb84ad460925b6c21e4a08f6facdfa22` |
| 对比库适配 SHA-256 | `5f09b209c66d504a2533b261a922e63cc8312ea549aa88619d9c4160c058f4fc` |
| 第一批原归档 SHA-256 | `2a335821d005a20a23e598012b342c48eb8fe2b882e861a0b7dc67da5db046fc` |
| 第二批原归档 SHA-256 | `c73e455b2f80ac3442fdedb925f13664df81664db75c98787db07cdcc75b6fec` |

两批原始归档各含 3016 个文件，下载后逐成员核验摘要。公开层保留两批原包；补全的 harness
从测量前冻结并验证未变的 502 文件导出增加 315 个文件，187 个重叠文件逐字节相同。
完整产品和 harness 清单均与测量前身份一致。补全不改变实际源码摘要或测量数值。

json4cj 保留实际源码与三份 O2 清单适配，以及对应公开 a185 源的 README 许可声明和
逐文件来源证明；该树没有独立的完整 LICENSE 文件，不补写许可文本。Java 外部依赖由固定
POM、构建日志和产物摘要绑定，不计入本地源码摘要。

## 历史记录与范围

[上一轮报告](2026-10-26-cjdoc-020-seven-library.md)及其失败、噪声和 strict 结果按原身份保留。
本轮只证明上述源码、SDK、API 和运行时配置，不证明 Native、默认并发配置或跨 SDK 性能。
归档打包时曾因发现产物二进制而停止；改为只选择日志和回执后重新打包，测量未重跑。

独立离线复核见[复核记录](../../../benchmarks/results/full-seven-library/2026-10-30-api-contracts/independent-validation.md)。
七库实际优化另由原始 execve 日志重放核验；Pure 优化核验使用已散列的实际 argv 回执，
本次归档未包含其原始 execve 日志。两者的证据深度按原样记录。
