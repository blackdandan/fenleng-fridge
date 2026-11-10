# Clean Architecture (整洁架构) 贯穿设计与编码准则

> 本文件是 Fenlengtechbase 贯穿需求设计、架构规划、代码实现与交付审查全生命周期的通用整洁架构准则。

## 1. 核心分层与职责边界

无论采用何种语言或框架，系统架构必须严格划分为 4 个层次：

1. **Domain Layer (领域层 - 核心业务)**：
   - 包含业务实体 (Entities) 与核心业务规则。
   - **纯洁性铁律**：必须是纯粹的语言基础代码，绝对不依赖任何 UI 框架、数据库、网络库或第三方 SDK。
2. **Use Case / Application Layer (用例/应用层)**：
   - 包含特定的业务用例逻辑与状态调度 (Use Cases / Notifiers / Services)。
   - 负责编排领域模型完成业务动作，只依赖 Domain 层。
3. **Presentation Layer (表现层 / UI)**：
   - 负责用户交互与界面渲染 (Widgets / Components / Controllers)。
   - **绝对隔离铁律**：表现层只负责响应 UI 事件并触发 Use Case/Intent，**严禁在表现层直接发起 HTTP/RPC 请求或直接操作数据库/本地存储**。
4. **Data & Infrastructure Layer (数据与基础设施层)**：
   - 包含 Repository 接口的具体实现、HTTP API 客户端、数据库 DAO 及设备硬件 SDK。
   - 通过依赖倒置 (Dependency Inversion) 适配并满足 Domain/UseCase 层声明的接口。

---

## 2. 设计阶段准则 (Design / Planning Phase)

在调用 `implementation-planner` 输出技术方案或 Work Package Spec 时：

- **分层设计**：必须在 Spec 中按 Domain / Presentation / Data 显式划分改动的文件目录与类职责。
- **依赖方向检查**：检查模块依赖图，确保依赖箭头单向由外层指向内层。
- **拒绝模棱两可**：不能直接写“修改某页面完成数据加载”，必须明确为：“在 Data 层新增 Repo 提取，在 UseCase 层增加逻辑编排，在 UI 层做声明式绑定”。

---

## 3. 编码与交付阶段准则 (Coding & Review Phase)

在调用 `ai-coding` 实现代码及 `delivery-reviewer` 进行交付审查时：

- **精准外科手术实现**：在对应分层中实现最小代码，不破坏现有分层边界。
- **审查硬阻断拦截**：Reviewer 对比 Git Diff 时，若发现以下违规行为直接标记为审查失败（`FAILED`）：
  - ❌ 在 UI 视图/组件中直接引用或调用 HTTP 网络库 / 数据库 API；
  - ❌ 在 Domain 层导入了 UI 框架（如 Flutter `flutter/material.dart` 或 React DOM）；
  - ❌ 绕过 Repository 接口直接在业务逻辑中实例化具体的数据源类。
