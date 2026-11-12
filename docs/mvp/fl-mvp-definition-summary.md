# V0.3 产品修订交付记录

用户2026-11-12授权7项本产品修订，之后明确取消单独产品分析开关。权威文档MVP.md已同步；两份协议草案使用组织资产主体与联系方式，App/官网预览共享生成正文，源文件修改后运行 `node scripts/build-preview-legal.mjs`。

交付：产品规则、流程、状态、验收与事件目录；首进协议、Android拍摄解释、反馈与游客身份模拟、设置底部备案；独立官网首稿和法律页。采用MVP PreviewDeveloper分工，分别实现App/官网后主Agent复核。未修改base通用工作流、上游平台或SDK；未提交、推送、部署。

验证：库存全回归/V3定向测试/官网静态检查PASS；CUA复核首进与相机解释，官网390/625/1280及政策全文。新增UI按已读语义主题和文字/触控规范局部调整，未声明全面设计系统合规。

已确认反馈API及SDK封装；本地与远程OpenAPI均未找到游客会话创建路径。正式接入存在上游依赖，详见shared-platform-integration.md。预览的身份/反馈/分析均本地模拟，不发送真实数据。产品名、域名、备案号和法律生效日期待定；两份协议为草案，拟定保存期仍需实际服务配置核对。

MVP未结束；用户最终审阅待完成。通知V0.2.2与空冰箱实现/验收仍单独追踪。本轮未要求Figma稿，不生成或宣称已交付Figma Prompt。

拟稿参考：[个人信息保护法官方全文](https://www.samr.gov.cn/wljys/gzzd/art/2023/art_3ef1e889c1e644d4b65b5f5c7f432386.html)、[Android权限请求官方说明](https://developer.android.com/training/permissions/requesting)。产品选择与平台实际能力以本仓库需求和集成证据为准。
