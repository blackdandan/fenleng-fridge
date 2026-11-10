# 离线检索与 FL 映射

## 定位和执行

脚本路径相对本 Skill，不相对业务项目的工作目录。支持 Python 3.9+，Windows 通常使用 python，其他宿主使用可用的 python3。若没有 Python，只做明确标注的人工分析，不声称跑过检索。

三个独立查询示例（使用已定位的脚本绝对路径替换 SEARCH）：

```text
python SEARCH "document scanner productivity" --design-system --json
python SEARCH "keyboard focus modal" --domain ux --json
python SEARCH "responsive adaptive layout" --stack flutter --json
```

领域：product、style、color、typography、google-fonts、landing、chart、ux、icons、gsap、react、web。栈支持由 --help 返回，包括 Flutter、React、Next.js、HTML/Tailwind 等；没有 Taro 专用库时使用 web/ux 通用结果并明确限制。

--variance、--motion、--density 是上游 1–10 候选生成参数；FL 实际间距仍映射到 Standard/Compact。可用 --max-results 1–20 控制领域/栈结果数量。脚本每次从受版本管理的压缩包解压到系统临时目录，执行原版引擎，再清理该临时目录；不向接入项目写入缓存。

## 候选到实现的映射表

每次系统级设计在项目已有设计记录中保存：

| 候选 | 判断依据 | FL 实现 | 未采用原因 |
| --- | --- | --- | --- |
| 产品/行业类别 | 返回的 product/reasoning identity，是否真实匹配 | 当前页面目标及页面 Profile | 不把营销落地页当应用首页 |
| 色板 | 主色/强调色承担的语义 | action.primary、content.primary 等已验证 Token | 品牌/对比度不匹配则保留已有主题 |
| 字体组合 | 中文覆盖、许可证、平台加载成本 | 已有 Typography Profile/字体配置 | 不静默安装或下载字体 |
| 构图 | 内容优先级、主任务、首屏焦点 | 可复用组件与响应式结构 | 单列卡片不能表示所有产品 |
| 动效 | 反馈/状态变化的目的 | duration/easing Token 与 reduced motion | 不因搜索返回 GSAP 就引入依赖 |

已有 FL Token 不足时：先提出集中主题/组件扩展方案及现有授权依据。若用户已授权品牌或设计系统调整，可按对应契约实现并验证；否则记录待决项。不能用页面私有颜色补洞，也不能把所有新方向都无条件压回默认蓝。

## 分清证据等级

- 检索命中证明资料可用，不证明页面美观。
- 类型/主题/状态检查证明契约合规，不证明实际布局无裁切。
- 视觉通过必须有实际渲染或 Figma 截图，记录视口、主题、状态及发现后修正的问题。
- 重设计使用同内容、同视口的前后图；保留主路径、内容、键盘操作和事件接口。
