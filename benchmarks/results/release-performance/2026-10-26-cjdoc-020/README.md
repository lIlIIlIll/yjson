# 0.2.0 候选 Pure 性能证据

生产候选 `5576cddb1e42a3b391385038ab5b2e3f6d76a77c` 的正式 Pure B 批次通过回退门槛。
此前候选 `0e1753c` 的 Pure A 批次失败，失败数据和判定一并保留。两批各有
24 个用例 × 11 轮 × 2 侧，共 528 个计时进程，另有 48 个预检进程；未删除样本或跨批拼接。

| 批次 | 测量判定 | 最大候选/基线中位数比率 | 最大单侧样本 CV |
| --- | --- | ---: | ---: |
| Pure A | FAIL | 1.056846899412867 | 3.110594794483142% |
| Pure B | PASS | 1.013942317686197 | 4.0167913250402805% |

A 的失败用例为 `yjsonStringDecodeLargeInt64Map`。B 使用修改后的独立候选；两批的源码、
可执行文件和运行配置分别记录。门槛仍为全部比率 ≤ `1.05`、全部单侧 CV ≤ `5%`。
本目录保留 Linux、STS `1.2.0`、显式 `-O2` 的测量证据；不代表其他平台或整体发布资格通过。
完整条件、24 项结果和变更边界见 [Pure 报告](../../../../docs/performance/results/2026-10-26-cjdoc-020-pure.md)。

## 公开文件

- [Pure B 证据归档](pure-release-020-b-source-only-evidence.tar.gz)：2938 个普通文件，保留全部原始计时与预检 stdout、RSS 和直接计时 sidecar、线程绑定、CPU 监测、构建日志、参数、SDK 摘要、统计和来源收据。
- [Pure A 失败证据归档](pure-release-020-a-failure-source-only-evidence.tar.gz)：2987 个普通文件，保留同类完整数据和原失败统计。
- [独立统计复核](independent-validation.json)：从两批全部 1152 份进程 stdout 重算统计，并逐项核对工作量、预热、分段、成功状态、RSS、角色绑定和 ready/continue 文件。`publication_validation: PASS` 只表示证据校验通过；A 的 `measurement_result` 仍为 `FAIL`。
- [原包到公开层校验](original-to-public-validation.json)：原包逐文件比对、源码字节一致、原包未变及重复生成证明。
- [父 agent 的原 B 独立复核](parent-pure-b-verification.json)：原始 2939 个文件的校验收据，逐字节保留。
- [主 agent 的公开层复核](parent-public-layer-verification.json)：重新逐文件比对两个原包与公开层，核对全部 826 份源码记录及保留文本中的路径替换，并重放公开统计校验。
- [路径规范化清单](path-normalization.json)：每个原普通文件的 before/after SHA-256、大小、公开位置、替换次数或排除原因。
- [校验程序](verify_public_evidence.py)和 [SHA256SUMS](SHA256SUMS)：可在不执行输入源码、不提取 Git 历史的情况下复核公开层。

这些证据留在源码仓库本目录，不加入库的源码发布包。

## 源码树与原始身份

原始胶囊含 Git 历史，其中作者身份未完成公开核实，因此原胶囊只在私有任务目录原样保留。
公开归档中的嵌套包是 **source-tree**：不含 Git 元数据、Git objects 或编译产物，不能恢复原 Git 历史。
未改写或重新生成任何原 Git 对象。A 中的完整 GitHub commit API 响应同样私有保留；公开
身份收据仅记录原响应 SHA-256、公开 API URL 和真实 commit/tree，结构性替换在路径清单中单列。

基线、A 候选和 B 候选分别保留 200 个源码及构建输入文件，A 另保留宏仓库 26 个文件。
所有源码文件均与原胶囊逐字节相同，且核对了原 commit/tree 对应的 Git blob 摘要。
两包合计包含 826 份源码文件记录，其中共享基线重复出现一次；独立源码树共 626 个文件。

| 源码树 | 原 commit | 文件清单 |
| --- | --- | --- |
| 共同基线 | `f1fd90b5cac55bfe1705e6e4a7e136d5679545b8` | [200 文件](pure-baseline-source-manifest.json) |
| A 候选 | `7eab830bddbaa02a9ee7d553da389c16fa79c5c2` | [200 文件](pure-candidate-a-source-manifest.json) |
| B 候选 | `003dd5b4918ff63618749a5a589f263e74807e38` | [200 文件](pure-candidate-b-source-manifest.json) |
| A 宏缓存 | `c9ef52da9ba2d3f77916c40ccb9280db78ee2e07` | [26 文件](yjson-macros-c9-source-manifest.json) |

每份源码清单保留原 tree、原胶囊 SHA-256、公开 source-tree 包 SHA-256 和逐文件摘要。
这里的 commit 是隔离测量快照身份；生产提交和产品源码摘要仍以各批原 provenance/receipt 为准。

原始完整归档身份：

| 原归档 | SHA-256 |
| --- | --- |
| Pure A | `9baff78bd4f9dca198614880a341953776091db94ed20f0fc2d18a652f688da4` |
| Pure B | `d7d9be698641f7634c9cc34c236c1ed74c34606568367188f79e280da786d9d2` |

原包中的四个 ELF 可执行文件未公开；其精确 SHA-256、大小和原成员位置保留在
路径清单及各包 `public-layer/source-and-binary-receipt.json`，并与原 provenance 核对。
公开层不提供可直接重放的二进制环境。

## 规范化与复核

临时路径前缀替换为 `<work>`、`<snapshot>` 或 `$HOME`。仅证据文本执行这些替换；
源码字节、测量值、SDK/二进制摘要和 commit/tree 标识均不变。原包的 5927 个普通文件都有处置记录：
5917 个文本文件保留，5 个 Git 胶囊替换为源码树包，4 个 ELF 排除，1 份完整 Git commit API
响应替换为身份收据。保留文本中 3528 个逐字节不变，2389 个仅替换路径；准确分类和逐文件摘要见路径清单。

所有嵌套归档均检查为普通文件，无链接、设备、绝对成员路径或 `..` 路径分量。
归档按成员名排序，uid/gid 为 `0`，owner/group 为空，tar 与 gzip 时间戳为 `0`；
保留源码原执行位。公开内容已检查开发机路径、用户名、主机、私有地址和凭据。第三方 yyjson 源码中的公开
版权邮箱属于原 license/source 内容，按原字节保留；示例域名和 GitHub 服务地址也保留。
两次从相同原输入生成的两份证据包、四份源码清单及路径清单全部逐字节一致。

在仓库根目录执行：

```sh
cd benchmarks/results/release-performance/2026-10-26-cjdoc-020
sha256sum -c SHA256SUMS
python3 verify_public_evidence.py .
```

校验程序仅依赖 Python 标准库，读取归档而不向磁盘解包。它验证公开文件摘要、嵌套源码摘要、
确定化元数据及两批原始进程统计。原始私有包到公开层的字节关系由单独收据记录；
公开文件不能独自证明未公开原包的内容，也不替代重新构建、重新测量或发布门禁。
