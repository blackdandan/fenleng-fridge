# 微信小程序 Figma 实施索引

范围来自 Owner 已验收的完整设计与持续实现授权，优先完成首页/入库/库存/整理，再补详情、设置、通知、历史、身份及反馈。按现有工程资产结构放在 `02-engineering/mini-program`，对应 Skill 的 docs/mini-program 索引职责，不另建平行 docs 根。

Figma 文件 `b34I8tzPpU7tv1sHHdWLkq`。基准430px；原图内10:00等模拟系统区域不进入正式实现。微信 status bar/capsule 单独由宿主实际尺寸处理；同态对比先裁除两端系统区域。Taro designWidth=430、deviceRatio=750/430；样式由编译器转 rpx，真实系统边距/最小触控使用明确 Px。原生图片为动态本机记录，不把设计示例图片塞入首装库存。

会话 `f32af4c2-d29f-4ff5-a991-527e3bee78da` 已按节点读取高保真上下文与截图；使用 `figma-design-to-code`，静态图标从响应 URL 下载到 src/assets/icons。本机未发现已安装微信开发者工具；构建、领域/适配层与布局初检不能充当开发者工具或真机视觉验收。

| 页面/状态 | node-id | 行为 spec | 实现 | 状态 |
|---|---|---|---|---|
| 首页 / 正常与空柜体 | 2:2 | MVP/空状态、WP02/03 | ui-kit inventory-views、index | 🔶 真实状态接线中；未跑原生截图采样 |
| 区域 / 入库与整理等宽、三列记录 | 2:44 | MVP/主流程 | ui-kit inventory-views | 🔶 已读取；构建与视觉待验 |
| 相机 / 独立页、相册、多选与区域 | 2:81 | WP04、capture-session | camera-view、camera-page、WeappMedia | 🔶 已读取；真实原生适配，未验设备 |
| 首进协议 / 拒绝与阅读返回 | 2:241、2:373 | WP03、V0.4 | ConsentView、PageFrame、Preferences | 🔶 中国首进门禁；离线正文与发布后WebView入口 |
| 相机用途 / 拒绝替代 | 2:262、2:275 | WP04 | CameraView 顶部说明 | 🔶 源说明已具备，节点专项采样待做 |
| 整理 / 四种状态 | 2:99 | WP02提醒闭环 | ReviewView、controller / 单条确认、持久化、撤销 | 🔶 源码/行为测试/build通过；原生保真待验 |
| 详情 / 修改、替换、删除 | 2:149、42:95 | WP02数据与删除 | RecordEditor/Page/View | 🔶 周期/失败重试/照片引用测试与build通过，原生保真待验 |
| 设置 / 默认、语言、协议、反馈、备案 | 2:172 | WP03/05 | SettingsView/Page/Choices、原子显示偏好 | 🔶 默认/显示/法律/备案和真实反馈页接通，原生截图待验 |
| 通知 / 原始与待处理数、完成态 | 2:216 | WP02/04/06 | RemindersView、reminderModels | 🔶 列表与整理闭环已接；后台消息未完成 |
| 历史 / 恢复 | 2:227 | WP02 | HistoryView/Controller | 🔶 数量/切换/详情/恢复/失败重试接通，原生保真待验 |
| 反馈 / 草稿、失败、回执 | 2:289、2:303、2:317 | WP05 | FeedbackSession/View/Page、官方Taro SDK、共享游客会话 | 🔶 草稿/幂等/回执/关闭与真实本机HTTP测试、build通过，原生视觉待验 |
| 法律全文 | 4:65、4:85 | V0.4 正文真相源 | RichText 离线读本；正式域名配置后 WebView | 🔶 未做原生视觉验收 |

不得把进行中行标成✅。其余原始19屏截图与链接见 `01-product/references/figma-qa/README.md`。正式 AppID、业务域名、隐私声明与设备验收仍由 Owner 后补，生产代码不得伪造登录或消息结果。
