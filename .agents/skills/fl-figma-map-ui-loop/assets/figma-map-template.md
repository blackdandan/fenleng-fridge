# <模块名> Figma ↔ Spec ↔ 代码 映射

> **本表是本模块 UI 开发的执行主线（索引层）。**
> 维护原则：**瘦**——只放"做什么"和"在哪"，不写"怎么做"。
> **"怎么做"统一走 skill**：`fl-figma-map-ui-loop`（该 skill 的 `SKILL.md`，本表不复述方法论）

---

## 〇、本包文档结构

```
docs/
├── figma-map.md         ← 本文件：页面索引（一屏一行）+ 共享组件指针
├── components.md        ← 跨页复用组件清单
├── backlog.md           ← 项目级待补 / 阻塞项（缺 node-id / 待原生侧补 / spec 缺口）
├── pages/
│   ├── <main_page>.md       ← 主页面卡片明细
│   ├── <detail_page_1>.md   ← 二级页 1
│   └── ...                  ← 更多二级页
└── <spec 目录>             ← spec 仓库（产品/设计 维护）
```

**规则**：行 = 交付物，不是 = 节点。具体登记规则见 `SKILL.md` §一。
**状态**：`✅` 完成 / `🔶` 进行中 / `⬜` 待做 / `⏳` 整页占位（开发未启动）。
**推进类型**：`🤖` loop 能自己到达+自验（纯 Flutter golden，**或**原生 `adb screencap`+采样）/
`🧑` 仅真要人拍板（原生 vs Flutter 选型、spec 真缺口、commit）。缺 factory/node-id = backlog 阻塞，非 🧑。
（默认绝大多数行 `🤖`。详见 `SKILL.md` §一/§二。）

---

## 一、页面索引（一屏一行）

| 页面/屏 | 整屏 node-id | 路由 | 变体/状态 | spec | 明细见 | 推进 | 状态 |
|---|---|---|---|---|---|---|---|
| **<主页面>** | `TODO` | `<route>` | <变体/状态> | `<spec.md>` | → `pages/<main_page>.md` | 🤖 | 🔶 |
| <二级页 1> | `TODO` | `<route>` | — | `<spec.md>` | → `pages/<detail_1>.md` | 🤖 | ⏳ |

---

## 二、共享组件

→ 详见 **`docs/components.md`**（卡壳、tab、全屏入口、通用骨架 等）

---

## 三、待补 / 阻塞项

→ 详见 **`docs/backlog.md`**（缺 node-id、待原生侧补 bridge view、spec 缺口）

---

## 四、变更联动

每次改本文件 / components.md / backlog.md / pages/ 任一文件后，**主动检查**：
1. **页面索引行**（§一）是否要增删改（页状态/变体变了）
2. **components.md** 是否有新增/重构的组件
3. **backlog.md** 是否有解锁的项要删、新阻塞要加
