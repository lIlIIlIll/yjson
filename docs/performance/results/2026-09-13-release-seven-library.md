# 2026-09-21 0.1.1 发布候选七库完整对比

本页是 [`current-main.json`](../../../benchmarks/results/full-seven-library/current-main.json) 指向的当前报告。
测量提交 `ce39e57ba6ade281d232bc0d82abfafdf91f5bb5`，对应主仓库源码候选 `fd2a8f7b400c4c80d6aaaf1e71fdd1ac5ff422ab`。
使用 SDKBench `YJSON_FIXED_WORK_V1`；两批各 10 workloads × 7 libraries × 11 rounds，共 1,540 个测量单元。
完整原始报告、RSS、源码和摘要见[证据目录](../../../benchmarks/results/full-seven-library/2026-09-21-release-011/README.md)。

**七库完整性 PASS；同一候选的 [Pure direct A/B](2026-09-13-linux-release-pure.md) 回退门禁 PASS。**
七库第一批仅 1/10 行 stable，第二批 0/10 行 stable，不据此声明稳定的跨库精确比例。
结果限于单核、`cjProcessorNum=1`、128 MiB 堆；不代表默认运行时并发配置。
Pure 使用独立的 `YJSON_PURE_DIRECT_V1`，不得与本矩阵拼接样本或比较绝对延迟。

## 测量范围

Encode 从已构造 typed value 生成紧凑 JSON；Decode 从 canonical JSON 恢复同一 typed 类型。
各 adapter 在计时前通过公开 API correctness preflight；存在 direct typed path 时不使用 DOM fallback。

| Workload | Typed value 的形状 | 规模 | Payload bytes |
| --- | --- | ---: | ---: |
| Address | `Address{street_name: String, zipcode: Int64}` | 2 个字段 | 47 |
| Person | 3 个字符串 tag、2 个整数 score、嵌套 Address 和 null nick | 7 个 JSON 字段 | 176 |
| Large Array | `ArrayList<ProfileRecord>` | 64 条记录 | 3929 |
| Large Map | `HashMap<String, Int64>` | 64 个 entry | 1013 |
| Deep Nested | `ArrayList<HashMap<String, ArrayList<ProfileRecord>>>` | 8 组 × 4 条记录 | 1929 |

## 结果状态

每批 770 个唯一成功单元、7 个 preflight 日志、110 份 yjson 固定工作量证明和 770 份正值 RSS sidecar。
220 份固定工作量证明均重新解析，两批工作量一致；每个进程只测一个 exact case，报告与 RSS 逐项绑定 manifest。
构建不计入 timing 或 RSS。全部 noisy 行保留，不删样本，不运行第三批。

单位为 µs/op，是 11 轮独立进程样本的中位数；`Max CV` 为七个库中的最大 CV。
仅 `Max CV <= 5%` 的行称为 stable。两批分别为 1/10 和 0/10 stable。

## 第一批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 1.448 | 2.957 | 2.829 | 3.213 | 2.937 | 0.175 | 0.065 | 11.23% |
| Address decode | 1.830 | 2.205 | 3.086 | 3.387 | 2.020 | 0.306 | 0.067 | 6.81% |
| Person encode | 3.751 | 12.109 | 15.709 | 5.120 | 9.915 | 0.579 | 0.267 | 8.51% |
| Person decode | 10.854 | 19.139 | 23.373 | 19.697 | 14.171 | 1.154 | 0.427 | 7.81% |
| Large Array encode | 56.174 | 79.910 | 250.720 | 91.869 | 71.412 | 8.898 | 3.756 | 10.23% |
| Large Array decode | 153.575 | 174.399 | 335.038 | 174.816 | 75.467 | 18.805 | 5.037 | 12.27% |
| Large Map encode | 11.717 | 117.275 | 157.759 | 122.043 | 115.160 | 1.802 | 1.742 | 12.61% |
| Large Map decode | 46.073 | 264.497 | 291.956 | 205.520 | 207.573 | 5.255 | 4.003 | 14.53% |
| Deep Nested encode | 80.243 | 73.669 | 171.334 | 77.779 | 66.503 | 4.513 | 2.544 | 4.62% |
| Deep Nested decode | 389.568 | 163.329 | 211.477 | 141.747 | 88.105 | 10.427 | 3.431 | 9.57% |

