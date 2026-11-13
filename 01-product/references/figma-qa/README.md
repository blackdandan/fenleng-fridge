# App UI 逐屏截图复核

## 2026-11-13 设计修订

相机改为独立页面（无Dialog、无遮罩），保留返回、取景、相册、快门与完成。其余弹窗左右外边距16px；相机权限说明和拒绝提示距顶部16px，其余居中并保持上下至少16px。使用源样式重新排版，不缩放整张弹窗或字体。本次是Figma稿修订，原交互preview尚未同步此项新布局。18个主状态＋1个详情底部状态。


日期：2026-11-12。以当前 06-project/prototype/mvp / http://127.0.0.1:4173/ 为源，使用项目自带14条示例数据隔离核对，不覆盖用户浏览器原有库存。主画布统一为430px内容宽；网页外部桌面留白、浏览器滚动条与Figma采集工具条不纳入App稿。

逐屏查看源页面截图，从实际渲染校准可编辑的文字、图标、布局、颜色、边框与照片位置，并删除临时采集参考层。最终不是整屏截图作为填充，食材照片继续使用原始本地素材，正文/图标/表单保持原生图层。

修复重点：冷藏区照片及编号居中；入库相机图标；8条记录；编号/入库日期；三种区域记录数及小图标；拍摄快门/相册/数量；整理详情与四状态；设置分组及底部协议/反馈/备案；通知和历史入口；首进与权限弹层；反馈三状态；协议全文。另修复采集原生日期/时间控件时丢失的值，并补绘日历/时钟图标。

拍摄和详情弹层的首屏按源页面保留滚动裁切，19/20另显示真实滚动到底部的位置，避免把完成、保存、删除操作当成不存在。长页面PNG保留全部内容；contact-1至contact-4为缩略总览，不能替代原尺寸PNG。

主体文字保留源字体声明Microsoft YaHei；Figma服务端无法加载该本地字体，新补绘的日期/时间值使用Noto Sans SC。截图复核不等同于字体栅格化完全一致或逐像素差分通过。本轮未改变preview产品规则、原页面样式、库存或Shared Platform接入状态。

| 页面/状态 | 设计节点 | 完整PNG | 结果 |
|---|---|---|---|
| 01 · 首页 / 默认 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-2) | [截图](01-figma.png) | 已截图复核 |
| 02 · 冷藏区 / 库存 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-44) | [截图](02-figma.png) | 已截图复核 |
| 03 · 拍摄 / 独立页面 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-81) | [截图](03-figma.png) | 已截图复核 |
| 04 · 整理 / 四种剩余状态 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-99) | [截图](04-figma.png) | 已截图复核 |
| 05 · 详情 / 编辑与移动 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-149) | [截图](05-figma.png) | 已截图复核 |
| 06 · 设置 / 底部协议与帮助 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-172) | [截图](06-figma.png) | 已截图复核 |
| 07 · 通知 / 当前预览行为 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-216) | [截图](07-figma.png) | 已截图复核 |
| 08 · 历史 / 恢复 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-227) | [截图](08-figma.png) | 已截图复核 |
| 09 · 首进 / 协议说明 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-241) | [截图](09-figma.png) | 已截图复核 |
| 10 · Android / 相机用途解释 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-262) | [截图](10-figma.png) | 已截图复核 |
| 11 · 权限 / 拒绝与替代路径 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-275) | [截图](11-figma.png) | 已截图复核 |
| 12 · 反馈 / 草稿 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-289) | [截图](12-figma.png) | 已截图复核 |
| 13 · 反馈 / 失败重试 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-303) | [截图](13-figma.png) | 已截图复核 |
| 14 · 反馈 / 受理回执 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-317) | [截图](14-figma.png) | 已截图复核 |
| 15 · 首页 / 到检查时间 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-327) | [截图](15-figma.png) | 已截图复核 |
| 16 · 首进 / 暂不同意 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=2-373) | [截图](16-figma.png) | 已截图复核 |
| 17 · 用户协议 / 全文 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=4-65) | [截图](17-figma.png) | 已截图复核 |
| 18 · 隐私政策 / 全文 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=4-85) | [截图](18-figma.png) | 已截图复核 |
| 19 · 详情 / 底部保存与删除 | [Figma](https://www.figma.com/design/b34I8tzPpU7tv1sHHdWLkq?node-id=42-95) | [截图](19-figma.png) | 已截图复核 |
