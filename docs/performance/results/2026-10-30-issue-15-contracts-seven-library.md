# 2026-10-30 Issue #15 修复候选七库测量

生产源码 `0d4d39a3e92ccaf4d3d0a37367160973dad21dbd`、宏 `2bfd34c08c421c04a0cd8e3d1326140849f1f21b` 完成两批测量。
每批 `10 workloads × 7 libraries × 11 rounds = 770` 个单元，两批共 1540 个。
两批均有 7/10 workload 满足七库全部 `CV <= 5%`；yjson 的十项在两批中均稳定。
所有噪声行保留，没有第三批、单元重试或跨批拼接。

完整记录见[证据索引](../../../benchmarks/results/full-seven-library/2026-10-30-issue-15-contracts/README.md)，
回退门禁及修复前 HEAD 对照见 [Pure 报告](2026-10-30-issue-15-contracts-pure.md)。
两批测量发生于 2026-10-30 UTC。本结果不表示候选已经发布。

## 测量条件

- Linux x86_64，Intel Xeon Gold 6248R；Cangjie STS `1.2.0` 与匹配 stdx。
- 仓颉测量构建实际使用 `-O2`，保留 CHIR 函数内联；JDK `17.0.20.1`、JMH `1.37`、Jackson `2.18.2`、fastjson2 `2.0.52`。
- `cjHeapSize=128MB`、`cjProcessorNum=1`，七库单 CPU 绑定。两批分别使用 CPU 1 / sibling 49、CPU 3 / sibling 51。
  各批重新采集 30 秒空闲窗口，所选线程利用率均为 0.0%。
- 每批独立执行全部七库 fixture 预检，然后轮换 workload 与库顺序；逐轮保留日志、RSS sidecar 和原始报告。
- yjson 使用原有 fixed-work protocol v1，工作量跨轮、跨批一致；其他库保留既有采样参数，不标作固定工作量。

## 构建与源码身份

yjson 与 stdx.json 共用从真实生产 Git pin 新构建的程序。实际 execve 日志及 argv 回执记录
四次测量运行时或 benchmark 编译，均为 `-O2`，没有禁用 CHIR 函数内联。

三个独立仓颉对照程序和 JMH JAR 复用既有产物，**不是本轮重新构建**。
复用前核对六棵对照源码树、四个产物、原始实际 O2 argv、fixture overlay 和 SDK。
两批计时前后再次核验全部七棵源码树、SDK 清单、overlay 和产物摘要一致。
复用符合[性能方法](../methodology.md)的对照产物规则，不把旧生产 yjson 程序作为新候选。

七库准备首次因任务校验脚本误用 SDK 摘要序列化格式而停止，没有开始构建或测量。
按原构建审计的 JSON 格式重新计算后，1179 项 SDK 清单与原摘要完全一致。
失败脚本、失败记录、完成后的构建日志和回执都保留；没有更换 SDK 或放宽断言。

下表为 11 轮中位数，单位 **微秒/操作**；`Max CV` 是七库最大样本 CV。
噪声行只是原始统计，不用于精确比例声明。SDKBench、JMH 与 Pure 直接计时不拼接样本。

## 第一批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 0.385 | 1.043 | 0.905 | 1.001 | 0.908 | 0.176 | 0.066 | 3.13% |
| Address decode | 0.250 | 1.814 | 0.563 | 1.793 | 0.693 | 0.327 | 0.071 | 4.10% |
| Person encode | 1.109 | 3.997 | 5.638 | 2.234 | 3.749 | 0.565 | 0.271 | 1.36% |
| Person decode | 1.664 | 7.172 | 4.948 | 6.203 | 4.731 | 1.134 | 0.419 | 2.56% |
| Large Array encode | 18.818 | 37.353 | 80.557 | 37.739 | 34.657 | 8.986 | 4.147 | 1.22% |
| Large Array decode | 36.064 | 65.138 | 43.310 | 64.637 | 43.631 | 18.814 | 5.068 | 5.21% |
| Large Map encode | 3.874 | 25.820 | 46.878 | 29.386 | 27.827 | 1.773 | 1.742 | 6.52% |
| Large Map decode | 11.808 | 53.725 | 58.712 | 50.282 | 49.725 | 5.414 | 3.963 | 1.26% |
| Deep Nested encode | 20.804 | 29.314 | 51.262 | 29.093 | 26.060 | 4.525 | 2.451 | 16.93% |
| Deep Nested decode | 46.177 | 48.988 | 36.486 | 44.265 | 33.063 | 10.362 | 3.449 | 1.50% |

