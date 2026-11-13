# 详情与食材记录阶段验收

设计来源：Figma `b34I8tzPpU7tv1sHHdWLkq`，详情顶部2:149、滚动底部42:95、历史2:227；使用各精确节点的高保真上下文及截图。继续使用已批准430基准、600最大页面宽、系统字体缩放和Fenleng forest主题映射，不重新设计。

## 实现与行为

详情使用398×688基准可滚动Dialog，左右至少16px，包含拖动指示条、编号、关闭、120px本机照片、替换入口、完整日期时间、区域/间隔、下次提醒、规则说明、上次整理、保存及底部删除。窄屏和大字将区域/间隔改为上下布局，底部动作可滚动到达。原始calendar/editor-chevron SVG下载保存并登记hash；不复用相机页白色箭头。Flutter固定SDK的DropdownButtonFormField保留12px suffix margin，使用外层定位将原始10×6 SVG放入正确槽位，不修改SVG内容或宽高比。

保存、替换和删除串行处理，忙碌时禁止关闭/重复操作。日期/时间取消不提交局部值，永久删除需要明确确认；失败保留编辑内容并允许重试，用户只看到本地化错误。区域/间隔编辑不会覆盖当前提醒，保存后由现有repository持久化。历史页提供在库/历史数量切换、55px照片、编号/区域/添加日期/已移出、详情与恢复、真实空态；恢复成功由最新repository状态驱动，失败不会提前从列表移除。

## 独立验证

- `detail_history_pages_test.dart`3项：设计几何、原始图标有效尺寸、单次保存/失败不关闭、恢复去重/失败重试、20语言×2主题×320px×2倍文字、无历史空态。真实照片通过呈现层ImageProvider注入，正式首装不植入夹具。
- `detail_history_flow_test.dart`1项：真实FridgeApp路由，修改历史002的区域及阿拉伯数字间隔后当前dueAt/cycle不变，恢复生成新周期，001旧提醒独立保留；取消删除不变，确认永久删除只影响001。既有record_editor2项继续验证非法间隔、非西文数字及删除确认。
- Android完整业务链路包 `b55d3d40344bdf591d33982d046110406150f81e8ecd52de78dde23ea2b6374e`：读取真实私有inventory及backup，验证修改落盘/未选记录不变、新周期恢复、取消删除、永久删除同时清记录/备份/选中照片，以及320px可达删除。见 `../../evidence/android/detail-history-native-results.json`。此后仅做输入框/图标/文字/间距校准，不把旧包哈希改写为新包。
- 最终视觉包 `d264e7335f0b579d7da217ac8b7d68edac6220378d4eeece876bf144ec713800`：430详情顶部/底部/历史及320详情截图复核；见detail-history-visual-results.json。两次QA均恢复原3条记录、nextNumber与420密度，只清理QA自有照片。
- 最终数字采样 `../../evidence/android/detail-history-fidelity-sampling.json`：9处平面颜色差0，详情四输入区/保存按钮、历史tab/选中段/卡片边界差≤1px；两处calendar墨迹边界差0，editor-chevron≤1px。指示条、关闭圆、照片、14组文字也记录了位置和尺寸。
- 同态原生图在 `../../evidence/android/`，以detail430-{top,bottom}-20261113-fidelity、history430-20261113-fidelity命名。详情只消除原生窗口高度导致的整体居中位移，再按Dialog局部坐标比较；未拉伸Dialog。字段使用最大连通色块，避免缩放时文字周围孤立过冲像素被误当作输入框边界。
- 数字门禁通过后更新detail-430与history-430 golden。Golden证明回归稳定，不替代Figma对照；最终全量结果见implementation-status.json。
- 最终App全部31项（含5份golden）通过，Dart analyze无问题；20语言101key及变量/两端副本一致，mini typecheck与weapp构建通过。项目知识审计pass，nextAction为none，日志`.fenleng/detail-history-knowledge-audit.log`。

## 范围限制与后续

Android系统字体与Microsoft YaHei仍有小幅字形宽度/基线差异，采样报告保留原值，不声称整屏像素一致。原生系统日期/时间选择器未仿造Web控件。iOS/Harmony运行、完整设置/反馈/通知调度、其余页面及完整WP03尚未完成，索引保持🔶。

替换照片的旧文件回收和保存失败后的候选文件清理需在WP04继续收口；当前没有把这项未验证行为当作已完成。源码入口：RecordEditor、record_editor_fields、HistoryScreen与app_routes，公共视觉参数来自contracts/design-tokens.json。
