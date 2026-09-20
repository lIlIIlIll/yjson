# yjson benchmarks

本目录保存性能测试用例、对照库适配器和汇总脚本，用于检查性能回退和收集发布证据。
这些代码不属于产品 API；性能测量还需要单独验证结果是否正确。

## 组成

| 路径 | 作用 |
| --- | --- |
| `packages/benchmarks` | yjson、stdx.json 类型编解码测试，以及 JSONPath 与 Schema API 对照 |
| `packages/backend_benchmarks` | AST、GC 管理的文档、Native 与 yyjson 测试 |
| `cjfast_json` | cjfast_json 类型编解码适配器 |
| `java_fastjson2` | fastjson2 适配器 |
| `scripts/json_perf_baseline.py` | 统一采集结果格式 |
| `scripts/json_backend_perf_run.py` | 后端测量脚本 |
| `scripts/json_backend_perf_summary.py` | 后端结果汇总 |
| `stream_protocol/workloads.json` | Stream protocol v1 用例与输入配置 |
| `scripts/json_stream_protocol_run.py` | 旧版 yjson 与候选版本的生命周期配对采集 |
| `scripts/json_stream_peer_run.py` | yjson 与 stdx.json 的增量流处理配对采集 |
| `scripts/json_pure_perf_compare.py` | Pure 基线与候选版本的发布验收和内部优化配对采集 |
| `full-seven-library/fixture-preflight-overlay.patch` | 七库外部测试程序中对标准输入的编码与解码断言 |
| `results/full-seven-library/<date>` | 当前开发版七库同批次对比的原始证据与校验和 |

类型编解码器、DOM 后端、类型化流编解码和跨运行时适配器的结果必须分别报告，不能将不同
数据表示或生命周期的测量合并排名。

<a id="pure-baselinecandidate-workload"></a>

## 比较 Pure 基线与候选版本

`scripts/json_pure_perf_compare.py` 支持普通 Release 验收和内部优化评估。准备两个独立且没有未提交
修改的源码目录；正式运行通过 `--rebuild --enforce` 在两侧清理并重建 `packages/benchmarks`。
结果目录必须位于两个源码目录之外。两个目录中的性能测试程序必须相同，产品源码可以不同。

24 个 Pure 验收用例使用直接计时；七库保留 SDKBench。两个协议共用
[`bench_fixed_work.cj`](../packages/benchmarks/src/bench_fixed_work.cj) 中的冻结工作量。
Pure 以批大小乘以批次数作为调用总数，类型化和 DOM 用例测量一个连续区间；
流式用例每次在计时区外创建新输入或输出流，只累加编解码区间。类型化用例预热
至少 200 ms，DOM 与流式用例至少 500 ms。七库的固定用例仍使用方法级 `minDuration=0`
并保留原预热和输入提供器生命周期。其他未列入固定表的基准不受此协议约束。

工作量在候选测量前冻结，不按候选成绩调整。配置表先以两批全部基线样本的中位数估算三秒
工作量：普通用例固定 200 批，将每批调用次数向上取二的幂；流式用例固定每批一次调用，
将批次数向上取二的幂。所有用例随后统一应用 65,536 批上限；额外两个 Address 用例仍为
200 批、每批 16384 次。该上限约束逻辑批次数，不等于 SDK 保留的统计样本数，也不保证
128 MiB 堆下可完成统计。当前仅 `encodePersonMemory` 的有效批次数从 524,288 降为
65,536，测量调用数减少八倍；三秒只是未截断的工作量预算，不是实际墙钟时长保证。

正式 Pure 与七库仓颉进程统一设置 `cjHeapSize=128MB`、`cjProcessorNum=1`。
Pure 将业务、GC 主线程组与 GC 辅助线程组分别绑定到三个物理核心；七库仍绑定单个 CPU。
结果仅代表各自的线程放置和运行时配置，不能当作默认配置的测量。

Pure 可执行文件输出 `YJSON_PURE_DIRECT_V1`，运行器检查用例、调用总数、计时、预热、
分段数与测试成功状态。七库仍校验 `YJSON_FIXED_WORK_V1` 声明与 SDK 批次数、批大小。
两种协议均要求同一用例跨轮次保持相同工作量；声明缺失、冲突或用例失败直接拒绝结果，
不会通过重试补齐。

语料目录必须包含 `person.json`、`records-64k.json` 和 `records-1m.json`。各用例测量
以下操作：

| 用例名称模式 | 输入与计时边界 |
| --- | --- |
| `yjsonStringEncodePerson` / `DecodePerson` | 使用生成的编解码器，将单个 `Person` 与 `String` 互转 |
| `*LargeProfileArray` | 使用生成的编解码器处理 `ProfileRecord` 大数组；覆盖字段名、字符串和整数 |
| `*DeepNestedProfiles` | `ArrayList<HashMap<String, ArrayList<ProfileRecord>>>`；覆盖递归容器 |
| `*ProfileBundle` | 使用生成的编解码器，将组合类型与字符串或字节数组互转 |
| `*EscapedUnicodeString` | 含控制字符、反斜杠和非 ASCII 文本的编码 |
| `parseStringRecords*` | `YJson.parseDocument(String)`，分别使用 64 KiB 和 1 MiB 文档 |
| `parseBytesRecords*` | `YJson.parseDocument(Array<Byte>)`，使用相同文档 |
| `decode*Chunk4k` | `YJson.fromJson(InputStream)`，输入按 4096 字节分块提供 |
| `encode*Memory` | `YJson.writeJson` 写入调用方持有的内存流 |

