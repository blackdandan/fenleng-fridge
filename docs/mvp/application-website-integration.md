# 应用官网接入登记

日期：2026-11-12；阶段mvp；状态in-progress（仅本地首稿）。

- 描述性名称：冰箱库存管理；正式产品名称待定。
- 产品仓库：https://github.com/blackdandan/fenleng-fridge；官网首稿同仓 `preview/website/`。
- 运营者：杭州临安芬棱软件设计工作室（个体工商户）；产品/域名/部署Owner由仓库Owner确认。
- 联系：promptmanager@163.com / 18234132630（来源见shared-platform-integration.md）。
- 域名：待定，不能把本地URL当作正式域名；不注册或部署。
- 法律源：`user-agreement.md`、`privacy-policy.md`；由 `scripts/build-preview-legal.mjs` 生成 `preview/shared/legal-content.js`，App/官网共用。
- 正式协议规划同域 `/terms/` 与 `/privacy/`；当前本地入口以官网实现为准。状态draft，无线上发布证据。
- 数据处理：同运营体系Shared Platform/Client SDK，反馈和分析处理要求见隐私政策；接入后需锁定SDK版本与实际清单，本轮无真实SDK、广告或支付接入。
- Android APK / Google Play / App Store：未发布，显示敬请期待；没有可用安装包时不提供下载链接。
- Canonical link：待域名确定后 `https://{产品域名}/app/`，官网首稿保留Web降级页；Associated Domains、Team ID、Bundle ID、AASA、assetlinks未配置，不声称唤起App可用。
- 芬棱门户：规划 `https://www.fenlengtech.com` 产品入口指向本产品官网；本轮不修改门户或登记表，状态planned。
- APP备案号、官网ICP备案号：均未核实，分别占位；不复制其他站点号码。

## 后续验收
确认产品名、域名与Owner → 定稿协议与真实SDK/处理清单 → 配置App级link/AASA及降级页 → 正式签名包与商店状态 → 发布官网及HTTPS/协议版本验证 → 门户挂载与登记证据。上述工程/发布项未因首稿完成而通过。
