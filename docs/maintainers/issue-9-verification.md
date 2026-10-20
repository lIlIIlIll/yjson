# Issue 9 修复与验证记录

日期：2026-10-02。关联 [issue #9](https://github.com/lIlIIlIll/yjson/issues/9)。
八项均在本次源码与实际运行中确认；实现已修复，发布验收仍受下述 gate 阻塞。

## 基线与环境

- 创建分支及提交前核对的最新 main：`0f2071a0ad59ad43a369abe51abaceaf873f0c63`。
- 独立分支：`fix/issue-9-json-correctness`。
- 宏子模块保持 `0847b59e0c8c47b7c5b52b550ef8765c0cbddb03`。
- Linux x86_64，官方 Cangjie STS 1.1.3；`cjc`、`cjpm` 均报告 1.1.3。
- SDK 归档 SHA-256：`2b68905afc466e665ae181595c63f96c18d75fd2c1fb6c6f0cb64e179c28d61a`。
- Native：Clang 15.0.7、GCC；libidn2 2.3.7。本容器需要仅映射自身及直接子进程 `/proc` 路径的兼容层才能启动 cjpm。
- 专项 `-O2` 编译与运行使用 Linux 8192 KiB 栈，仓颉运行时环境使用 SDK 默认配置。仓库 CI gate 继续使用其原有 128 MiB 编译栈。
- 默认资源预算、Reject 重复键策略、测试、CI 配置和性能基线均保持原值。

## 逐项证据

各项先加入回归、保存实际失败，再修改实现。可能不终止的旧实现使用独立进程和外部超时，终止整个进程组。

| 项目 | 修复前实际证据 | 实现与回归 | 修复后 |
| --- | --- | --- | --- |
| 001 | 两个 reader 对 128/256/512 个唯一键分别执行 8128/32640/130816 次名称比较；线性工作量断言失败 | `lib_json_direct_reader.cj`、`lib_json_fast_reader.cj`：每个对象独立的解码名称 HashSet；`json_issue9_skip_test.cj`、外部 unknown-skip 测试 | 对应 128/256/512 次集合插入；Reject/LastWins、转义等价重复键、父子同名键通过 |
| 002 | 手写与 generated consumer 的合法逗号后空白输入报 Unexpected token；raw bounded 路径也独立复现 | 三条对象 skip 路径消费逗号后的 JSON 空白；空格/TAB/CR/LF、嵌套未知字段、String/bytes、逐字节及所有分块位置测试 | 核心 6 项、外部 2 项通过；尾随逗号和非 JSON 空白继续拒绝 |
| 003 | 预算 8 的展开视图仍读取 131070 个子节点；Patch、Merge target/patch 循环分别在 5 秒超时后终止 | `yjson_algorithms/src/lib_json_patch.cj`：显式祖先栈，获取子节点前计费，复制前验证；Merge 两个输入均先验证，使用已复制 patch 子树 | 小预算只读 7/6 个子节点且未 materialize；循环 `cyclic_json_node`，深度超限 `max_depth`，预算 `work_limit_exceeded`；256/257 深度、DAG 每次出现计费、输入不变均通过 |
| 004 | 零容量 writer 8 秒超时；容量加法/乘法超限泄漏 OverflowException | `lib_json_direct_writer.cj`：零规范化为 1，负数 IllegalArgumentException；增长及所有容量预留使用受检算术，超限 `output_too_large` | 零、1、默认、扩容边界、Int64 边界及失败后内容保持通过 |
| 005 | 缺失路径 move 到自身未抛异常，回归失败 | `jsonPatchMove()` 在同路径返回前 evaluate 源；对象/数组/根/转义 Pointer 回归 | 缺源、越界、数组 `-` 返回 `json_patch_path`；存在路径保持原值，失败不修改输入 |
| 006 | 8 MiB bytes、maxInputBytes=64 的拒绝路径分配 8393968 字节，GC=0 | `CompactJsonDocument.parseOwned()` 分配前检查长度；limit-1/limit/limit+1、分配量和修改原 bytes 后文档不变测试 | 同 SDK、`-O2` 拒绝路径分配 1080 字节，GC=0；拥有式复制保留 |
| 007 | SDK 与 yjson 将 `1.0000000596046448` 舍入到 Float32 `0x3f800000`，而目标最近偶数舍入应为 `0x3f800001`；Float16 中点及溢出边界也失败；完整 Native/yyjson 各有 24 个负零位断言失败 | `lib_json_target_float.cj` 与 builtin/generated 桥：原文对精确目标中点比较，Float64 前缀仅作候选；backend tape 数字先验证语法；`native/yjson_compact.c`、`native/yjson_yyjson.c` 保留 `-0` 原文，view 与物化节点的整数访问器维持 0 | 核心 6 项、generated 41 项、Native primitives 3 项通过；生产 YJson Pure/Native primitives 各 7869 个有理数 oracle 向量零不匹配；完整 Native/yyjson consumer（含 Pure 对照）各 1216 个位断言零失败，持久回归包含 root/inline view、materialize 与逐字节 stream |
| 008 | 换行后 `"ab"`、maxStringBytes=1 的流错误报告第一行；两个位置回归失败 | 资源错误通过 InputCursor 定位；未消费窗口也扫描换行；未知坐标返回 None；覆盖 CRLF、UTF-8 byte column、每种分块与资源错误 | 资源专项最终 21/21、与 skip 合计 27/27 通过；示例为 byteOffset=3、line=2、column=3 |

001 的初始计数只在临时诊断副本中加入，产品没有计数器。持久回归脚本 `scripts/check_skip_work_scaling.py` 在临时副本中用同一包装键委托实际 String hash/equality，运行真实 parser 与 Array/HashSet 控制流；五种输入路径的旧版 equality 为 8128/32640/130816，新版 hash 为 128/256/512、equality 为 0。未知源码形状会失败，不声称验证了恶意哈希碰撞行为。007 的 oracle 使用 Python Fraction 独立计算 IEEE-754 最近偶数舍入，不以 SDK 的浮点 parser 作预期值。

007 追加验收真实发现 Native/yyjson 把负零整数压缩为 INT 0。先运行 C kind/text/tape 和仓颉位断言得到失败，再排除这一字面量的整数折叠；序列化现在保留 `-0`，普通整数仍使用原表示。旧 yyjson C 断言中的 `-0`→`0` 及混合数字统计按该语义修正，性能基线未修改。SDK 的 UInt64 文本 parser 拒绝 `-0`，因此另补先失败的 view 及 materialize 兼容性回归，维持 `asInt64()`/`asUInt64()` 为 0；`lib_json_value.cj` 只对精确 `-0` 返回 UInt64 0，其他负数、非法语法与 typed UInt64 的拒绝保持原有行为。

## 实际 gate 结果

consumer 与 standards 的 `YJSON_CI_DEPENDENCY_OVERRIDE=-O1` 与当前工作流的既有配置一致；专项默认栈 `-O2` 结果单独列出。

| 命令/检查 | 实际结果 |
| --- | --- |
| 临时源码副本仅把根 compile-option 改为 `-O0`，`cjpm test --no-color --no-progress` | 604/604 PASS，0 skipped/errors；补充验证，不能替代正式 core gate |
| `scripts/ci_job.sh core`，原始 `-O2` | FAIL，LLVM opt OOM，测试尚未执行；cgroup 峰值 8590163968 字节，oom_kill 4→5 |
| 未修改 main 上原样 `cjpm test --no-color` | 相同 LLVM opt OOM，oom_kill 3→4，证明完整 `-O2` 构建在本容器的 8 GiB 限制下存在基线阻塞 |
| 专项 `-O2`、8192 KiB 栈 | 最终 writer/document 13 项、reader/location 27 项、float 6 项，算法 60 项 PASS；临时工作量测试另通过 |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh macro-consumer` | 41/41、可执行程序及暂存包独立 macro consumer PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh algorithms-consumer` | 60/60、暂存 algorithms/schema-formats consumer PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 YJSON_STANDARDS_OFFLINE=1 scripts/ci_job.sh standards-conformance` | oracle 测试 PASS；Schema 1299、JSONPath 703、Patch 108，共 2110/2110 PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 YJSON_STANDARDS_OFFLINE=1 scripts/ci_job.sh schema-formats-conformance` | 格式包 2/2；含可选语料的 Schema 2263、JSONPath 703、Patch 108，共 3074/3074 PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh custom-native` | 最终 primitives 3/3、accel 13/13、native 17/17、暂存 Native consumer 和导出符号检查 PASS；零跳过，峰值 3.45 GB，未新增 OOM |
| `scripts/ci_job.sh runtime-freeze` | 原优化配置，10 个独立进程场景 PASS |
| `python3 scripts/check_target_float_rounding.py` / 加 `--native` | 生产 Pure/Native primitives 各 7869 向量，0 mismatches；`-O2`、8192 KiB 栈 |
| 完整 Native/yyjson 浮点 consumer 与持久包测试 | consumer 各 1216 位断言、0 failures、真实 executable exit 0，运行栈另核对 8192 KiB；Native 17/17、yyjson 20/20 PASS，构建使用其既有 `-O1` 配置 |
| `scripts/ci_job.sh native-clang` / `native-gcc` | PASS，C `-O2` 与警告检查 |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh yyjson-native` | 最终 20/20 与暂存 yyjson consumer PASS；零跳过，峰值 2.43 GB，未新增 OOM |
| `scripts/ci_job.sh yyjson-colink` | PASS，四种链接组合；固定 0.11.1 tag 对应 commit 的源码及 Git blob SHA 核验 |
| `scripts/ci_job.sh sanitizer` / `fuzz-short` | FAIL，Clang/GCC 的 LSan 因容器 PID namespace 与 `/proc` 不一致报 fatal；fuzz 保留 5000 个案例配置和 detect_leaks=1，没有禁用 LSan |
| `scripts/ci_job.sh cjdoc-qualification` | 6 项资格回归、固定源码构建及真实二进制资格检查 PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh examples` | generated codec、AST 与 builtin codec 示例全部运行 PASS |
| `YJSON_CI_DEPENDENCY_OVERRIDE=-O1 scripts/ci_job.sh registry-rehearsal` | FAIL；完整核心测试构建在 LLVM opt `-O1` 阶段 OOM，峰值 8589852672 字节，oom_kill 5→6，测试尚未执行 |
| 独立 `release_registry_rehearsal.py`，原有 bundle/consumer `-O1` 参数 | 最终补充 PASS：346 文件的 clean 候选、九模块确定性打包/复刻与全部六类外部消费者；191.07 秒，峰值 2525470720 字节，未新增 OOM。包括最终 Native、materialize 与清单修复，不替代上述完整 gate |
| `python3 scripts/check_skip_work_scaling.py`，再加 `--source-ref 0f2071a0ad59ad43a369abe51abaceaf873f0c63` | 真实 `-O2`、8192 KiB 栈：当前 PASS，旧 main FAIL；五种路径与三个规模均动态计数，策略回归通过 |
| `scripts/ci_job.sh perf-evidence-drift strict` | 40 个校验器测试 PASS；freshness FAIL，当前源码与冻结测量身份不同 |
| `TAR_OPTIONS=--no-same-owner scripts/ci_job.sh stream-docs` | PASS；该环境参数只处理容器无法恢复归档 uid/gid 的限制，内容与数值证据仍全部核对 |
| API inventory、source-stage、release-temp 单元检查 | PASS；1094 个公开声明，9 包，新增文件已纳入发布清单 |
| CI guardrails | 性能策略 20 项、consumer 策略 2 项、STS 4 项 PASS；健康 sanitizer 探针与 3 个真实 `/proc` 子进程发现用例受上述环境问题阻塞 |
| `scripts/coverage.sh` + `scripts/check_patch_coverage.py` | PASS；原覆盖流程下核心 613/613、runtime 10 个场景、Native accel 13/13；项目行 9029/10506=85.9%、分支 4001/5432=73.7%；改动行 265/265=100%、分支 181/204=88.7%，原阈值全部满足 |

## 复现精度检查

在准备好的 STS 1.1.3 环境与普通 8192 KiB 栈下执行：

```sh
python3 scripts/check_target_float_rounding.py
python3 scripts/check_target_float_rounding.py --native
python3 scripts/check_skip_work_scaling.py
```

脚本构建临时外部使用方，调用生产 `YJson`，覆盖正负中点两侧、偶数/奇数 tie、所有目标 exponent field、次正规数、溢出边界、负零、随机十进制与长指数抵消；不会修改仓库清单。

## 未完成的验收

- 正式完整 `-O2` core 及完整 registry-rehearsal gate 的可用运行结果，LSan/guardrails 的正常进程环境结果，以及托管平台与完整 CI Required 结果。
- 新源码的真实七库性能测量与性能 freshness 验收。原 runner 的实际准备检查失败：缺完整 peer 工作区、CPU 筛选输入、GNU time、JDK/Maven 及 STS 1.1.3 stdx；尚未完成 correctness preflight 或测量。既有测量、阈值和基线保持冻结，不能把原源码的结果绑定到本次修复。
- 不自动合并；issue 在验收完成前保持打开。
