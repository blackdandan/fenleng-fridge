# 区域与整理页阶段验收

Figma `b34I8tzPpU7tv1sHHdWLkq` 的2:44/2:99，沿用已批准稿。区域页恢复双按钮、原始相机SVG、三列记录和添加日期；整理页含编号、区域、添加日期、上次确认时间、详情及四种剩余状态。修改通过现有repository持久化，不创建正式演示数据。

整理页串行处理点击；保存失败显示本地化错误、保持原记录并允许重试。提醒页按最新同日提醒查询待整理记录，避免已打开页面遗漏同日新增记录。完成态、返回和撤销使用真实App路由测试，未选择记录保持不变。

## 验证

- App全部27项通过；本阶段inventory_pages 4项、review_flow 2项，包含真实路由/完成态/撤销。zone-430、review-430与既有home-430 golden通过。
- 20语言×2主题、320px宽、2倍文字布局检查通过。中文日期按稿使用MM.dd，其他语言保持本地化。
- 自有API35模拟器emulator-5580，430逻辑宽原生截图：区域8条与滚动后整理第8条可见；操作001“没了”后读真实私有库存确认落盘，002及其他记录不变；点击真实撤销后逐字段确认记录周期恢复。
- `../../evidence/android/inventory-ui-native-results.json`记录操作结果；截图为zone430-aligned-20261113及review430-{top,bottom,after-undo}-aligned-20261113。QA结束恢复原3条记录、nextNumber和420密度；临时照片仅用于QA。
- `../../evidence/android/inventory-ui-fidelity-sampling.json`：8处语义颜色采样完全一致；按钮原生语义边界、前4张卡片边界、返回/相机SVG墨迹边界与设计差异≤1px。

物理截图缩放有抗锯齿，按钮布局以原生语义边界衡量，同时保留精确RGB边界观察值；卡片分割容许最大2通道差值。平台字体字形仍有细微宽度差异，不能将上述采样称为整屏逐像素一致。测量脚本为check-flutter-inventory-fidelity.py。

APK SHA-256 `295f31b91285fa7301f386ccef8c23b46f38222dfeba70c841274c35406bb16b`。当前仅Android基准阶段通过；iOS/Harmony设备、其它页面、系统通知调度与完整WP03仍待完成。Widget完成态测试不是原生通知送达证据。
