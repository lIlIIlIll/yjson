# yjson 0.2.0 候选验证记录

本轮交付文档、SDK 迁移候选和 Pages；未发布 yjson 九包，未创建 yjson tag。
需求、实际检查结果和剩余缺口统一记录在[实施记录](../../docs/implementation/cjdoc-020.md)。
本页固定输入身份，不把尚未执行的检查写成通过。

## 工具链与源码

| 输入 | 固定身份 |
| --- | --- |
| 九包候选版本 | `0.2.0`，见[发布图](../release-graph.toml) |
| 产品、宏与 CI SDK | Cangjie STS `1.2.0` |
| 匹配 stdx | `1.2.0.1` |
| 实际 cjc SHA-256 | `023be1bb2ded1078906fc91919b3c1175ad14436ad88d23d505f7b8dcd0d7118` |
| 实际 cjpm SHA-256 | `a565d86540656c62340aacf6ac89c175b50c1f4d9ba4f69cee6a0fdacdee412d` |
| 静态 stdx SHA-256 | `1e0c5c14f2a028032a39a096a8849491b7d8e6711d5e269a0d744d028c4daf44` |
| 独立宏仓提交 | `c9ef52da9ba2d3f77916c40ccb9280db78ee2e07`；[PR #9](https://github.com/lIlIIlIll/yjson_macros/pull/9) 已合并 |
| 文档工具目标 | cjdoc `0.7.5`；正式源码归档与资格以[工具配置](../cjdoc-tool.toml)为准 |

上述工具摘要对应 Linux x86_64 官方安装输入，不代表尚未运行的 Windows 或 macOS 资格。
未构建或修改编译器、SDK、std 或 stdx。

## 性能输入

| 输入 | 固定身份 |
| --- | --- |
| 生产测量源码提交 | `0e1753ccae19c815670b97b63a998d84ede64595` |
| 生产产品源码摘要 | `dbf87de5e3c62fd1db395d6332ca17489b7ee4817ba00253a2984c3476cd2f38` |
| 生产 harness 摘要 | `230ccd61c2dd5bc85de33db9f2f27745c0f95e6fe7512bf8a1427a7b35cc2904` |
| Pure 清理前基线快照 | `f1fd90b5cac55bfe1705e6e4a7e136d5679545b8` |
| Pure 清理后候选快照 | `7eab830bddbaa02a9ee7d553da389c16fa79c5c2` |
| 两侧相同 Pure harness | `4774b4b1b674f039b7062ec03868cdce84627bc72659af2baad2fb378f9a34b9` |

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
