# 发布 yjson

按以下流程准备和发布候选版本。每个候选的提交、SDK、运行器、命令、日志和
校验和必须进入 `release/<version>/evidence.md`。

## 1. 固定候选版本

当前准备九包 `0.2.0` 候选，记录主仓与独立宏仓的精确提交、发布图、工具链及版本。
本轮只交付候选、cjdoc 工具发布与 Pages，不发布 yjson 九包或创建其 tag。
以下打包和发布步骤供另行授权的正式发布使用。
发布期间不混入未经评审的公开 API、C ABI 或生成代码接口变化。

`release/public-cangjie-delta-0.2.0.toml` 必须逐项覆盖当前候选相对精确基线快照的全部删除和新增记录。
每条记录只能属于一个说明了理由的评审组；存在重复、漏项、`unclassified` 或尚未完成评审的组时，不得把发布图改为 `release-ready`。
组评审状态必须对应发布图版本；生成器不会自动批准已分类的变更。enum 采集修正还必须绑定
`release/0.2.0/enum-case-inventory.json`，证明记录在基线源码中已经存在。历史 `bfd29` 差异文件保留原样。

产品、宏、示例、文档与托管 CI 统一使用 Cangjie STS `1.2.0` 及匹配的 stdx。
`release/cjdoc-tool.toml` 是 SDK 精确版本来源；CI 的 `sts` job 导出同一版本，所有包 manifest
的 `cjc-version` 下限同步为 `1.2.0`。证据记录实际 `cjc`、`cjpm`、SDK 安装回执、归档摘要
和可执行文件摘要。daily 或旧 SDK 不能替代这一资格检查。

API 文档工具固定为 cjdoc `0.7.7`。升级工具时，先完成上游发布及源码资格验证，再将准确的
源码提交、归档摘要和二进制证据写入工具配置。未完成这些步骤时，不得记录为工具已发布或资格已通过。
归档、可执行文件和 Action 均按真实来源记录校验和或完整 SHA。

整个 `0.x` 阶段不保证 patch 或 minor 之间的 API、ABI、生成代码或旧 SDK 兼容。
每项破坏性变更仍须说明影响、给出迁移方法并取得用户确认。发布检查保留当前 API 差异评审、
包配对和外部消费方验证，不再要求旧消费方二进制跨版本矩阵。历史结果保持原样。

## 2. 发布前检查

以下任一项失败都会阻止发布：

1. API/C ABI 接口清单、发布图或包版本配对失败；
2. 核心包、示例、宏、codec 或算法使用方测试失败；
3. 固定标准测试集或可选格式测试集不满足预期用例数；
4. 发布性能测量缺少负载、校验和、RSS、交替与反转 A/B，或确认发生阻止发布的性能回退；
5. Native 包不能从暂存源码独立构建；
6. 编译警告检查、ASan、UBSan、LSan、差分模糊测试或符号隔离失败；
7. 清单、仅含源码的暂存、许可证、内置第三方源码校验和或隔离的使用方测试失败；
8. 文档规定的选项、错误、视图、流、并发或生命周期约定失败；
9. 源码归档包含构建产物、缓存、符号链接或未声明产物；
10. 发布验证平台存在尚未处理的正确性或安全问题；
11. GitHub Actions Linux、Windows 或 macOS Pure 检查，或 Linux Native 检查失败；
12. 覆盖率低于项目行 80%、分支 70%，或改动行 90%、分支 80%；
13. cjdoc 资格、九包统一文档、应用注释与可执行示例、离线查询、链接或可复现性检查失败。

`0.2.0` 的 Pure 基线固定为 STS `1.2.0` 迁移后、旧包装清理前的源码，候选与基线使用
同一 SDK 和测量程序。冻结生产源码、宏指针、锁文件和测量输入后，执行 24 个 Pure 用例
各 11 轮，以及七库两批各 770 个单元，并通过 `perf-evidence-drift strict`。
旧 SDK 的历史结果不作为本候选通过的证据，不发布跨 SDK 性能结论。

Pure 的普通 Release 验收使用 `json_pure_perf_compare.py --gate-mode release`：
正式 `--enforce` 运行要求完整的 11 轮配对结果，且所有用例的 `candidate/baseline <= 1.05`；
CV 只用于 stable/noisy 标签和性能声明精度，不作为普通 Release 的失败条件。
只有 Release notes 明确宣称某项性能优化时，才额外使用
`--gate-mode optimization --target-case ...` 验证该优化目标；优化模式除 Release
回退条件外还要求双方 CV 不超过 5%，目标用例达到指定提升并在 11 轮中至少赢 5 轮。
优化目标未达标不应被误写成所有 Release 的通用性能失败。

