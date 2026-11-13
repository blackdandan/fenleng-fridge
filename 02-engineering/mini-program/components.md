# 共享组件与规范绑定

Fenleng 规范基线 `069718f51642df16e5c80c757943ce03621fd4a0`；已读 design-system 与 mini-program 规范的证据见 design-system-evidence.json。目标 forest 主题，所有 Figma 产品覆盖集中在 `06-project/contracts/design-tokens.json`；生成器同步 Taro TypeScript Token Map 与 SCSS variables。

| 组件 | 目录职责对应 | 状态与约束 |
|---|---|---|
| FridgePage / PageFrame | App Shell / 页面骨架 | 实际宿主安全区，系统字体缩放、RTL、light/dark/system；业务由 Controller 驱动 |
| HeaderAction / ActionButton | Button | 默认/按下/禁用/无障碍；原始 SVG 根尺寸与 Figma 对齐，视觉44、触控至少44物理像素 |
| FridgeDialog | Dialog | 居中或顶部，16物理像素 margin，长文滚动，独立相机页不套弹窗 |
| RoundPhoto | Avatar / 数据图片职责 | 真正本机照片，圆形裁切、失败文本；不以示例照片替代缺失数据 |
| CabinetView / RecordsView | 数据展示组合 | 显式空态、数量、更多；只渲染 Application ViewModel，不承担业务变更 |
| ConsentView | 隐私门禁组合 | 同意先持久化再打开库存；拒绝和阅读返回不创建业务存储/平台会话 |
| CameraView | 媒体采集组合 | 原生预览插槽与 capability adapter；处理权限、初始化、忙、失败、重试、完成 |

Root App 仅负责 Provider/生命周期，所有可见容器落在真实 Taro Page 内，避免 App render 根被宿主忽略。保真采样、自动截图回归、开发者工具验证和真机验证分别登记，不互相替代。

- RecordEditorView：复用Dialog/Action/Photo/Icon和原生Picker/Input，独立ScrollView，纯状态/事件；RecordEditorPage负责应用层装配。日期图标原始根尺寸放16槽，不拉伸。
- HistoryView：Page/Tab/Card/Photo/Button组合，在库/历史/空/错误/忙碌与恢复数量随仓库变化。
- SettingsView/SettingsChoices：Page/Form/Input/Picker/List/Action组合；默认值草稿、保存结果、20语言/外观、协议/反馈/备案。所有几何/色彩来自现有Token；原生截图未验收。
- FeedbackView：Page/可见标签/Textarea/说明/Action/错误与回执，复用现有反馈Token和20语言文案；只消费状态与回调，SDK和持久草稿在外层。源码/构建通过，微信原生字体、键盘、放大文字与RTL未验。
