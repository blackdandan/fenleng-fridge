# 独立拍摄页阶段验收

2026-11-13 权限说明保真增量：重新读取 Figma 2:262（会话 efdbd4d6-3da8-40ae-a31d-b7ec17b005d2）的高保真上下文与截图，补齐右上关闭按钮；修正 page 背景/ink/scrim、20/16/15字体角色、23/22/30间距和两枚49.6高次操作，复用FridgeAction与集中Token。Dialog仍在原生安全区下方留16px，并随文字滚动。关闭与暂不拍摄返回cancel，相册和继续申请返回独立意图，不提前申请系统权限。20语言×2主题×320宽×2倍文字及四种动作的两项Widget测试、定向analyze通过。

新固定签名Debug包7b790718...在独立API35模拟器原生截图430/320通过。430精确色值采样：背景/主按钮/次按钮/关闭底色一致，归一化边界最大差1.801逻辑px；关闭字形差2.085px单独记录为Android系统字体与Microsoft YaHei差异，不把它称为完全像素一致。原生24px状态栏使用实际60物理像素Insets证据归一化。动态背景为真实相机页，未复制设计稿示例食材。图与数值见 ../../evidence/android/delivery-current/；系统相册替换全过程也已验证（功能包eaff8aae...），更新了此前“尚未验证”的Android项。完整首进/法律等状态、iOS/Harmony与正式发布仍不由本条证明。

设计基准：Figma b34I8tzPpU7tv1sHHdWLkq 的2:81，高保真上下文与截图；同态参考01-product/references/figma-qa/03-figma.png。继续沿用430基准几何、600限宽、系统文字缩放和至少44触控。原型示例面包是动态相机内容，生产接入真实CameraPreview；演示徽章替换为真实「照片与库存仅存本机」，不显示不会开启摄像头的演示描述。

## 实现与区块覆盖

CapturePage保留相机生命周期、权限协调、待保存照片退出确认，向纯呈现CaptureScreen注入真实预览与回调。屏幕按controls/viewfinder拆分，均低于300行；业务库存动作分离至bootstrap的inventory_actions分片，不改变动态方法调用。共享FridgePage允许原始相机返回SVG、相机标题字重/行高，默认行为不影响其他页。

| 顶层块 | 实现与证据 |
| --- | --- |
| 背景、标题、返回 | 固定camera主题#263c2c，与系统/用户主题无关，系统栏白图标；22px原始camera-back保持导出颜色，标题500字重；原生墨迹及Widget主题/系统栏断言 |
| 本机说明 | 原稿22.4高徽章槽位保留，显示真实数据边界；颜色/边框来自cameraTag族，位置与尺寸测量，文案改变故宽度不强行相等 |
| 区域选择 | 44.4高、原始10×6箭头、真实PopupMenu选项；长语言自动长高，不压缩文字。数字采样校正箭头末端间距至4.6；触控作用于整个选择区 |
| 预览、取景线、说明 | 382方形viewport，对比参考380.4差异来自原型428.4外壳；真实sensor图用FittedBox.cover居中裁切，不拉伸。内嵌17间距、346.4方形引导框、底部提示；半透明描边由真实像素合成，不伪称与示例照片同色 |
| 相册、快门、计数 | 原始22px相册SVG；69px快门和4px边框、真实本次计数。未就绪或busy/pending禁拍，busy/pending禁相册和完成，已有pending可重试；区域改变只影响以后获取的照片 |
| 补充说明、完成 | 原稿双行本机说明、底部完成动作，内容可整体滚动；小屏/大字可到达。不可用预览自身允许滚动阅读长错误，页面外缘仍可滚动到完成 |
| 未授权/不可用/失败 | 加载、相机不可用、打开系统设置、重试、保存失败和pending状态；相册不依赖相机授权。Android解释弹窗顶部及左右16px，暂不拍摄不触发系统请求 |

SVG已按当前2:81的3个资产URL重新curl下载，SHA与仓库既有文件逐字节一致；见icon-assets.json的cameraSourceNode/verification，未重画或修改SVG。快门无障碍树曾把标签与点击拆为两个节点，现以单一Semantics合并tap/label/enabled并排除重复子语义；Widget测试和Android实际点击验证。

## 独立验证

- Capture页面3项：基准方形/区域框/快门几何、3个SVG有效尺寸、原始返回色、guide尺寸、标签与caption语义色、固定暗色及系统栏、单一快门语义点击、实际选区回调；busy/pending禁用，未授权保留相册/系统设置；20语言×两种宿主主题×320×文字2×ready/unavailable/failed，共120状态。
- 原生完整业务包ea64ffb8ccf4927507525519ec7a7cfd7bb2851528b6825281beb0b03246da3a：两个真实sensor照片，004冷藏/005冷冻，004与原3条记录不因切区改变；私有照片非空、编号连续、重启保持。启动只删除自建无引用.image/.pending，保留现有引用和非规则文件。撤销相机权限后先出现应用解释，暂不拍摄后相册/系统设置仍可用。见camera-native-results.json；全部恢复原3条记录、照片、授权和density420。
- 最终视觉/结构包及已安装hash见camera-visual-results.json：仅在原生业务验证后校正箭头/原始返回色并拆分源文件；430顶部/完成、320顶部/完成均已观察，原数据和授权恢复。没有把业务包hash换成最新hash冒充重跑业务链路。
- camera-fidelity-sampling.json：3处平整色值差0，区域/预览/快门填充与边框≤2px，3个SVG墨迹≤2px，完成按钮局部尺寸≤2px；7组文字保留原始墨迹数字。细字/半透明边框的两处最近色独立记录，不和纯色平面门禁混称一致。解释弹窗从native136状态栏之后测得顶部/左右约16px，引用其实际业务包hash。
- Figma采样后生成camera-430 golden（受控灰色预览槽，非原生相机内容），既有9份回归通过。当前App全量57项、10份golden、核心领域/磁盘15项通过；Dart analyze无问题。日志.fenleng/flutter-camera-{validation,page-validation,analyze,goldens}.log与dart-core-camera-validation.log。
- 两端语言资源133key校验通过；mini typecheck和weapp构建成功，.fenleng/mini-build-camera-ui.log保留common.js约298KiB及无异步块的webpack性能建议。mini本轮只同步Token/新增区域句式，不把它当成微信真机视觉验收。
- 项目知识审计`fl.cmd kno audit --project . --base HEAD`通过，nextAction为none；`.fenleng/camera-knowledge-audit.log`。本阶段未提交、push或部署。

本机照片替换的失败清理/旧文件引用保留与重启回收见../../specs/photo-lifecycle-evidence.md，当前已纳入APK并验证启动回收。系统相册替换全过程仍需专项原生验证；iOS/macOS和Harmony工具链/设备未验。相机解释的16px约束通过，不等于其他同意/法律/权限设计状态已全部对齐。

完整WP03/WP04仍在进行中：系统通知/完整提醒UI、剩余权限及同意状态、三端设备等继续实施。无真机、无Xcode、无HAP时不冒称验证完成。
