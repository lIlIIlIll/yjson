# 2026-09-20 维护性候选七库完整对比

本页记录 [`current-main.json`](../../../benchmarks/results/full-seven-library/current-main.json) 指向的当前七库报告。
测量绑定 `7d086a69200cecb447c64e73fa2b5e61e584ddb7`，七库协议为 SDKBench `YJSON_FIXED_WORK_V1`。
两批各完成 10 个 workload × 7 个库 × 11 轮，共 1,540 个实际测量单元；
原始报告、RSS、源码和校验和见[证据目录](../../../benchmarks/results/full-seven-library/2026-09-20-maintainability-7d086a6/README.md)。

**结果只适用于单核绑定、`cjProcessorNum=1`、128 MiB 堆的配置。**
它不代表默认运行时并发配置，也不与旧自适应批次、失败的固定采样批次或被拒包装拼接。
[Pure A/B](2026-09-13-linux-release-pure.md) 使用独立的 `YJSON_PURE_DIRECT_V1` direct 协议；其 24 个 case 均通过 `<= 1.05` 回退门槛且 48 个 side CV 均 `<= 5%`。Pure direct 与本页 SDKBench 七库结果不比较绝对延迟。

## 测量范围

Encode 从已构造的 typed value 生成紧凑 JSON 字符串；Decode 从 canonical JSON 字符串恢复同一 typed 类型。
Payload bytes 是 decode 输入的 UTF-8 大小。各 adapter 在正式计时前通过公开 API correctness preflight，
存在 direct typed path 时不使用 DOM fallback。

| Workload | Typed value 的形状 | 规模 | Payload bytes |
| --- | --- | ---: | ---: |
| Address | `Address{street_name: String, zipcode: Int64}` | 2 个字段 | 47 |
| Person | 3 个字符串 tag、2 个整数 score、嵌套 Address 和 null nick | 7 个 JSON 字段 | 176 |
| Large Array | `ArrayList<ProfileRecord>` | 64 条记录 | 3929 |
| Large Map | `HashMap<String, Int64>` | 64 个 entry | 1013 |
| Deep Nested | `ArrayList<HashMap<String, ArrayList<ProfileRecord>>>` | 8 组 × 4 条记录 | 1929 |

## 结果状态

**七库完整性 PASS；与独立单批 PASS 的 Pure direct 回退门禁共同完成本候选正式性能资格。**

两批均有 770 个唯一成功单元、7 个 preflight 日志、110 份 yjson 固定工作量证明和 770 份正值 RSS sidecar；合计 1,540 个实际样本单元和 220 份固定工作量 sidecar。
每个进程只测一个 exact case；工作量、报告和 RSS 均与 manifest 绑定。构建不计入 timing 或 RSS。

表中单位为 µs/op，是 11 轮独立进程样本的中位数，越小越好。
`Max CV` 是七个库中的最大 CV；只有 `Max CV <= 5%` 的行才是 stable。

| 批次 | 完整测量单元 | Stable workloads | Noisy workloads |
| --- | ---: | ---: | ---: |
| 第一批 | 770/770 | 0/10 | 10/10 |
| 第二批 | 770/770 | 1/10 | 9/10 |

Noisy 行保留原值，但不据此发布稳定的跨库精确比例。

## 第一批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 1.311 | 2.842 | 3.216 | 3.429 | 2.458 | 0.182 | 0.066 | 6.33% |
| Address decode | 1.775 | 2.478 | 3.381 | 3.474 | 2.002 | 0.318 | 0.075 | 12.39% |
| Person encode | 3.201 | 10.944 | 17.412 | 5.475 | 9.893 | 0.577 | 0.271 | 11.15% |
| Person decode | 10.363 | 21.734 | 27.373 | 20.237 | 15.425 | 1.124 | 0.420 | 6.64% |
| Large Array encode | 54.363 | 96.773 | 248.896 | 91.465 | 75.213 | 9.017 | 4.183 | 5.94% |
| Large Array decode | 112.407 | 174.699 | 414.680 | 174.165 | 77.405 | 18.846 | 5.110 | 10.99% |
| Large Map encode | 9.752 | 129.775 | 181.338 | 130.125 | 128.070 | 1.773 | 1.729 | 5.56% |
| Large Map decode | 48.099 | 250.112 | 338.861 | 224.211 | 237.897 | 5.405 | 3.892 | 5.02% |
| Deep Nested encode | 57.767 | 75.264 | 171.093 | 84.880 | 73.824 | 4.481 | 2.441 | 9.92% |
| Deep Nested decode | 367.074 | 161.780 | 242.501 | 143.104 | 95.183 | 10.420 | 3.412 | 8.51% |