## 第二批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 1.454 | 3.052 | 2.825 | 3.404 | 2.969 | 0.170 | 0.066 | 7.57% |
| Address decode | 1.834 | 2.209 | 3.072 | 3.378 | 2.024 | 0.308 | 0.067 | 8.14% |
| Person encode | 3.706 | 10.402 | 15.821 | 5.059 | 9.923 | 0.583 | 0.267 | 9.18% |
| Person decode | 10.891 | 19.277 | 25.222 | 19.740 | 14.480 | 1.142 | 0.429 | 7.93% |
| Large Array encode | 56.713 | 81.579 | 250.624 | 92.079 | 74.368 | 8.965 | 3.797 | 13.48% |
| Large Array decode | 153.238 | 175.910 | 329.470 | 172.288 | 73.224 | 18.622 | 5.065 | 11.03% |
| Large Map encode | 11.722 | 112.704 | 157.626 | 121.186 | 123.243 | 1.808 | 1.756 | 11.33% |
| Large Map decode | 46.442 | 265.702 | 293.376 | 205.135 | 202.054 | 5.245 | 3.901 | 9.95% |
| Deep Nested encode | 80.606 | 73.664 | 171.584 | 77.499 | 67.261 | 4.555 | 2.479 | 6.13% |
| Deep Nested decode | 392.846 | 153.437 | 210.731 | 140.404 | 88.365 | 10.351 | 3.388 | 12.41% |

## 输入和运行环境

| 项目 | 值 |
| --- | --- |
| Measured commit | `ce39e57ba6ade281d232bc0d82abfafdf91f5bb5` |
| Measured tree | `4826abc45cac6fdff757ce6ee36dd50219b2eded` |
| Product source SHA-256 | `9e22b132f38b28f15ef698a373247ac91ad4bdbe922bd8fae42c1b09cdcf30cf` |
| Effective harness SHA-256 | `4d34fcb5e5a160e46c293efd996ac9fc416aa2858d316d163e1cf7c22bba1cc3` |
| Candidate identity SHA-256 | `e809af61d164287dbf18f320977334c52d2140ebb3358fe6834f2e34e1147549` |
| SDK | Cangjie STS `1.1.3` |
| CPU | CPU 3，sibling 51；30 秒 idle sample 均为 `0.0%` |
| 仓颉运行时 | `cjHeapSize=128MB`、`cjProcessorNum=1` |
| Hostname | 独立 UTS namespace 中的 `example-host` |
| GNU time | `/usr/bin/time`；RSS 单位 `kbytes` |

库和 workload 顺序逐轮旋转，偶数轮反转 workload 顺序。
yjson 使用冻结固定工作量，其他库保留原采样参数；所有仓颉库统一限制运行时并发。
Java 每个外层轮次为一个 fork、3 × 500 ms warmup 和 1 × 1 秒测量。
规则见[性能方法](../methodology.md)。

yjson 与 stdx.json 共用本轮一次 clean compile-only 构建的候选程序；其余五库逐字节复用摘要固定的二进制。
候选源码胶囊含 179 个文件，覆盖全部 51 个产品输入和 28 个 harness 输入；peer 胶囊含 278 个文件。
隔离测量提交与主仓库候选的产品、有效 harness、版本及依赖绑定一致，不要求 Git tree 相同。

## 资格边界与复核

本矩阵不证明 Native provider 性能，也不替代正确性、覆盖率、平台或发布门禁。
Deep Nested 的回退判定来自同轮完整 Pure A/B，不跨历史批次推导。
在含全部归档的干净候选中执行：

```sh
PYTHONDONTWRITEBYTECODE=1 bash scripts/ci_job.sh perf-evidence-drift strict
```

门禁校验归档、1,540 单元、RSS、固定工作量、summary 重生成、文档表格与当前产品/harness/发布绑定。
不得使用 `integrity-only` 放行。

## 包装与历史边界

临时打包器首次直接比较了 `cjpm` 启动诊断中的时间戳和线程 ID，错误拒绝了两批相同的 SDK 版本。
修正为调用仓库既有的 `stable_identity` 后重新打包；原始诊断、版本输出、样本和阈值没有改写，也没有重跑测量。
同时删除了临时模板对旧包装记录的无效引用。`path-normalization.json` 记录该包装修正，以及 1,985 个规范化文件的原始/公开摘要。
日志仅替换测量工作目录前缀，源码胶囊字节不变；规范化后的两批再次完整解析通过。

[上一轮七库证据](../../../benchmarks/results/full-seven-library/2026-09-20-maintainability-c5ccfd6/README.md)及 Pure 历史失败记录保留，不进入本轮统计。
