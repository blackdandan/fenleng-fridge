# <模块名> Figma ↔ Spec ↔ 小程序代码 映射

> 本表是本模块小程序 UI 开发的执行主线（索引层）。
> 只记录“做什么”和“在哪”；实现方法、截图和验收规则统一走 `fl-figma-mini` Skill。

---

## 〇、本包文档结构

```text
docs/mini-program/
├── figma-map.md         ← 页面索引（一屏一行）+ 共享组件指针
├── components.md        ← 跨页复用组件清单
├── backlog.md            ← 缺 node-id、截图入口、资源或 spec 缺口
├── pages/
│   ├── <main_page>.md
│   └── ...
└── <spec 目录>
```

状态：`✅` 完成 / `🔶` 进行中 / `⬜` 待做 / `⏳` 整页占位。

推进类型：`🤖` 可自行实现并完成当前可用门禁 / `🧑` 需要人工决策或外发授权。

---

## 一、页面索引（一屏一行）

| 页面/屏 | 整屏 node-id | 路由/入口 | 变体/状态 | spec | 代码入口 | 截图 profile | 采样/回归 | 推进 | 状态 |
|---|---|---|---|---|---|---|---|---|---|
| **<主页面>** | `TODO` | `<route>` | 默认、加载、空、错误 | `<spec.md>` | `<apps/miniapp/src/pages/main>` | `<device-profile>` | `TODO` | 🤖 | 🔶 |
| <二级页 1> | `TODO` | `<route>` | — | `<spec.md>` | `<apps/miniapp/src/pages/detail>` | `<device-profile>` | `TODO` | 🤖 | ⏳ |

---

## 二、共享组件

→ 详见 `docs/mini-program/components.md`。记录组件源码入口、Figma 组件/node-id、支持状态、Token 和已覆盖页面。

---

## 三、待补 / 阻塞项

→ 详见 `docs/mini-program/backlog.md`。缺 node-id、缺截图入口、字体/图标/图片资源、原生能力适配和 spec 缺口都登记在这里。

---

## 四、页面明细最低字段

每个 `docs/mini-program/pages/<name>.md` 至少记录：

- 页面入口、测试数据或状态构造方式；
- Figma 当前准 `node-id` 与直接子节点覆盖清单；
- TSX/组件、Token/WXSS 生成目标、JS/TS 状态入口；
- 设计基准宽、设备 profile、DPR、安全区和系统区域裁切；
- `compare`、`point`、`glyph`、`bbox` 或 `sxs` 采样证据；
- 截图回归、开发者工具和真机复核结果；
- 未验证项、阻塞项和需要人类决策的事项。

---

## 五、变更联动

每次改本文件、`components.md`、`backlog.md` 或 `pages/` 任一文件后，检查：

1. 页面索引行是否要增删改；
2. 共享组件是否新增、重构或影响其他页面；
3. backlog 是否有解锁项要删除，或有新阻塞要增加；
4. 截图 profile、测试数据和状态覆盖是否仍然有效。