即使 CV 过高，也要保留并报告结果；noisy 只表示不能发布精确性能比例。
Native 加速的正式检查使用 11 轮、固定 CPU、交替进程顺序；对外宣称加速的读写负载
要求 `Native/Pure <= 0.95` 且至少赢 6/11，普通负载不得回退超过 5%，双方 CV 均不超过
5%。这些条件只决定 Native acceleration 性能声明是否成立；不稳定批次整体作废并完整重跑一次，
第二批仍不稳定时不得发布该声明，但 noisy 本身不阻断普通 Release。只有 Release notes
明确包含该加速声明时，才把这项 qualification 纳入该次发布的额外阻塞条件。

## 3. 记录各项检查结果

```text
Local Linux fresh-candidate: PASS / FAIL / NOT RUN
Hosted Linux CI: PASS / FAIL / NOT RUN
Hosted Windows Pure: PASS / FAIL / NOT RUN
Hosted macOS Pure: PASS / FAIL / NOT RUN
Coverage: PASS / FAIL / NOT RUN
Pages deployment: PASS / FAIL / NOT RUN
Release policy: BLOCKING / NON-BLOCKING
```

本地 PASS 不能写成托管 CI 的 PASS。候选 PR 和合并后的 `main` 工作流都须通过；
分别记录推送、PR、CI、合并、打标签和发布状态。

## 4. 准备源码并演练发布

先在磁盘上创建任务目录，确认文件系统和可用空间，再创建仅含源码的工作树：

```terminal
install -d -m 0700 "$HOME/.cache/agent-tmp"
findmnt -T "$HOME/.cache/agent-tmp"
df -h "$HOME/.cache/agent-tmp"
release_task=$(mktemp -d -p "$HOME/.cache/agent-tmp" yjson-release.XXXXXX)
export TMPDIR="$release_task" TMP="$release_task" TEMP="$release_task"
python3 scripts/stage_source_tree.py "$release_task/source-stage"
python3 scripts/stage_source_tree.py --check "$release_task/source-stage"
```

目标必须为空且不能与源码树重叠。暂存目录拒绝构建产物、可执行文件、归档、
性能分析或覆盖率文件和符号链接。

按发布文件清单创建候选树：

```terminal
python3 scripts/release_temp_tree.py "$release_task/release-stage" --enforce-clean
```

该命令只复制 `release/release-files.txt` 中的路径，并再次执行仅含源码的检查。正式候选
要求干净的检出版本，并生成 `release/candidate-provenance.json`。该文件记录提交、Git 树、
清单摘要和文件内容摘要；来源记录文件自身不计入文件内容摘要。每个收录的 cjpm 项目的 `src/**/*.cj`、`cjpm.lock` 和 `build.cj`（若存在）必须完整入清单；被收录
脚本依赖的本地文件也必须收录。

API 接口清单和核心包测试会写临时文件，因此 CI 在候选清单复制出的诊断树中运行这些检查。
包仓库发布演练使用未修改的正式候选树，并在构建前后验证清单和来源记录。

完整本地 Linux 模拟：

```terminal
scripts/ci_fresh_checkout.sh
```

包仓库发布演练从候选树执行 API 接口清单、九包独立暂存和构建、外部使用方测试、
第三方声明、内置第三方源码的校验和，以及导出符号检查。SDK 构建不属于 yjson 包
发布检查。

## 5. 生成 API 文档并部署 Pages

使用前述任务目录，从固定源码构建并验证 cjdoc，再生成九包统一站点：

```terminal
cjdoc_path=$(scripts/codex_cangjie_env python3 scripts/prepare_cjdoc.py)
scripts/codex_cangjie_env python3 scripts/generate_api_docs.py \
  --cjdoc "$cjdoc_path" \
  --output "$release_task/api-docs"
scripts/codex_cangjie_env python3 scripts/run_api_doc_examples.py "$release_task/api-docs"
python3 scripts/check_api_documentation.py "$release_task/api-docs"
```

目标必须不存在。站点以根目录 `index.html` 为入口。候选要求 HTML、Markdown、Doc IR v16、
质量报告与完整 Agent 离线包，并实测 `query` 和 stdio MCP。应用范围中文契约与逐入口
可执行示例的规则见 [API 文档维护指南](api-documentation.md)。解析限制必须精确记录，
不为旧 URL、旧 Doc IR 或旧目录建立兼容层。

PR 构建并上传文档 artifact；合并到 `main` 后，全部必需门禁通过且部署提交仍为 HEAD 时才部署。发布证据记录
部署 URL、运行 ID 和产物校验和。本地生成 HTML 后，还需要单独确认 Pages 部署成功。

## 6. 打标签并发布

所有阻塞问题关闭且证据评审完成后：

1. 通过普通 PR 合并到 `main`；
2. 等待合并提交的全部必需工作流通过；
3. 在该提交创建与候选版本一致的附注标签；
4. 创建 GitHub Release；
5. 上传九个 `.cjp`、`checksums.txt`、`manifest.json` 和 `environment.json`；
6. 验证发布附件和 Pages 指向已验收的提交。

向中心包仓库发布是单独操作；未获授权时不得发布。发布动作、URL 和校验和
追加到发布记录，后续候选不得覆写。

测试对应关系见 [testing.md](testing.md)，性能规则见
[性能方法](../performance/methodology.md)。
