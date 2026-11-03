# 2026-11-03 Issue #9 七库性能证据

生产测量提交：`aa128768beaaa4383586ae306ab0c0d2f74ce172`；九包候选 `0.2.0`，宏固定为 `2bfd34c08c421c04a0cd8e3d1326140849f1f21b`。
两批顺序完成，各 770 个唯一单元，共 1540 个；没有补跑单元、覆盖首批或第三批。
第一批 10/10 workload 稳定；第二批 6/10 稳定、4/10 noisy。README 只使用第二批稳定行。

[完整证据、校验和与可信重放](../../../benchmarks/results/full-seven-library/2026-11-03-issue-9-contracts/README.md)；[独立 Pure 回退资格](2026-11-03-issue-9-contracts-pure.md)。

## 输入与执行条件

| 输入 | 固定身份 |
| --- | --- |
| 产品源码 SHA-256 | `a0ca74e163e77bf33a0c48267b2b0dc0f51e81b85178dc7a6eba1a20c0bd34c6` |
| 生产 harness SHA-256 | `0f16fde97703cf34328a37cbbdfa37ceb6d20d636e0a48f3ea8a2de2beefad8e` |
| candidate binding SHA-256 | `44031890bd8a2f07ffacd8698bc1ac82225adbb0f4f8f8426156066bf3635cc0` |
| 测量 overlay SHA-256 | `5f09b209c66d504a2533b261a922e63cc8312ea549aa88619d9c4160c058f4fc` |
| SDK/STDX 清单 SHA-256 | `ea7984dc5c37c02acf7f7119c24d7633a3b655f0c71350a8aa910c87abe00b5a` |

仓颉使用 STS `1.2.0`、显式 `-O2`，测量构建保持 CHIR 函数内联。
仓颉进程为 `cjProcessorNum=1`、`cjHeapSize=128MB`；每批重新采样空闲物理核后单核绑定。
JMH 使用每外层轮次 1 fork、3×500ms warmup、1×1s measurement、avgt ns/op。
各库入口与数据模型见归档 `metadata.json` 的 `api_paths`；七库 canonical fixture preflight 全部通过。
不同协议的样本不拼接，也不把七库表当作 Pure C/B 回退资格。

| 批次 | UTC 开始 | UTC 结束 | business CPU / SMT sibling | 空闲采样秒数 | 稳定 / noisy |
| --- | --- | --- | --- | ---: | --- |
| 1 | 2026-11-03T06:33:14.925030+00:00 | 2026-11-03T07:26:50.325639+00:00 | 17 / 65 | 30 | 10 / 0 |
| 2 | 2026-11-03T07:27:24.183192+00:00 | 2026-11-03T08:21:01.823774+00:00 | 2 / 50 | 30 | 6 / 4 |

入选物理核的两个线程均低于 1% 利用率；原始采样窗口与 CPU 选择保留。
全部 1540 份 RSS 为正，220 份 yjson fixed-work 证明与对应原始日志一致。
计时前后重新核验生产源码、所有 peer 源码、SDK、overlay 和产物；没有在计时中构建。

## 第一批

单位为 µs/op，中位数；Max CV 是该 workload 七库中的最大值。

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 0.379 | 1.051 | 0.904 | 1.004 | 0.915 | 0.177 | 0.067 | 2.71% |
| Address decode | 0.214 | 1.881 | 0.563 | 1.796 | 0.695 | 0.327 | 0.070 | 4.37% |
| Person encode | 1.079 | 4.078 | 5.657 | 2.230 | 3.746 | 0.573 | 0.271 | 2.38% |
| Person decode | 1.649 | 7.257 | 4.942 | 6.216 | 4.733 | 1.133 | 0.421 | 0.80% |
| Large Array encode | 18.644 | 37.975 | 80.610 | 37.793 | 34.608 | 9.122 | 4.153 | 3.35% |
| Large Array decode | 36.565 | 64.990 | 43.357 | 64.609 | 43.667 | 18.840 | 5.067 | 4.06% |
| Large Map encode | 3.756 | 26.281 | 46.821 | 29.489 | 27.939 | 1.747 | 1.741 | 2.93% |
| Large Map decode | 11.984 | 55.033 | 58.562 | 50.496 | 49.644 | 5.391 | 3.984 | 1.57% |
| Deep Nested encode | 20.988 | 29.882 | 51.269 | 29.100 | 26.059 | 4.461 | 2.459 | 1.89% |
| Deep Nested decode | 46.331 | 49.189 | 36.432 | 44.176 | 32.826 | 10.344 | 3.415 | 4.97% |

