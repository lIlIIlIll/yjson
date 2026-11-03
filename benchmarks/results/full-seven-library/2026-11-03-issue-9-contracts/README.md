# Issue #9：2026-11-03 源绑定性能证据

测量生产提交：`aa128768beaaa4383586ae306ab0c0d2f74ce172`。
产品 `a0ca74e163e77bf33a0c48267b2b0dc0f51e81b85178dc7a6eba1a20c0bd34c6`，生产 harness `0f16fde97703cf34328a37cbbdfa37ceb6d20d636e0a48f3ea8a2de2beefad8e`，
宏 `2bfd34c08c421c04a0cd8e3d1326140849f1f21b`，STS `1.2.0`，九包候选 `0.2.0`。

[Pure 完整资格](../../../../docs/performance/results/2026-11-03-issue-9-contracts-pure.md)与[两批七库报告](../../../../docs/performance/results/2026-11-03-issue-9-contracts-seven-library.md)分开阅读。
完整 Pure 24 项和额外 HEAD Deep Nested 两项通过原门槛；七库各 770 单元顺序完成。
这是测量与数据重放证据，不表示已经发布 yjson；最终 PR 还须对应 HEAD 的 strict 与 Required。
[旧 Issue #15 证据](../2026-10-30-issue-15-contracts/README.md)保持原样，不重标旧结果。

## 内容

| 公开存档 | 普通文件数 | 范围 |
| --- | ---: | --- |
| `seven-library-issue9-batch1.tar.gz` | 3000 | C3 正式计时/构建/源码，测量 PASS |
| `seven-library-issue9-batch2.tar.gz` | 3000 | C3 正式计时/构建/源码，测量 PASS |
| `seven-library-issue9-build-audits.tar.gz` | 25 | C3 正式计时/构建/源码，测量 PASS |
| `pure-issue9-qualified.tar.gz` | 3151 | C3 正式计时/构建/源码，测量 PASS |
| `pure-issue9-source-inputs.tar.gz` | 404 | C3 正式计时/构建/源码，测量 PASS |
| `seven-library-issue9-harness.tar.gz` | 585 | C3 正式计时/构建/源码，测量 PASS |
| `pure-issue9-first-failure-C.tar.gz` | 3212 | C1 正式失败；measurementStatus=FAIL |
| `pure-issue9-failure-C2.tar.gz` | 3247 | C2 正式失败；measurementStatus=FAIL |
| `issue-9-diagnostic-history.raw.tar.gz` | 1638 | 历史准备、采样及因果诊断；DIAGNOSTIC_ONLY |

C3 六包共 10165 个普通文件。两个正式失败包及诊断包另行保留，不能用其 verifier 的 PASS
替换 measurementStatus。文件名中的 `raw` 表示保留诊断原始载荷，不表示公开压缩字节等于私有下载包。
C1 补充宏源码在诊断包 `c1-dependency-inputs/`；完整原宏源码和许可证也在 C3 source-inputs 包中保留。

七库第二批仅六项满足七库 CV 均≤5%；四项 noisy 全部保留，不第三批追分。
`canonical-report-rows.json` 保存由可信 checker 生成的两批完整行与 README 第二批稳定行。
Pure/七库前后的生产源码、宏、SDK、overlay 与产物身份一致；当前生产保留真实 Git macro pin。

## 传输、隐私与源身份

- `download-verification.json`：下载的六个私有原包及每个成员均与服务器封存清单相同。
- `server-packet-inventory.json`：原包 SHA-256、全部成员 SHA-256/字节数。它记录私有原包的压缩字节摘要，
  不替代公开 `checksums.txt`。
- `publication-projection.json`：原包/公开包摘要分列，逐成员证明全部载荷、顺序、非 owner 属性相同。
  只将 uid/gid、uname/gname 及对应 PAX owner 字段匿名化，并使用匿名 gzip 头。
- `publication-content-audit.json` 与 `publication-content-review.json`：C3 六包全部内容和元数据检查，
  28 条匹配分别核验为标准 SDK unittest 库标识或匿名 `/mnt/home/.cjpm` 路径；保留原字节。
- `c1-*`、`c2-*`、`diagnostic-history-*`：各自的投影、完整内容审计、逐项处置与离线复算。
- `pure-offline-verification.json`：全部 572 计时及 52 预检、原始日志/RSS/sidecar、affinity、独立统计、
  实际 compiler execve、三份语料和完整宏源码闭包重放。
- `seven-offline-verification.json`：1540 唯一单元、1540 正 RSS、220 fixed-work、七个源码树、生产闭包、
  SDK 清单、生产 execve、peer O2 argv 和两批完整 summary 重算。

源码包保留生产 manifest/lock、全部 product/harness 输入、三侧 Pure 快照及原始宏仓许可证。
json4cj 的原 README、公开同代码来源回执和三份 manifest 调整 patch 均保留；上游只声明 MIT，
未找到独立完整 LICENSE/NOTICE，不补造上游版权信息。
所有公开存档不含 Git 元数据或可执行二进制。归档里的 Python/脚本只作数据，没有执行。

## 可信离线重放

在干净、已审核的 checkout 根目录执行。以下程序是本目录中经过版本控制并列入校验和的文件，
不是从存档解出的同名程序。源码和 runner 归档只供比对，不加入 Python import path。
先启用仓库约定的 STS `1.2.0`。然后在磁盘上创建独占目录：

```sh
install -d -m 0700 "$HOME/.cache/agent-tmp"
findmnt -T "$HOME/.cache/agent-tmp"
df -h "$HOME/.cache/agent-tmp"
E=benchmarks/results/full-seven-library/2026-11-03-issue-9-contracts
work=$(mktemp -d -p "$HOME/.cache/agent-tmp" yjson-issue9-replay.XXXXXX)
export TMPDIR="$work" TMP="$work" TEMP="$work" PYTHONDONTWRITEBYTECODE=1
(cd "$E" && sha256sum -c checksums.txt)
for archive in \
	seven-library-issue9-batch1.tar.gz \
	seven-library-issue9-batch2.tar.gz \
	seven-library-issue9-build-audits.tar.gz \
	pure-issue9-qualified.tar.gz \
	pure-issue9-source-inputs.tar.gz \
	seven-library-issue9-harness.tar.gz \
	pure-issue9-first-failure-C.tar.gz \
	pure-issue9-failure-C2.tar.gz \
	issue-9-diagnostic-history.raw.tar.gz; do
	tar --no-same-owner --no-same-permissions -xzf "$E/$archive" -C "$work"
done
python3 "$E/verify-pure.py" --trusted . \
	--results "$work/pure-issue9-qualified" \
	--sources "$work/pure-issue9-source-inputs" --output "$work/pure.json"
python3 "$E/verify-seven.py" --trusted . --capsules "$work" \
	--expected-main aa128768beaaa4383586ae306ab0c0d2f74ce172 --output "$work/seven.json"
python3 "$E/verify-failed-pure.py" --trusted . \
	--capsule "$work/pure-issue9-first-failure-C" \
	--expected-main 57cfddb61834fb1d3c5c2e573ff6d986124045e2 \
	--expected-product 5a7b638804bc5561bf94775adc5df6aa7a2ce0fc8d61678a15a80d46aa64a8f1 \
	--expected-overruns 6 --output "$work/c1.json"
python3 "$E/verify-failed-pure.py" --trusted . \
	--capsule "$work/pure-issue9-failure-C2" \
	--expected-main 87f37a76ff02d1214158c787ca6732aaa97ecbd6 \
	--expected-product b5c49ab3d0fdebefd22b73c51be5818cde825b3022ecf45811905d9978cca23a \
	--expected-overruns 1 --output "$work/c2.json"
python3 "$E/verify-history.py" --trusted . \
	--packet "$E/issue-9-diagnostic-history.raw.tar.gz" --output "$work/diagnostics.json"
bash scripts/ci_job.sh perf-evidence-drift strict
```

最后一条要求干净 checkout。重放失败批的预期输出为 verifier `status=PASS` 且
`measurementStatus=FAIL`；诊断为 `DIAGNOSTIC_ONLY`。不将预期失败改判为资格通过。
`trusted-replay-tool-manifest.json` 绑定本轮使用的七个重放/审计工具；
`checksums.txt` 和 schema 3 marker 将公开存档及回执全部绑定。

本地重放不证明托管 CI、Windows/macOS 性能、Native 性能或发布资格；
相同产品/harness 的最终 Required 与其他发行要求仍独立验收。
