# Epic Plan: [Epic 名称]

- **状态**: [Pending / In Progress / Completed]
- **关联需求**: [指向 PRD 或 Issue 的链接或简要文字说明]
- **首次创建时间**: YYYY-MM-DD
- **最后更新时间**: YYYY-MM-DD
- **效率审计目录**: `docs/ai-coding-audits/[EPIC-ID]/`
- **用户审批**: `Adjustment`（用户明确回复 `spec approved` 前不得开始任何 Work Package）

---

## 🏛️ 架构设计与分层拓扑 (Clean Architecture Align)
<!-- Planner 必须在此说明本次 Epic 涉及的整洁架构分层，并画出数据流向拓扑 -->

```
        ▲  【外层：Frameworks & Drivers】 (UI, DB 驱动, 网络库)
        │
        ▼  【中层：Interface Adapters】 (Controllers, Presenters, Gateways)
        │
        ▼  【内层：Core Business Logic】 (Use Cases, Entities/Domain Model)
```
* **核心业务实体 (Entities)**: [例如: User, Account]
* **业务用例 (Use Cases)**: [例如: RechargingWallet, FetchingTransactionHistory]
* **依赖关系约束**: 依赖只能**从外向内**。外层的 `UI / Database` 变化不能影响内层的 `Domain / Use Cases`。

---

## 📋 串行 WorkPackage 规划 (自内向外演进)
<!-- 拆解 of WP 必须遵循“自内向外（从核心领域到外围 UI）”的串行构建顺序，确保后一步永远拥有稳定的内层依赖 -->

### ➡️ WP-001: [Domain & Use Case 核心业务逻辑层]
- **整洁架构归属**: `Core Business Logic (Entities & Use Cases)`
- **状态**: [Pending / In Progress / Completed]
- **涉及目录**: [例如: /domain/model/, /usecases/]
- **职责范围**:
  - [ ] 必须做: 定义核心实体与业务流接口（纯 Kotlin/Java/Python 逻辑，不包含任何 DB、Spring、Compose 等三方框架代码）。
  - [ ] 不能做: 绝不编写具体的 UI 界面、数据库 SQL 语句。
- **交付产物**:
  - [ ] 代码修改: (留空，待完成)
- **验收方式**: 纯 JUnit 单元测试验证核心业务规则。

### ➡️ WP-002: [Interface Adapters 适配器层]
- **整洁架构归属**: `Interface Adapters` (Repository 接口实现, Controllers)
- **状态**: [Pending]
- **涉及目录**: [例如: /adapters/db/, /adapters/web/]
- **职责范围**:
  - [ ] 必须做: 实现数据库读写、外部 API 请求序列化，将内层的 Use Cases 与外部数据库/网络桥接。
  - [ ] 不能做: 绝不直接在 Controller 里写核心业务决策逻辑。
- **交付产物**:
  - [ ] 代码修改: (留空，待完成)
- **验收方式**: 模拟外部 DB/网络请求的集成测试验证。

### ➡️ WP-003: [Frameworks & Drivers 外部表现层]
- **整洁架构归属**: `Frameworks & Drivers` (UI 界面与三方框架整合)
- **状态**: [Pending]
- **涉及目录**: [例如: /ui/view/, /ui/compose/]
- **职责范围**:
  - [ ] 必须做: 实现具体的 UI 页面、交互逻辑、并绑定适配器。
  - [ ] 不能做: 绝不在 UI 代码中编写或决定业务决策逻辑。
- **交付产物**:
  - [ ] 代码修改: (留空，待完成)
- **验收方式**: UI 自动化测试或人工视觉验收。

---

## 📈 Epic 完成效率审计

只有所有 Work Package 已验收并合并后，使用本 Skill 的 `assets/epic-efficiency-audit/` 生成：

- `docs/ai-coding-audits/[EPIC-ID]/audit.md`
- `docs/ai-coding-audits/[EPIC-ID]/metrics.json`
- `docs/ai-coding-audits/[EPIC-ID]/evidence.md`

审计必须识别无效 Token/成本、重复上下文、无效验证、返工与冲突；不得以减少测试或降低验收标准伪造效率提升。