同一性能测试类还包含三个 XL 大规模测试，用于观察输入增大后的热点：

| 用例 | 数据形状 | API |
| --- | --- | --- |
| `*XlProfileArray` | 1024 个 `ProfileRecord` | `YJson.toJson/fromJson` + 显式的类型化列表编解码器 |
| `*XlInt64Map` | 一个包含 1024 个键值对的 `HashMap<String, Int64>` | `YJson.toJson/fromJson` + Int64 映射编解码器 |
| `*XlDeepNestedProfiles` | 64 组 × 每组 16 条记录，共 1024 条 | `YJson.toJson/fromJson` + 递归类型编解码器 |

XL 用例在构造阶段解析一次具体的编解码器，不在遍历元素时重复解析。它们是 yjson
内部规模分析用例。只有对照库提供语义相同的数据结构和对应的最优类型编解码 API 时，才能进入
跨库共同结果表。

`AlgorithmOptimizationBenchmarks` 使用同一输入检查三项设计边界：在视图上找到首项后停止、收集
全部匹配后取首项、转成 AST 后再查询；另外比较 Schema 编译一次后重复验证与每次重新
解析 Schema。测试程序在计时前验证结果一致。这组测试用于观察性能回退，不与类型编解码器或 DOM
后端的排名混合。

在 Linux Server 上运行发布验收矩阵：

```terminal
scripts/json_pure_perf_compare.py \
  --baseline /path/to/baseline \
  --candidate /path/to/candidate \
  --corpus /path/to/corpus \
  --output /path/to/result \
  --rounds 11 \
  --gate-mode release \
  --rebuild \
  --enforce
```

`release` 模式只检查完整结果和回退：任何用例回退超过 5%，命令返回非零状态。
CV 只影响 stable/noisy 标签和可发布的性能表述，不会单独使普通 Release 失败；
它不要求候选版本相对基线提升。

如果正在评估一个明确的内部优化，再显式启用优化模式：

```terminal
scripts/json_pure_perf_compare.py \
  --baseline /path/to/baseline \
  --candidate /path/to/candidate \
  --corpus /path/to/corpus \
  --output /path/to/result \
  --rounds 11 \
  --gate-mode optimization \
  --target-case yjsonStringDecodeLargeProfileArray \
  --target-improvement-percent 5 \
  --rebuild \
  --enforce
```

优化模式在发布模式的基础上保留双方 CV 不超过 5% 的稳定性条件，并要求每个
`--target-case` 至少提升指定百分比、在 11 轮中至少胜出 5 轮。`--target-case` 和
`--target-improvement-percent` 只能与 `--gate-mode optimization` 一起使用；目标优化
门禁不是普通 Release 的必要条件。

脚本先采样 CPU 利用率，选择同一 NUMA 节点上三个物理核心，所有 SMT 线程的利用率
必须低于 1%。`--cpu` 可指定业务核心，但不能绕过空闲检查。fixture 准备完毕后，
运行器通过文件握手核验五个运行时线程并设置亲和性，再放行预热和计时。
奇偶轮反转基线与候选版本的执行顺序。

结果包含 `provenance.json`、`summary.json`、`summary.md`、`cpu-selection.json`、两侧
构建日志、CPU 监控 CSV、每个进程的 GNU `time -v` RSS sidecar、直接计时日志及
线程放置证据。来源记录绑定源码、配置表、运行器和可执行文件摘要；`--enforce`
固定要求 11 轮、`--rebuild` 和无未提交修改的源码树。

## 发布结果要求

- 用例语义、API、输入数据和输入形态一致；
- 基线与候选版本或多个库交替、反转顺序执行；
- 完整保留 yjson、stdx.json、cjfast_json 的共同用例；
- 高 CV 行保留并标为 noisy（波动过大）；noisy 不单独阻断普通 Release，也不支持发布精确比例；
- 方向证据与稳定精确比例分开；
- 保存提交、运行时和主机信息、各轮原始结果、测量清单与校验和；
- 不把临时路径、快速测量结果或未同步的跨批次数字写入 README。

统计方法和证据要求见[性能方法](../docs/performance/methodology.md)，可引用结果见
[性能入口](../docs/performance/README.md)。

## 验证 Stream 文档

运行下面的命令，校验归档的校验和、机器汇总和生成的测试输入页面：

```terminal
scripts/ci_job.sh stream-docs
```

命令输出每个文件的 `OK`、`Stream workload documentation is current`，以及三个 JSON
汇总的等价检查。正式性能测量必须在文档规定的 Server 环境运行，不能用这个检查替代。
