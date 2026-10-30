# yjson 0.2.0 候选验证记录

本轮交付文档、SDK 迁移候选和 Pages；未发布 yjson 九包，未创建 yjson tag。
需求、实际检查结果和剩余缺口统一记录在[实施记录](../../docs/implementation/cjdoc-020.md)。
本页固定输入身份，不把尚未执行的检查写成通过。

## 当前工具链与源码

| 输入 | 固定身份 |
| --- | --- |
| 九包候选版本与 SDK | `0.2.0`；Cangjie STS `1.2.0` 与匹配 stdx `1.2.0.1` |
| 独立宏仓提交 | `d819745310f8cc6aa416e1298f706ea5138b7d16`；[PR #10](https://github.com/lIlIIlIll/yjson_macros/pull/10) 已合并，仅新增四条分类注释 |
| 文档工具 | 已发布的 [cjdoc `0.7.7`](https://github.com/lIlIIlIll/cjdoc/releases/tag/v0.7.7)，[工具配置](../cjdoc-tool.toml)绑定精确源码与两次独立冷构建 |
| cjdoc 已合并源码 | `8cc8f71a296b1c6321e575b56fadbd0c379e242a`，tree `8bc115f09ed8823cdbe8dd66fdd940bf29b35af8`；[PR #168](https://github.com/lIlIIlIll/cjdoc/pull/168) 已合并 |
| cjdoc tag ref | `v0.7.7` 为轻量标签，直接指向上述 commit；没有独立 tag object |
| cjdoc main CI | [40994003657 / attempt 3](https://github.com/lIlIIlIll/cjdoc/actions/runs/40994003657/attempts/3)，三平台与 Doc IR 身份门禁通过 |
| cjdoc Reader 与站点 | [Reader](https://github.com/lIlIIlIll/cjdoc/actions/runs/40994003637) 通过；[Pages](https://github.com/lIlIIlIll/cjdoc/actions/runs/41027932006) 绑定 CI attempt 3，源码重现、浏览器、阅读与正式部署通过 |
| cjdoc 正式发布运行 | [41029708849 / attempt 2](https://github.com/lIlIIlIll/cjdoc/actions/runs/41029708849/attempts/2)，三平台、性能、打包及原发布器通过 |
| 工具资格配置 SHA-256 | `dbfcce51f26cb7229ee236ac2a78b692591d21d3170d8bd4ce1db50ba5c6c7d2` |
| cjdoc 精确源码归档 SHA-256 | `21a6e03a80ff5fcef259c1a80f55401f81e01c0fe33c9390c9409a0cf1f6cc75`；995 个文件及权限与 Git blob 一致 |
| 主仓本地验证源码 | `2945d3beb0ceb696cd7c673a0adee69b9635d860`，tree `7c0ad7021985a2509d815f4e9cdef157ce62a94f`；完整 strict 与全部 17 个 fresh CI gate 通过 |
| 正式生成 Doc IR SHA-256 | `fe4eb7b2d7315684f969986bc1529284a45c1dc41a676edc484f5c569c1e691b`；九包 1035 项声明及 333 个实际执行示例通过 |
| 本地完整离线包 | 16659640 字节，SHA-256 `4c810d798bf27054dfb9c51f4fa93aca11124f72b4e2856ff6f89ff295a9b4b3`；5331 个文件与站点相同，真实断网 query/MCP 及空 cjpm 缓存下全部 333 示例、11 profile 重建通过 |

本地工具资格使用下表中相同的 cjc/cjpm 和普通 static stdx，SDK、构建策略与 wrapper
摘要不变。两个独立空缓存构建的二进制 SHA-256 分别为
`a3e7875eba73cc02e65b3b3df00d968e6a4ae48e29a2b14758ccb12c74789808` 和
`482a128e9e70de09b69cc5424948a8eb80bd69a97c8f33ef3d6e7a574468e8c7`。
两份真实构建收据均与当前配置一致，不宣称二进制可重现。

公开 Release 的 12 项资产已全部下载；GitHub 摘要、六份校验文件、三份包的精确源码
payload、固定 SDK 及嵌入候选收据均独立检查通过。三个收据都绑定 Release attempt 2，
包内二进制与对应独立下载件一致；Linux 下载件实际输出 `cjdoc 0.7.7`。

| 平台 | 公开分发包 SHA-256 | 公开可执行文件 SHA-256 |
| --- | --- | --- |
| Linux x64 | `ee328b037828891534d34b17a0691ee95ad521125868200f0ba2a37f58a89de4` | `9c218e606d916a7411e70d7dc70a50ff7eeb704aa72a6fc45a284f01ae8ae386` |
| Windows x64 | `2300aeaf30f52cc74dedd7d0439a4bf62255d4acffc4da082bbbdd5bfd1113b7` | `141445a081a47d4de82b845b0ea8a38c798048c5c726682a714d6583b73514cc` |
| macOS arm64 | `a60a482a2705115b7764c652f26e4ea37636431470476ce06216b406aa91f0c7` | `182004e95efbae3ccd58ac0e68c274693d7e864c779c3b9adee6418e84936688` |

main 前两次失败及 Release 首次 macOS `markdown` 依赖的 `llc -O2` 退出 139 均保留。
用户明确授权完整重跑及同任务后续操作；所有门禁、优化参数和堆配置保持不变。
Linux 公开二进制与 main attempt 2 的失败二进制相同；后续通过不确定 GC 或 LLVM 故障根因。
本地主仓冻结输入已单独验收；托管三平台文档示例与 yjson Pages 仍待验收，不以 cjdoc
发布或本地结果替代。随后仅追加本页和实施记录正文，不改变生成器的 145 文件输入、
工具配置、产品或 harness。托管按最终 PR/main 提交重新生成，本地证据仍绑定 2945d3b。

## 当前性能输入

| 输入 | 固定身份 |
| --- | --- |
| 生产测量候选 | `ac4f8b987910a473ada7d77f10ce6cd3c12d2248`；宏仓 D819 |
| 产品源码摘要 | `4251be5ff98c50a91afdd162ae130d94f8bf2a70c85faf5da6a78304232771af` |
| 生产 harness 摘要 | `9d457f09101cb4466a82b000d2494e9c12b2f495b5b16b4fef809811a60d8852` |

Pure 24 项、11 轮正式测量通过；七库两批共 1540 单元，全部噪声行保留。
完整公开证据及独立重放见[本轮 Pure](../../docs/performance/results/2026-10-30-api-contracts-pure.md)
和[七库报告](../../docs/performance/results/2026-10-30-api-contracts-seven-library.md)。
工具配置与验收记录更新不属于已冻结的产品或 harness 输入。

## 历史工具链与源码（cjdoc 0.7.6）

| 输入 | 固定身份 |
| --- | --- |
| 九包候选版本 | `0.2.0`，见[发布图](../release-graph.toml) |
| 产品、宏与 CI SDK | Cangjie STS `1.2.0` |
| 匹配 stdx | `1.2.0.1` |
| 实际 cjc SHA-256 | `023be1bb2ded1078906fc91919b3c1175ad14436ad88d23d505f7b8dcd0d7118` |
| 实际 cjpm SHA-256 | `a565d86540656c62340aacf6ac89c175b50c1f4d9ba4f69cee6a0fdacdee412d` |
| 旧开发工具所用 extern 静态 stdx SHA-256 | `1e0c5c14f2a028032a39a096a8849491b7d8e6711d5e269a0d744d028c4daf44`；保留原验证范围 |
| 最终工具普通 static stdx SHA-256 | `e62289d5b88af440de04a26a30c79403d024f6accfacfd96607ae409ad9c1df2` |
| 独立宏仓提交 | `c9ef52da9ba2d3f77916c40ccb9280db78ee2e07`；[PR #9](https://github.com/lIlIIlIll/yjson_macros/pull/9) 已合并 |
| 文档工具 | 已发布的 [cjdoc `0.7.6`](https://github.com/lIlIIlIll/cjdoc/releases/tag/v0.7.6)，[工具配置](../cjdoc-tool.toml)绑定两次真实源码冷构建 |
| cjdoc 已合并源码 | `653457d1aa46ef2939cd10e130d7e1b16fd5d999`，tree `06f7d27491f8952b1df63163dca292d8cb8378d5` |
| cjdoc v0.7.5 tag object | `f16cfb1e30d69692b2d78a4cae795a55b7f73ac2`；正式发布的 macOS、Windows 验收发生 llc 崩溃，尚未发布 |
| cjdoc 0.7.6 修复 PR | [#166](https://github.com/lIlIIlIll/cjdoc/pull/166) 已合并，最终 PR HEAD `8cd4ccbb7683e430835f064450895b88c0269d53` |
| cjdoc v0.7.6 tag object | `742f292a9b1b0fedd012062b068b5b7f86a9b538`，指向上述精确 main 提交 |
| cjdoc 正式发布运行 | [40546453166 / attempt 2](https://github.com/lIlIIlIll/cjdoc/actions/runs/40546453166/attempts/2)，原三平台与发布门禁全部通过 |

上表的本地工具链摘要对应 Linux x86_64，yjson Windows 和 macOS 的最终平台示例另行验收。
未构建或修改编译器、SDK、std 或 stdx。

托管 cjv 和最终源码工具资格选择同一官方 stdx `1.2.0.1` 归档中的普通 static 子目录。
两次冷构建使用独立空缓存，核对了实际 cjc/cjpm、static stdx、构建脚本及单次成功产品调用；
二进制 SHA-256 分别为 `faf319e2866a691b5b5f7ff2cd73e366212dea574d208236979e10d48ad1c009`
和 `a8577e5f52e81892fb7f213475c279e59ce777337027de028067b43838aa0f1d`。
这两份收据不改标旧 extern 结果，也不证明二进制可重现。资格配置 SHA-256 为
`c65e560f88dbe5bff17fea7ef9c5581ac17af3e3b787d4da994cca1c1db4cde7`；
精确源码归档 SHA-256 为 `ac116b3fb587505f7ebae93c0b44fd6befa9a61464dbe77af208e31f8125646d`。

公开 Release 的 12 项资产全部下载并独立检查：GitHub 摘要、六份校验文件、三份包清单与
精确源码 payload，以及三个独立可执行文件和包内二进制的一致性均通过。

| 平台 | 公开源码包 SHA-256 | 公开可执行文件 SHA-256 |
| --- | --- | --- |
| Linux x64 | `e86fa35546a6f6def6dcfc381558b75d2eadb60d8f5ff3967ba9d7c8b48bc609` | `e6bc2e2529ede407d1b0a9ed00a3c8ef2c51d416270082474e3417852b65c377` |
| Windows x64 | `2f1f9b592a798f97db28b8d26b7dee4c78369ca4a122a7a7bc135bf795142c79` | `ed99126c82dfb78b7ba3e6bb77d299791b8eae4a11557c52ae97f3f69f9d3c28` |
| macOS arm64 | `bc23a48f32c9d28e5c071f97a4c86e4a0aadb84aab113a087b135249f58169f7` | `472daee119f75bebde813620de040a17d154ac4e69a149622df87df2e56166f7` |

首次 Release 的 Windows llc 与 Linux 运行时失败均保留。后续固定源码诊断未复现，
用户确认暂按偶发故障记录，并明确授权上述一次完整重跑。公开 Linux 二进制与首次失败相同；
本次通过没有修改 SDK、编译参数或门禁，也不确定两类故障的根因。

## 历史性能输入（5576cdd 及更早）

首次正式批未通过，以下身份和失败证据保留，不作为当前候选的通过结论。

| 输入 | 固定身份 |
| --- | --- |
| 生产测量源码提交 | `0e1753ccae19c815670b97b63a998d84ede64595` |
| 生产产品源码摘要 | `dbf87de5e3c62fd1db395d6332ca17489b7ee4817ba00253a2984c3476cd2f38` |
| 生产 harness 摘要 | `230ccd61c2dd5bc85de33db9f2f27745c0f95e6fe7512bf8a1427a7b35cc2904` |
| Pure 清理前基线快照 | `f1fd90b5cac55bfe1705e6e4a7e136d5679545b8` |
| Pure 清理后候选快照 | `7eab830bddbaa02a9ee7d553da389c16fa79c5c2` |
| 两侧相同 Pure harness | `4774b4b1b674f039b7062ec03868cdce84627bc72659af2baad2fb378f9a34b9` |

修正冗余空白扫描后的新候选已完成完整 Pure 测量和主 agent 原始证据复算。
24 项均通过原有 5% 门槛；七库两批数据、公开证据及来源摘要已独立复核，干净检出 `7d48eb2` 的完整 strict 通过。

| 新批输入 | 固定身份 |
| --- | --- |
| 生产测量源码提交 | `5576cddb1e42a3b391385038ab5b2e3f6d76a77c` |
| 生产产品源码摘要 | `eb31d8ab82a5ed9149fc1fbf2955f7b9f6796acf4af1ab612fb03a1d6f446e99` |
| Pure 候选快照 | `003dd5b4918ff63618749a5a589f263e74807e38` |
| 基线及生产、Pure harness | 与首次正式批相同 |
| 对比库适配摘要 | `5f09b209c66d504a2533b261a922e63cc8312ea549aa88619d9c4160c058f4fc` |
| Pure 原始证据归档 SHA-256 | `d7d9be698641f7634c9cc34c236c1ed74c34606568367188f79e280da786d9d2` |

主 agent 逐项核验归档 2939 个文件、48 个预检、528 个计时样本，以及原始工作量、
预热和绑核记录。最大候选/基线中位数比率为 `1.013942317686197`，最大样本 CV 约 4.02%。
原失败的字符串 Int64 Map 解码在新候选中的比率为 `1.0023357830205017`；旧失败批保持原样。

七库第一次调用在正确性预检中因缺少语料目录环境变量退出，正式计时样本为零。
失败归档 SHA-256 为 `d17419d9ad841f45594a9e0d577d111c479c94854aa43ffdaa17ee1b6684b5f1`。
补齐 `YJSON_CROSSLANG_CORPUS_DIR` 时沿用 Pure 的冻结语料，另建结果目录；
原失败输出不覆盖，harness、输入和性能门槛保持不变。

首批有效七库测量的 `70 × 11 = 770` 个单元已由主 agent 独立复核：
3012 个归档文件、全部 RSS 和用例绑定、110 份 yjson 固定工作量证明及三种汇总重放均通过。
归档 SHA-256 为 `2d65b6e7ed0dd1692a72d2cf30934f6b1362bf3accd7cb369555898db8502ca5`。
第二批独立 fresh build 后也完成 770 个单元，原归档 SHA-256 为
`4b9ef3e435de287df5ad21531ce87f146bbb6e95e5627a82ec1c07e4b3329f63`。
主 agent 重放两批汇总，核对全部 18 个稳定 metadata 字段及 10 个固定工作量用例一致；
两批合计 1540 单元，噪声行保留，没有第三批。公开来源已复核，干净检出 `7d48eb2` 的完整双批 strict 通过。

实际命令为 `bash scripts/ci_job.sh perf-evidence-drift strict`，40 项回归和严格证据校验均退出 0；
主 agent 独立重放 strict checker 也通过。同一主仓提交与宏 C9 的
`release_temp_tree.py --enforce-clean` 暂存 371 个文件，payload SHA-256 为
`455e0f83d45d18ef12900e1577789ea97c531c0200388d7c6fd7ef83845e80d3`。
这些结果不替代最终工具资格、托管矩阵或未来源码提交的验收。

Pure 两侧快照使用同一显式 path 依赖 overlay，七库使用实际生产 Git pin 与锁文件。
实际字节及链接输入参与身份校验，不归一化依赖 pin 或版本。正式测量采用相同 SDK 和
显式 `-O2`；不将 cjdoc 的 `--fno-chir-function-inlining` 加入产品或对比库的编译参数。
具体门槛和原始证据要求见[性能方法](../../docs/performance/methodology.md)。

cjdoc 的构建选择为 `-O2 --fno-chir-function-inlining`；单测采用单独记录的 O1 例外。
cjdoc 必须使用实际产品参数通过自身耗时与 RSS 上限检查。这不证明普通 O2 通过，
也不提供内联开关带来的性能变化比例。

最终主仓库提交、托管运行、工具发布和 Pages 产物身份在实际完成后追加；当前不记录
yjson 发布附件校验和。历史 [0.1.1 发布记录](../0.1.1/evidence.md)保持原样，只适用于其
记录的源码、SDK 和验证范围。