## 第二批

采用同一协议重新采样，不替换第一批。单位为 µs/op，中位数。

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 | Max CV |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 0.380 | 1.042 | 0.901 | 0.997 | 0.904 | 0.176 | 0.066 | 2.96% |
| Address decode | 0.214 | 1.858 | 0.562 | 1.809 | 0.690 | 0.325 | 0.070 | 4.31% |
| Person encode | 1.082 | 4.034 | 5.659 | 2.230 | 3.762 | 0.574 | 0.269 | 1.54% |
| Person decode | 1.634 | 7.230 | 4.946 | 6.199 | 4.723 | 1.131 | 0.418 | 1.03% |
| Large Array encode | 18.638 | 37.948 | 80.486 | 37.608 | 34.577 | 8.875 | 4.132 | 5.49% |
| Large Array decode | 36.548 | 64.900 | 43.266 | 64.646 | 43.647 | 19.060 | 5.079 | 6.45% |
| Large Map encode | 3.749 | 26.205 | 46.832 | 29.416 | 27.883 | 1.726 | 1.761 | 5.61% |
| Large Map decode | 11.976 | 55.017 | 58.603 | 50.336 | 49.665 | 5.439 | 3.943 | 1.73% |
| Deep Nested encode | 20.940 | 29.834 | 51.273 | 29.016 | 26.056 | 4.469 | 2.467 | 2.11% |
| Deep Nested decode | 46.260 | 49.117 | 36.362 | 44.282 | 33.024 | 10.366 | 3.438 | 6.21% |

Large Array encode/decode、Large Map encode、Deep Nested decode 为 noisy，保留全部结果，
不发布这些行的精确相对比例，也不追加第三批追分。

## RSS 峰值

单位 KiB；每格是对应库 11 个进程峰值中的最大值，包含运行时与进程开销。

### 第1批 RSS

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 169868 | 169820 | 155564 | 158272 | 162880 | 205908 | 201236 |
| Address decode | 170160 | 169736 | 155380 | 158180 | 162428 | 202060 | 201332 |
| Person encode | 170268 | 169752 | 155800 | 158200 | 162408 | 204280 | 201940 |
| Person decode | 170072 | 169928 | 155660 | 158252 | 157712 | 202628 | 205256 |
| Large Array encode | 170140 | 169992 | 155804 | 158220 | 162972 | 203612 | 201480 |
| Large Array decode | 170020 | 169880 | 155980 | 158260 | 162324 | 202544 | 201444 |
| Large Map encode | 170244 | 170012 | 155540 | 158256 | 163124 | 203800 | 202264 |
| Large Map decode | 169932 | 169960 | 155636 | 158068 | 162724 | 202032 | 201972 |
| Deep Nested encode | 169968 | 169872 | 155696 | 158348 | 162688 | 225992 | 201780 |
| Deep Nested decode | 170100 | 170020 | 155380 | 158448 | 162672 | 203340 | 201884 |

### 第2批 RSS

