# 应用官网接入登记

日期：2026-11-12；阶段mvp；状态in-progress（仅本地首稿）。

- 描述性名称：冰箱库存管理；正式产品名称待定。
- 产品仓库：https://github.com/blackdandan/fenleng-fridge；官网首稿同仓 `06-project/prototype/website/`。
- 运营者：杭州临安芬棱软件设计工作室（个体工商户）；产品/域名/部署Owner由仓库Owner确认。
- 联系：fenlengtech@163.com / 18234132630（来源见shared-platform-integration.md）。
- 域名：`fridge.fenlengtech.com`，2026-11-13 Owner 确认并自行扩展；解析、HTTPS、部署尚未验证。
- 法律源：`user-agreement.md`、`privacy-policy.md`；由 `06-project/scripts/build-preview-legal.mjs` 生成 `06-project/prototype/shared/legal-content.js`，App/官网共用。
- 正式协议规划同域 `/terms/` 与 `/privacy/`；当前本地入口以官网实现为准。状态draft，无线上发布证据。
- 数据处理：同运营体系Shared Platform/Client SDK，反馈和分析处理要求见隐私政策；接入后需锁定SDK版本与实际清单，本轮无真实SDK、广告或支付接入。
- Android APK / Google Play / App Store：未发布，显示敬请期待；没有可用安装包时不提供下载链接。
- Canonical link：规划 `https://fridge.fenlengtech.com/app/`，官网首稿保留Web降级页；Associated Domains、Team ID、Bundle ID、AASA、assetlinks未配置，不声称唤起App可用。
- 芬棱门户：规划 `https://www.fenlengtech.com` 产品入口指向本产品官网；本轮不修改门户或登记表，状态planned。
- APP备案号、官网ICP备案号：均未核实，分别占位；不复制其他站点号码。

## 后续验收
确认产品名、域名与Owner → 定稿协议与真实SDK/处理清单 → 配置App级link/AASA及降级页 → 正式签名包与商店状态 → 发布官网及HTTPS/协议版本验证 → 门户挂载与登记证据。上述工程/发布项未因首稿完成而通过。

2026-11-13工程进度补充：已将原批准首稿承接至06-project/web，生成静态首页/terms/privacy/app入口和20种界面语言。本地提供经过版本/签名/完整HTTP SHA验证的Android0.1.0(1)调试预览；其他渠道未正式发布，未提供假入口。当前以../../02-engineering/specs/website-implementation-evidence.md和implementation-status为工程证据；网站未部署、法律仍V0.4中文审阅草案，初稿中的“无安装包”描述仅为当时阶段记录。