## 第二批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 1.309 | 2.884 | 3.356 | 3.419 | 2.457 | 0.177 | 0.067 | 6.64% |
| Address decode | 1.776 | 2.479 | 3.501 | 3.427 | 1.998 | 0.317 | 0.071 | 4.95% |
| Person encode | 3.149 | 13.238 | 17.389 | 5.463 | 10.058 | 0.582 | 0.267 | 11.35% |
| Person decode | 10.545 | 21.627 | 29.017 | 20.283 | 15.383 | 1.130 | 0.420 | 6.44% |
| Large Array encode | 54.381 | 92.629 | 248.469 | 91.679 | 75.093 | 9.066 | 4.148 | 7.33% |
| Large Array decode | 111.845 | 184.248 | 400.909 | 173.312 | 77.568 | 18.748 | 5.129 | 8.20% |
| Large Map encode | 10.026 | 129.792 | 182.167 | 133.058 | 128.766 | 1.777 | 1.728 | 6.39% |
| Large Map decode | 47.733 | 249.856 | 337.673 | 223.232 | 224.778 | 5.416 | 3.964 | 5.69% |
| Deep Nested encode | 59.110 | 70.400 | 170.944 | 84.651 | 73.920 | 4.479 | 2.471 | 12.63% |
| Deep Nested decode | 357.844 | 159.137 | 266.328 | 143.206 | 94.985 | 10.398 | 3.418 | 7.39% |

## 输入和运行环境

| 项目 | 值 |
| --- | --- |
| Measured commit | `7d086a69200cecb447c64e73fa2b5e61e584ddb7` |
| Measured tree | `53527121b6bdca31586505ec838b5b092cd15924` |
| Product source SHA-256 | `1c3d85aca3fec86594d1732bb8779728cd42e7e5b7656b720bd0f934390cb2c9` |
| Effective harness SHA-256 | `43461d89631bd104fc93f32b0319dfc3d386c5a6a1266cd47bec4d1e2559268f` |
| Candidate identity SHA-256 | `67dca1cfe2b00efbf3cb4f85e3d2a4c5fb1fb9260483a138796c5813d6235a10` |
| SDK | Cangjie STS `1.1.3`；`cjc`/`cjpm` `1.1.3` |
| CPU | CPU 1，sibling 49；30 秒 idle sample 均为 `0.0%` |
| 仓颉运行时 | `cjHeapSize=128MB`、`cjProcessorNum=1` |
| Hostname | 独立 UTS namespace 中的 `example-host` |
| GNU time | `/usr/bin/time`；RSS 单位 `kbytes` |

七库和 workload 顺序逐轮旋转，偶数轮反转 workload 顺序。
yjson 用例采用冻结的固定工作量；其他库保留原采样参数，所有仓颉库统一限制运行时并发。
Java 每个外层轮次使用一个 fork、3 × 500 ms warmup 和 1 × 1 秒测量。
详细工作量规则见[性能方法](../methodology.md)。

yjson 与 stdx.json 共享本轮一次 clean compile-only 构建的候选程序；独立仓颉对照和 JMH JAR 使用按摘要绑定、逐字节复用的固定产物，没有重建 peer。
实际运行器与冻结候选权威源字节相同。28 文件 harness 身份为 `43461d…9268f`；候选源码 capsule 含 179 个冻结提交文件，并覆盖全部 51 个产品输入和 28 个 harness 输入。

## 资格边界与复核

本页七库矩阵使用 SDKBench；Pure 回退门禁使用 `YJSON_PURE_DIRECT_V1` direct 总耗时协议。两者 workload 名称相交也不能跨协议比较绝对延迟。
本矩阵测量 typed Pure API，不证明真实 Native provider 下 RF-009 writer 的性能，也不能代替正确性门禁。

在包含完整归档的干净候选中执行：

```sh
PYTHONDONTWRITEBYTECODE=1 bash scripts/ci_job.sh perf-evidence-drift strict
```

门禁验证校验和、安全解包、两批 770-cell 矩阵、RSS、固定工作量、整数单并发配置、可重新生成的 summary、文档表格，以及当前产品、harness 和发布绑定。不能用 `integrity-only` 放行。

## 已封存协议