| Workload | yjson | stdx.json | cangjieJSON | json4cj | cjfast_json | Jackson | fastjson2 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Address encode | 170216 | 169992 | 155464 | 158120 | 162976 | 205968 | 201216 |
| Address decode | 170056 | 169968 | 155428 | 158220 | 162896 | 202108 | 201240 |
| Person encode | 169832 | 169948 | 155788 | 158204 | 163112 | 204256 | 201984 |
| Person decode | 170120 | 169896 | 155256 | 158248 | 162872 | 202824 | 205368 |
| Large Array encode | 170028 | 169884 | 155804 | 158372 | 161060 | 203800 | 201388 |
| Large Array decode | 169888 | 169912 | 155556 | 158424 | 162756 | 202512 | 201608 |
| Large Map encode | 170544 | 169956 | 155644 | 158180 | 162892 | 203912 | 201788 |
| Large Map decode | 170148 | 170016 | 155672 | 158128 | 162644 | 202112 | 201784 |
| Deep Nested encode | 170208 | 169960 | 155780 | 158180 | 162832 | 226064 | 201892 |
| Deep Nested decode | 169972 | 170012 | 155568 | 158436 | 163276 | 203356 | 202084 |

## 构建与对照库复用

| 程序 | 模式 | 字节数 | SHA-256 |
| --- | --- | ---: | --- |
| seven-cjfast | 已核验复用，未重建 | 14329384 | `ae9757be96e9e38a02b3e7c26e455882f77ecfb8a6f2c49b543e789f359bc7bf` |
| seven-cjjson | 已核验复用，未重建 | 13310424 | `b9e2733542512e21aef19ecaab24d105fa2dd2065d392dbf934d652779ea4c73` |
| seven-json4cj | 已核验复用，未重建 | 15371616 | `93a2527ae0f14cd446bc68c1feca954ff284d8ba96521fab8d169a5cdcb131d2` |
| java | 已核验复用，未重建 | 7363572 | `89e1f5eb6cb837889815ab5122bc3ab1bac7d541a25143f8d270878f3842d026` |
| seven-yjson | 当前生产源码 clean rebuild | 18624640 | `0108086594378ab25e44f34d80cc8e198d032837f6c174af1709dc222814c214` |

yjson 与 stdx.json 使用同一个从生产 Git-pinned C3 干净构建的程序。
其他仓颉程序与 Java JAR 只有在源码、fixture overlay、SDK、实际 O2 argv 及产物摘要全部吻合时才复用；
未将复用写成重建。生产 execve 原始日志和 argv 回执由可信工具独立重算，三份复用 peer 的编译回执也验证了 O2。
Java/JMH 的依赖版本与精确调用保留在 metadata 和 harness 中。

七个源码树摘要、完整生产 product/harness 载荷及两个原始宏仓源码/许可证均保留。
json4cj 对应公开提交 `a185e9ac0df95ee2a9715941b13f21f2a2a4f674` 的同代码来源与三个 manifest 调整有独立回执及 patch。
上游 README 声明 MIT，原树未找到独立完整 LICENSE/NOTICE；本轮保留经过 Git blob 与 SHA-256 核验的完整原 README，
不补造版权声明或把这一事实写成完整法律审查。
宏依赖使用本地 Git URL 路由取得精确 pin，不据此判断远端发布状态。

## 重放与适用范围

可信 checkout 的 checker 重验每批 70 个 workload/library 配对各 11 轮、全部原始日志/RSS/fixed-work、
两批稳定身份和完整 summary。`verify-seven.py` 另复算七个源码树摘要、生产闭包、SDK 清单及生产 execve。
公开包的全部 10165 个普通文件载荷和非 owner 属性保持不变，owner 与压缩头另作匿名投影；
28 条内容扫描匹配逐项处置为标准 SDK 库标识或匿名 `/mnt/home/.cjpm` 路径，没有丢弃原始字节。
归档内脚本没有执行。C1/C2 的正式失败及侵入式诊断独立保留，不算作本批通过。

本次不发布 yjson，不证明 Native 性能、其他平台/SDK、默认并发配置或外部 provider 资格。
测量与离线重放通过不等于最终 PR Required 或发布资格通过。
