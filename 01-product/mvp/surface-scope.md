# 产品端侧范围 · V0.4 工程交接

| Surface | 首版目标 | 当前未交付 |
| --- | --- | --- |
| App | Flutter Android/iOS/HarmonyOS NEXT 三端 | 原生工程、真实权限/提醒/身份/反馈/分析、安装包与设备验收 |
| 微信小程序 | Taro/React/TypeScript，仅 weapp | 工程、平台身份、图片持久化、提醒能力决策及真机验收 |
| 官网 Web | 静态网页，域名 fridge.fenlengtech.com | DNS/HTTPS验证、部署、备案、正式下载与真实分析 |

不开发 Web 库存客户端或工作台；不建产品后端，复用 Shared Platform 既有能力。无独立分析开关，无账号密码注册页、购物清单、云同步、食材识别、付费或广告。照片留在设备。

官网/App/微信的协议沿用同一法律源，在正式接入时核实平台差异与清单。Android 先显示顶部权限解释再申请相机；拍摄独立成页。微信后台提醒不能视作 App 本地通知的等价实现，差异与待决策项见 `../handoff.md`。