`c844aa9` 的 Pure 第二批失败、初版固定采样的基线 OOM，以及被中止的七库部分批次均保持原状态。
统一 65,536 批上限的首次预检仍 OOM；单并发配置是随后经批准的测量方案，不是对旧失败的改判。SDK 分配器的准确失败机制仍未完成证明，本轮不声称修复 SDK。
首版 v1 包装因复制历史 run/summary 日志而被拒，并在远端保留为失败历史；当前 v2 只修正日志绑定，没有重跑 benchmark 行或改写测量数据。

<details>
<summary>c844aa9 原报告（封存，非当前配置）</summary>

### 2026-09-18 维护性重构候选七库完整对比

本页记录 [`current-main.json`](../../../benchmarks/results/full-seven-library/current-main.json) 指向的当前报告。两批测量绑定隔离候选 `c844aa9519ec9bd9bffa3e45fceb3d5d45fb974a`，对应 `0.1.0` 代码线的维护性重构与缺陷修复；这不是发布声明。原始报告、RSS sidecar、脚本与校验和见[证据目录](../../../benchmarks/results/full-seven-library/2026-09-18-maintainability-c844aa9/README.md)。历史归档保留，不与本轮样本拼接。

每个 workload-library 组合运行 11 个独立进程轮次。GNU `/usr/bin/time -v` 为每个进程记录 peak RSS，`manifest.csv` 与 sidecar 逐项对应。表中单位为 µs/op，数值是 11 轮中位数，越小越好。CV 超过 5% 的行完整保留，但不发布稳定的跨库精确排名；构建步骤不计入 timing 或 RSS。

### 先看 workload

Encode 从已构造的 typed value 生成紧凑 JSON 字符串；Decode 从 canonical JSON 字符串恢复同一 typed 类型。Payload bytes 是 decode 输入的 UTF-8 大小。

| Workload | Typed value 的形状 | 规模 | Payload bytes |
| --- | --- | ---: | ---: |
| Address | `Address{street_name: String, zipcode: Int64}` | 2 个字段 | 47 |
| Person | 3 个字符串 tag、2 个整数 score、嵌套 Address 和 null nick | 7 个 JSON 字段 | 176 |
| Large Array | `ArrayList<ProfileRecord>`；每条记录有 id、alias 和 level | 64 条记录 | 3929 |
| Large Map | `HashMap<String, Int64>`；key 为 `metric_0` 到 `metric_63` | 64 个 entry | 1013 |
| Deep Nested | `ArrayList<HashMap<String, ArrayList<ProfileRecord>>>` | 8 组 × 4 条记录，共 32 条 | 1929 |

### 结果状态

**整体性能资格未通过：** [Pure 第二批 A/B](2026-09-13-linux-release-pure.md)有两项超过 `1.05` 门槛。七库证据完整性通过不代表 Pure 或发布资格通过。

`Max CV` 是该 workload 在七个库中的最大 CV。只有 `Max CV <= 5%` 的行才是 stable；noisy 本身不改变普通 Release 的回退门禁。

| 批次 | 完整测量单元 | Stable workloads | 结论 |
| --- | ---: | ---: | --- |
| 第一批 | 770/770 | 2/10 | 完整测量；8/10 noisy |
| 第二批 | 770/770 | 3/10 | 完整测量；7/10 noisy |

### 第一批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 0.912 | 3.235 | 3.112 | 3.417 | 2.467 | 0.174 | 0.066 | 16.97% |
| Address decode | 1.316 | 2.361 | 3.437 | 3.459 | 2.016 | 0.309 | 0.071 | 14.81% |
| Person encode | 1.639 | 12.806 | 16.751 | 5.493 | 10.177 | 0.574 | 0.268 | 14.13% |
| Person decode | 7.944 | 21.585 | 28.050 | 20.984 | 15.416 | 1.134 | 0.421 | 7.40% |
| Large Array encode | 26.264 | 85.632 | 249.696 | 91.536 | 75.392 | 9.147 | 4.166 | 8.51% |
| Large Array decode | 92.768 | 174.835 | 408.434 | 174.013 | 77.746 | 18.539 | 5.101 | 12.32% |
| Large Map encode | 6.554 | 124.328 | 178.917 | 130.488 | 128.727 | 1.797 | 1.734 | 6.69% |
| Large Map decode | 26.777 | 241.586 | 350.912 | 223.573 | 224.372 | 5.299 | 3.903 | 4.42% |
| Deep Nested encode | 44.160 | 75.072 | 171.081 | 85.568 | 73.856 | 4.559 | 2.477 | 3.99% |
| Deep Nested decode | 325.739 | 155.958 | 263.747 | 143.155 | 95.407 | 10.454 | 3.405 | 11.47% |

