# Flutter共享视觉组件

- FridgeLayout：430基准几何与字号策略的唯一入口，不承担业务状态。包裹在限宽600的Page内，无第二次全页缩放。
- FridgePage/HeaderIcon：共用SafeArea、标题、返回和动作区；同一页面宽度对齐；图标圆形视觉44、交互至少44，实际48基准。
- FridgeIcon：原始Figma SVG，本机静态资产，不用Material同义图标代替；正常主题保留原始颜色，深色映射到语义ink。大小/比例及SHA见icon-assets.json。
- FridgeFoodPhoto/MorePhoto：本机ImageProvider，圆形双层裁切、语义边框与微阴影；更多数量为虚线圆而非食材照片。不承担读取/上传/库存业务。
- FridgePalette/ProductTokens：已锁定Fenleng forest主题之上使用同一contracts/design-tokens.json生成Flutter/Taro产品映射，避免两端色值漂移。

flutter_svg固定2.2.4；SVG/基础Widget纯Dart渲染，不增加同意前的原生业务SDK初始化。官方包说明 https://pub.dev/packages/flutter_svg/versions/2.2.4 。

- FridgeAction/FridgeChoice：区域双操作及整理四状态，共享语义色、圆角和触控边界；区域按钮基准46px，选择至少44px。正文显式使用0字距，避免继承Material tracking后与设计偏移。
- FridgeDates：中文日期按已验收稿使用MM.dd，其它语言使用Material本地化短日期；确认记录带24小时制时间。
- 区域记录使用SliverGrid延迟创建，三列与文字实际高度共同计算行高；FridgeFoodPhoto按显示尺寸和DPR限制解码缓存，原始照片文件不改变。
- App photoLoader只提供呈现层ImageProvider注入，测试使用内存照片；生产默认仍为FileImage。不在正式库存注入示例记录。

- RecordEditor/record_editor_fields：可滚动的现有Dialog/Input/Button产品组合，覆盖默认、选择、保存中、错误、删除确认/取消、窄屏和大字。颜色使用editor/dialog语义族，尺寸来自中央Token；不直接访问存储或HTTP。
- HistoryScreen：既有Page/List/Card/Button产品组合，覆盖在库/历史、空、恢复中、失败与成功后的真实状态。FridgePage支持可选headerTop/titleGap以匹配历史页既有标题槽位，默认不改变其它页面。
- FridgeIcon新增calendar及editorChevron两份原始SVG，独立于相机selector；FridgeDates.editable提供中文年/月/日和其它语言本地化日期，统一24小时制。

- SettingsScreen/SettingsChoices：复用Page、List、Card、Input、Choice与Action；只渲染与派发，不承载IO。defaults/groups分片维持清晰职责；长值右对齐限宽160，标题弹性换行，箭头用单色Material north_east替代原型文本符号，避免Android彩色emoji。
- FridgeIcon新增settingsCold/settingsFrozen/settingsPantry/clock原始SVG；返回/相机返回支持RTL镜像。FridgePage以实际Theme亮度设置系统栏图标，显式深浅及固定暗色不受系统亮度覆盖。
- FeedbackScreen：Page/Form/Input/Action/Status组合，204.8高输入区、44高主动作、26顶部间距；大字自适应最小三行以上。加载/初始化错误/草稿/提交忙碌/失败/真实回执分别呈现，回执由外部状态提供。
- FridgeAction可按已批准页面指定字号及最小高度，默认仍46；FridgeChoice可指定字号。geometry/color/theme来自统一Token，触控最小44保持。
- CaptureScreen/controls/viewfinder：既有Page、Dropdown、Preview、Button、Status组合；纯props/回调，不持有CameraController或平台API。固定相机主题，方形真实预览槽与取景线，busy/pending串行门禁；宿主负责权限、原生预览和退出确认。快门单一语义节点提供tap/label/enabled，避免有标签的不可点击父节点。
- FridgeIcon支持明确保留原始SVG颜色；相机返回在固定相机背景保留导出色，其它默认主题映射不变。FridgePage可指定backIcon、原色开关和标题字重/行高，默认值保持原页面输出。

- RemindersScreen：Page/List/Card/Action组合，纯InventoryState+回调；保留原始量、独立待处理/部分/完成/空态，完成无操作。
- NotificationSettingsScreen/NotificationPermissionDialog：纯状态与回调，宿主负责权限和系统设置；解释Dialog独立FridgeLayout、顶部/两侧16；20语言/2主题/320px/文字2倍验证。
