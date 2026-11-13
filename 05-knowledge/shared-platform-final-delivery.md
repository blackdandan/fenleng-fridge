# Shared Platform与官方SDK最终交付

Owner于2026-11-13明确要求平台提交、push和部署，剩余正式配置及端侧验收由Owner处理。

- 平台仓库：blackdandan/fenleng-shared-platform，main已推送35487625d6e1a49bf18c925a90d7521b89c30477；生产0.1.0-rc.138，实际schema V63，三个容器healthy。
- SDK仓库：blackdandan/fenleng-client-sdk，main已推送b5e529fab47f95a7fcbefc397f90051dce903b0b；完整verify和78项Flutter测试通过。
- 平台迁移：未发布冰箱V54/V55/V56顺延为V61/V62/V63，保持上游已部署V54–V60不变。原阶段文档中的旧编号仅为历史。
- 保留上游微信acquisition事务记录、Apple登录及认证遥测deliveryId去重；App和小程序事件使用密码学UUID，SDK重试保留同一事件标识。
- Flutter三份官方SDK副本按Git blob字节冻结，来源与哈希见06-project/app/vendor/flsdk/candidate-provenance.json；不依赖同级工作区。
- 小程序与官网显式依赖带b5e529f文件名的官方源码tgz。旧candidate归档保留原字节，不改写历史证据。
- 部署：固定root@121.199.10.6单向上传本机构建JAR，服务器只用已缓存固定JRE/原Admin做离线镜像装配，无远程源码编译和镜像回传。既有发布代理执行备份、切换、smoke及回滚点保留。
- 最终生产证据：02-engineering/evidence/final-delivery/platform-production-verified.json；数据库2,248,469字节备份已验证可列出目录，路径为/opt/fenleng-shared-platform/production/backups/offline-0.1.0-rc.138。RC137可回滚。

平台部署不等于冰箱正式客户端登记或Provider配置已完成。游客、提醒、采集等默认关闭能力，待Owner配置和真实联调后按产品登记启用；不改变现有物理删除审批及hold。

归档复核：官方SDK随后push清理提交de7fb7c993f6a5e842c73d629ff88c6ed8e7ca88，只取消跟踪8个误纳的Gradle缓存并补ignore，保留本地缓存；消费API源码仍固定b5e529f。产品snapshot只包含66个真实源码文件，8项非源码排除记录在provenance，完整来源ZIP已通过逐文件校验。
