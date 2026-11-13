# 设置与反馈阶段验收

沿用已批准的 Figma b34I8tzPpU7tv1sHHdWLkq：设置2:172，反馈草稿2:289、失败2:303、回执2:317。430基准、600限宽居中、系统文字缩放、Fenleng forest 主题与集中产品Token保持原契约。生产不复制原型的重置演示、时间模拟、演示徽章、演示控制或虚构回执。

## 实现与状态

SettingsScreen及其defaults/groups分片提供三区默认间隔、24小时时间选择、显式保存、失败保留输入及重试；数字支持非西文输入，范围1..3650。修改默认值只影响后续新记录，现有食材、当前due/cycle不改变。数字框表面76×35.6、时间表面38.2高，外层交互至少44；长文/大字/窄屏可换行和滚动。三个区域及clock使用原始Figma SVG，SHA与源节点登记于icon-assets.json。

历史/账号、外观/语言、协议/隐私/反馈分组接入真实路由。外观支持系统/浅/深，显式选择优先于OS；语言支持系统及20种自称，保存成功才更新界面，写入串行化且失败不污染下次尝试。Android SharedPreferences、iOS UserDefaults与OH Preferences实现display.theme；各端失败返回错误并恢复缓存旧值。FridgePage用实际主题驱动状态栏/导航栏图标，固定暗色相机仍保持暗色身份；返回SVG支持RTL镜像。

法律入口继续使用原生WebView。备案按钮置底、10px低强调，固定打开工信部查询地址；正式号码用FRIDGE_APP_FILING_NUMBER注入，未配置显示待登记，不套用其他产品号码。OH openLink使用官方UIAbilityContext API；仅做源码/API核对，未声称HAP运行：[官方参考](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-inner-application-uiabilitycontext/)。global渠道备案差异与撤回UI仍在完整WP03范围内待收口。

FeedbackScreen只渲染状态及回调，FeedbackSession管理加载/草稿/保存失败/提交中/失败重试/持久回执/再写一条。1..4000 UTF-16长度、重复提交合并，发送前先持久化随机幂等键；相同trim正文沿用键，正文变化换键。真实平台响应id与RECEIVED、以及本机回执落盘都成功后才清正文；失败保留草稿和键。草稿私有文件原子写，损坏文件保留证据并提示加载失败。关闭等待写入/提交结束，不把原始异常显示给用户。

PlatformFeedbackGateway消费官方FlutterFeedbackSDK，与官方身份客户端共用认证。无配置或无有效平台会话时如实失败，不制造回执。当前未完成游客客户端会话接入；反馈真实公网成功仍依赖WP05、正式登记与部署。真实契约和冻结commit见../../shared-platform-feedback-evidence.json。可选在线身份在feedback对象构造后后台恢复，离线首页不等待网络恢复。

## 验证证据

- 当前App全部51项通过，含9份golden；`.fenleng/flutter-settings-feedback-validation.log`。UI kit/settings/inventory/App lib/test的Dart analyze无问题。
- 新增FeedbackSession8项、实际官方SDK+本机HttpServer适配器3项、偏好/默认值4项、页面4项和真实FridgeApp路由1项。覆盖写盘失败、平台拒绝、异常2xx、重复提交、ACK后落盘失败、同意失效、离开/重开/重启、回执及再次反馈；本机服务器仅证明合同，不替代公网服务。
- 页面矩阵：20语言×2主题×320px×2倍文字，设置与反馈草稿/错误/回执共160种状态，无布局异常。语言资源132key的实际译文、变量和两端副本检查通过。
- Android完整业务验证包c99b7239395616e3a68a1fb6b01e1f119a8fb70abfc420c1211cca6590689e98：默认间隔7及09:15写盘，原食材/cycle不变；深色和英语重启恢复；未配置反馈保持草稿/键且无回执，重启重试沿用键；备案跳转Intent和320页尾可达。见settings-feedback-native-results.json。之后仅做视觉及可选身份启动顺序修正，新增源码路由测试通过，未把旧包哈希替换成新包。
- 最终视觉包74781b70c9f6464b99b0240728bb73aeb3dcecbc3368682e3b52e732aa733e05：已安装自有emulator-5580；430中文设置/页尾/深色/反馈草稿/空提交校验及320设置/页尾截图。settings-feedback-visual-results.json证明完成并恢复原3条食材、偏好、草稿和density420；脚本先核对已安装APK与本机hash一致。
- settings-fidelity-sampling.json：5处平整颜色差0、6处默认设置区块边界≤1px、5个原始SVG墨迹边界≤1px；12组文字记录原始数字。Android Noto CJK与Microsoft YaHei的小幅字形差异保留，不声称整屏像素一致。
- feedback-fidelity-sampling.json：3处平整颜色差0，输入框/按钮色块尺寸差≤2px，去掉34.4px原型演示徽章后边界位置差≤1px，5组文字已测。按钮顶部间距由24校正为26，尺寸44高。原型坏掉的文字返回替换为共享原始SVG；生产差异明确列出，不拉伸截图隐藏偏差。
- 数字门禁后生成settings-430和feedback-{draft,error,receipt}-430四份golden，既有五份回归通过。回执截图属于受控Widget状态，不是原生公网受理证据。
- mini同步132key和生成Token，typecheck与weapp构建通过；`.fenleng/mini-build-settings-feedback.log`保留common.js约297KiB及无异步块的webpack性能建议。该构建不证明mini完整设置/反馈已实现，亦无微信真机视觉证据。
- 项目知识审计`fl.cmd kno audit --project . --base HEAD`通过，nextAction为none；`.fenleng/settings-feedback-knowledge-audit.log`。本阶段未提交、push或部署产品/SDK/平台。

所有JSON报告及截图位于../../evidence/android/。iOS/macOS与HarmonyOS运行仍未验，完整WP03/WP05和整体项目保持进行中。后续包括游客反馈、隐私撤回、遥测、账号注销、完整通知及其他页面状态，不以本阶段代替最终验收。