### 第二批

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 0.902 | 2.759 | 3.221 | 3.430 | 2.586 | 0.171 | 0.066 | 30.80% |
| Address decode | 1.519 | 2.141 | 3.585 | 3.445 | 2.007 | 0.309 | 0.071 | 9.81% |
| Person encode | 1.709 | 13.198 | 17.712 | 5.458 | 10.424 | 0.576 | 0.267 | 15.26% |
| Person decode | 7.983 | 19.366 | 28.801 | 20.341 | 15.382 | 1.130 | 0.421 | 6.14% |
| Large Array encode | 26.275 | 87.488 | 249.350 | 92.390 | 75.469 | 9.016 | 4.159 | 8.23% |
| Large Array decode | 97.261 | 176.440 | 408.595 | 176.043 | 77.803 | 18.642 | 5.046 | 8.71% |
| Large Map encode | 6.557 | 124.896 | 178.155 | 128.209 | 127.693 | 1.810 | 1.732 | 4.89% |
| Large Map decode | 26.762 | 240.896 | 352.341 | 222.976 | 236.999 | 5.398 | 3.937 | 4.11% |
| Deep Nested encode | 44.000 | 74.731 | 171.031 | 85.376 | 73.856 | 4.543 | 2.443 | 3.47% |
| Deep Nested decode | 326.496 | 155.979 | 251.815 | 142.528 | 95.861 | 10.371 | 3.430 | 5.91% |

### API、环境和解释

各 adapter 在正式计时前通过公开 API correctness preflight。每个 adapter 使用语义等价的最快公开 typed API，存在 direct typed path 时不使用 DOM fallback。七库顺序与 workload 顺序逐轮旋转，偶数轮反转 workload 顺序。Cangjie 使用 200 ms warmup、至少 1 秒测量及至少 12 个 batch；Java 每个外层轮次使用一个 fork、3 × 500 ms warmup 和 1 × 1 秒测量。

| 项目 | 值 |
| --- | --- |
| Measured commit | `c844aa9519ec9bd9bffa3e45fceb3d5d45fb974a` |
| Measured tree | `76432c607bd5be972c1008d3a98905f35aa8f423` |
| Product source SHA-256 | `1c3d85aca3fec86594d1732bb8779728cd42e7e5b7656b720bd0f934390cb2c9` |
| Effective harness SHA-256 | `8c8e193c4f676484f020a0fcc997204a89993df90aa5cddb3005d2dd095ca251` |
| Candidate identity SHA-256 | `70856862780f30fab9098a671b080eee7e56eb9d24c6c01801ad55e028f8bed7` |
| Measured overlay SHA-256 | `4f1350b31ab636db4b6b00410d0927f4baf1e52900657ac5f6ae5eb529d0b35d` |
| SDK | Cangjie STS `1.1.3`；`cjc`/`cjpm` `1.1.3` |
| 环境 | SSH alias `Server`；Linux 5.15.0-187-generic；x86_64 |
| Hostname | 独立 UTS namespace 中的 `example-host`；未记录真实主机名 |
| CPU | CPU 0，sibling 48；30 秒 idle sample 均为 `0.0%` |
| Heap | `128MB` |
| GNU time | `/usr/bin/time`；RSS 单位 `kbytes` |
| Java | OpenJDK 17.0.20+8-1-22.04-Ubuntu；JMH 1.37；Jackson 2.18.2；fastjson2 2.0.52 |

隔离候选使用实际修改后的宏源码和本地 path 依赖；生产仓库的 Git pin 未改。此矩阵测量 typed Pure API，不证明真实 Native provider 下 RF-009 writer 的性能，也不能代替 Pure A/B、正确性测试或发布资格。Deep Nested 的不回退结论以[本轮 Pure A/B](2026-09-13-linux-release-pure.md)为准，不跨历史批次推导。

### 复核

在干净候选中执行 `bash scripts/ci_job.sh perf-evidence-drift strict`。门禁验证校验和、安全解包、每批 770 个单元与 RSS、原始报告再生成的 summary、文档表格，以及当前产品、harness 和发布绑定。不能用 `integrity-only` 代替 strict。归档中保存实际命令、exact case filter、工具链、preflight 与源码身份。

</details>
