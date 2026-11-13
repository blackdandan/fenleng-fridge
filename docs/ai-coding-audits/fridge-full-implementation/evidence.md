# 阶段审计证据

路径均相对仓库根；`.fenleng`为本机原始日志，不作为已提交或公开发布证据。

| 事项 | 证据 | 范围和结论 |
| --- | --- | --- |
| 初始FVM消费者尝试及后续成功 | .fenleng/source-candidate-fvm.log；项目06-project/app/.fvmrc | 已使用固定fork；项目配置关闭自动旧Melos改写与切换后pub，历史提示失败不算成功 |
| Windows核心测试首次失败及固定入口成功 | .fenleng/source-candidate-core-tests.log、source-candidate-core-tests-fixed-sdk.log为失败；source-candidate-core-flutter-tests.log为通过 | 原生Dart runner及绝对路径尝试失败，同一SDK Flutter runner核心17项通过；归属aa706候选 |
| 最新消费者 | .fenleng/candidate-e17-fvm-use.log、candidate-e17-pub-get.log、candidate-e17-app-tests.log | e17d候选独立解析成功，App168通过/7默认渠道跳过；包内SDK路径由verify-source-candidate.py核验 |
| 首进协议实际修复 | 02-engineering/evidence/android/consent-current/results.json、digital-sampling.json | 安全区和长文本真实问题有修复与回归；不声称像素完全相同 |
| WebView UIA限制 | 同上results.json的nativeFunctionalProof | 第二次阅读器渲染正文/底部可见但UIA仅暴露header；未宣称无障碍验收通过 |
| 安装取消 | Owner会话“先不用安装”；本机owner-install日志 | package服务未就绪时报错，等待启动的命令已停止；本阶段未成功安装新包到Owner模拟器 |
| 当前待完成范围 | 04-operations/completion-audit.md | 整体目标保持in-progress，不以阶段测试代替全面完成审计 |

完整首次通过率及全程耗时无法仅由这些证据重建，保持unknown。

最终功能复核发现并修复平台任务领取/进度回写的事务裂缝；证据为02-engineering/evidence/data-request-recovery-results.json。新增真实PG6项、兼容共20项通过。初轮测试因模块依赖与Test导入不匹配编译失败，日志data-request-transaction-tests.log保留，修正后tests-fixed与recovery-regression日志和XML同时归档；不把首次失败改写成一次通过，也不因本轮后端修复重复未改的客户端全量构建/截图。
