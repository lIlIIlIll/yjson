# 0.1.1 Pure 正式性能证据

本轮使用实际发布的 0.1.0 源码与冻结的 0.1.1 候选进行完整 A/B。
正式结果为 PASS：24 cases × 11 rounds × 2 sides = 528 个计时进程，另有 48 个预检进程。
全部 C/B ≤ 1.05，全部单侧 CV ≤ 5%；没有第二批。

完整结果、协议和身份见[Pure 报告](../../../../docs/performance/results/2026-09-13-linux-release-pure.md)。
源码候选为 `fd2a8f7b400c4c80d6aaaf1e71fdd1ac5ff422ab`，测量提交为
`ce39e57ba6ade281d232bc0d82abfafdf91f5bb5`；产品、harness 与版本绑定一致。

## 文件

以下文件保留在 Git 仓库本目录，不进入 source-only 发布树：

- `pure-direct-release-011-evidence.tar.gz`：576 个进程的 stdout、direct/RSS sidecar、线程放置、CPU 监测、构建日志、退出码和独立复核。
- `independent-validation.json`：从全部原始记录重算的统计和门禁结果。
- `published-010-baseline-source.tar.gz` 与 `published-010-baseline-source-manifest.json`：172 个冻结基线文件及逐文件摘要；两侧使用相同当前 harness。
- `tag-baseline-aborted.tar.gz`：发现旧 tag 与实际附件不一致后中止的首次部分批次，含中止原因；不进入正式统计。
- `SHA256SUMS`：上述文件摘要。

候选源码胶囊与本轮七库证据共用。归档路径使用 `<work>`、`<snapshot>` 或 `$HOME`
占位符；计时值和源码字节不改写。正式归档包含路径规范化前后的文件摘要。
归档无链接、路径穿越、私有路径或私有 IPv4；归档时间戳、uid/gid 与 owner 字段确定化。

```sh
cd benchmarks/results/release-performance/2026-09-21-release-011
sha256sum -c SHA256SUMS
```

历史 tag/附件不变；基线差异见 [issue #6](https://github.com/lIlIIlIll/yjson/issues/6)。