噪声单元：Large Array decode / jackson：5.21%；Large Map encode / fastjson2：6.52%；Deep Nested encode / jackson：16.93%。

## 第二批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 0.386 | 1.039 | 0.901 | 0.999 | 0.902 | 0.174 | 0.066 | 4.43% |
| Address decode | 0.250 | 1.845 | 0.562 | 1.819 | 0.691 | 0.326 | 0.073 | 3.87% |
| Person encode | 1.109 | 3.992 | 5.667 | 2.229 | 3.739 | 0.568 | 0.271 | 2.12% |
| Person decode | 1.664 | 7.151 | 4.934 | 6.198 | 4.707 | 1.128 | 0.420 | 0.78% |
| Large Array encode | 18.810 | 37.362 | 80.475 | 37.687 | 34.618 | 9.015 | 4.157 | 2.30% |
| Large Array decode | 36.069 | 65.053 | 43.253 | 64.591 | 43.916 | 18.937 | 5.096 | 5.11% |
| Large Map encode | 3.871 | 25.792 | 46.787 | 29.468 | 27.900 | 1.738 | 1.742 | 7.52% |
| Large Map decode | 11.806 | 53.696 | 58.696 | 50.575 | 49.653 | 5.421 | 3.932 | 1.75% |
| Deep Nested encode | 20.833 | 29.326 | 51.278 | 29.049 | 25.997 | 4.468 | 2.468 | 2.06% |
| Deep Nested decode | 46.041 | 49.034 | 36.517 | 44.361 | 32.845 | 10.399 | 3.451 | 6.95% |

噪声单元：Large Array decode / jackson：5.11%；Large Map encode / fastjson2：7.52%；Deep Nested decode / fastjson2：6.95%。根 README 只引用本批七库均稳定的七行。

## 输入身份与复核

| 输入 | 身份 |
| --- | --- |
| 生产提交 | `0d4d39a3e92ccaf4d3d0a37367160973dad21dbd` |
| 宏提交 | `2bfd34c08c421c04a0cd8e3d1326140849f1f21b` |
| 产品源码 SHA-256 | `e53700605a8d479abd69b504a138278dc0f9e7be1df6bcd5a8332d0e6e7e5368` |
| 生产 harness SHA-256 | `3f1c2c1de5ae803f99e344a9a283057674ff2de72154cb66389b5b6d833dc8c5` |
| 九包版本与依赖身份 SHA-256 | `cd053e16597cd7e0be084a03999b6ddd6d4641bed7bd7e5b00906c310e3fa4d7` |
| 对照适配 SHA-256 | `5f09b209c66d504a2533b261a922e63cc8312ea549aa88619d9c4160c058f4fc` |
| SDK 清单 SHA-256 | `ea7984dc5c37c02acf7f7119c24d7633a3b655f0c71350a8aa910c87abe00b5a` |
| 生产测量程序 SHA-256 | `ca360d9eb099615a7f53ab5532cf58ad4201833aafa6716aa23be2b0e2168f51` |
| 第一批归档 SHA-256 | `acd63e4573f9ae9446cd9f1f7cc57d9060bd945f2e395d85b30d83b4e382099f` |
| 第二批归档 SHA-256 | `6446fffe5b6eced27fa0288c2e847ed8733bb793e2168e9801463227ff9545b0` |

两批归档各含 3000 个普通文件，包括完整结果与任务控制记录。下载后逐成员核对摘要。
公开 harness 含 843 个源码或回执文件，与冻结的产品、harness 及各对照源码摘要一致，
不含 Git 历史或可执行产物。json4cj 保留实际公开源码、三份 O2 清单适配及许可来源证明，
不补写上游不存在的 LICENSE。

本地复核使用可信检出中的汇总器重算两批原始报告，核验 770 单元矩阵、case 绑定、
固定工作量、RSS、跨批身份及文档行。复核不执行归档中的 Python。
最终干净检出门禁和全部修复验收状态见[实施记录](../../implementation/issue-15.md)。

## 范围与历史

[上一轮 API 注释候选](2026-10-30-api-contracts-seven-library.md)按原提交保留。
本轮只证明所列源码、SDK、API 和单并发配置，不证明 Native、默认并发配置、其他平台或跨 SDK 性能。
宏提交尚未发布；本轮生产依赖检查通过进程级 Git URL 路由读取该精确本地提交，不表示它已可从远端下载。
