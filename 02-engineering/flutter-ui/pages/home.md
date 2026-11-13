# Flutter首页实现与证据

Figma准节点2:2，最新高保真上下文和截图已读取；实际UI使用原始SVG，食材图来自ImageProvider。首装InventoryState保持空，不注入示例数据。参考场景照片只用于自有隔离模拟器的临时QA状态。

## 结果与范围

修正整列放大照片导致冷藏过高的问题；430基准主照片66、冷藏271、下层161、柜体约455，主网格固定83槽位/13行距，溢出第6格展示+数量。冷藏/冷冻把手、柜脚、分层圆角、细边框和照片阴影均按稿落到Token。

Page统一标题和内容的限宽/居中，正常首页25字号；原始图标22和区域图标15，图标视觉44圈与最小44触控分别处理。原生SafeArea替代模拟系统栏。字号在窄屏不缩小，文字放大使卡片长高并可滚动。新增真实到期/2天未整理提示及全部食材整理入口。

修复照片内层圆形裁切，明确箭头为Unicode文本呈现，避免Android自动彩色emoji。Flutter与Taro共用同一个contracts/design-tokens.json源，Flutter主题仍建立在锁定Fenleng forest包上。

## 已执行

- App全部21项测试通过；新增首页4项含430尺寸/溢出、320×20语言×浅深主题×2倍文字、宽屏竖横屏限宽600/居中、空态/到期入口。
- 已验证实际图像解码成功与44触控；Widget golden home-430.png固定在同一测试，回归通过。golden使用确定性单像素测试图和测试字体，负责布局/组件回归，不冒充设计照片/原生字形证据。
- Dart analyze覆盖ui_kit、feature_inventory、App lib/test，无问题。
- Android固定签名debug构建、安装成功；当前APK SHA256 e36623f180d9c132cd0d6e357a72527f4da80d6b951144492e2c4a915a818556，签名身份保持原值。
- 自有fridge_api35/emulator-5580上以430、320、800逻辑宽复核。最终截图为../../evidence/android/home-figma-{430,320,800}-proof-20261113.png。430归一化截图为home430-proof-normalized.png，排除真实状态栏并对齐设计模拟45px系统区。
- home430-fidelity-sampling.json：六处语义颜色最大通道差0，四个柜体区域边界差<=1px，两个标题SVG图标的可见墨迹尺寸一致，标题可见边界最大差1px。颜色分割限制在对应Figma节点邻域，避免其他动态照片同色像素污染bbox。
- 430与320和800截图逐一查看，照片、+3、数量、把手、柜脚和单色箭头正常。原生字体为Android CJK，Figma为Microsoft YaHei，记录实际字形差异，不把字体名字当像素一致证据。

## 复现与恢复

运行06-project/scripts/qa-android-home.py：固定专用AVD/serial，并要求原本3条QA记录，否则拒绝。依赖.fenleng/figma-home-fixtures中来自本次Figma上下文的原始照片导出；这些文件不进入App assets。脚本先持久备份两份inventory JSON，再临时构造8冷藏/3冷冻/3常温状态，finally恢复原本记录和nextNumber、删除自有qa-figma文件、reset density；本轮已核对恢复成功。异常中止时从同目录original-inventory.json/original-inventory.backup.json恢复两份文件；恢复入口保留可发现。

运行python 06-project/scripts/check-flutter-home-fidelity.py重建归一化图和数值JSON；状态栏默认136物理px属于本AVD设置，其他设备应显式传--status-top。APK哈希随报告计算，防止把旧截图当新构建证据。这个脚本仅检验首页明确列出的块，不能证明整App或其它端完成。

原生空库存补验：同一最终APK临时构造0记录/nextNumber1，实际截图home-figma-empty-430-proof-20261113.png与归一化home-empty-proof-normalized.png已逐一查看；三个区域仅有居中加号/拍照入库，无记录数、示例照片、整理卡片或教程。通过qa-android-home.py --empty-only复现；流程结束已恢复原本3条QA记录和density420。这里是空库存UI复现场景，真正首装的初始化语义另由bootstrap/domain测试证明。

## 待后续

iOS真实字体/设备、Harmony运行未验，按Owner约定交接；区域/整理/详情/设置/历史/反馈仍需逐屏对齐，通知调度与平台功能尚未完成。WP03和完整Epic保持进行中。
