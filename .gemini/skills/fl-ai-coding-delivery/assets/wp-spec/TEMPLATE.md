# WorkPackage Spec: [WP-ID] [工作包名称]

- **全局 Epic 计划**: [epic_plan.md](../epic_plan.md)
- **整洁架构归属**: [例如: Core Business Logic / Interface Adapters / Frameworks]
- **分类**: `work-package`
- **用户审批**: `Adjustment`（用户明确回复 `spec approved` 前不得修改代码、测试、业务文档、配置或依赖）
- **Spec 存放位置**: `docs/spec/[WP-ID].md`

---

## 📖 必需的上下文文件列表 (Context Files to Read)
<!-- 列出当前宿主执行本 Spec 前必须读取的最小上下文，避免无目的扩大读取范围 -->
- **依赖接口/基底类** (必须读取):
  - [例如: `domain/model/User.kt`]
- **类似实现参考** (可帮助理解设计风格):
  - [例如: `adapters/web/ExistingController.kt`]

---

## 🎯 核心修改范围 (Target Files & Directories)
* **允许修改的文件/目录**:
  - [ ] [例如: `/adapters/web/RechargeController.kt`]
* **严禁触碰的文件/目录**:
  - [ ] [例如: `/domain/model/User.kt` (必须保持只读，只允许依赖，不允许修改)]

---

## 🛠️ 实现规格与伪代码 (Technical Blueprint)
<!-- 提供具体的类签名、核心方法、API 字段及整洁架构设计指导 -->

### 接口/类定义草案
```kotlin
// 伪代码或框架定义
class RechargeController(private val rechargeUseCase: RechargeWallet) {
    fun recharge(request: RechargeRequest): Response {
        // 调用业务用例
    }
}
```

### 接口契约
* **Method**: `POST`
* **Path**: `/api/v1/recharge`

---

## 🧭 项目知识影响 (Knowledge Impact)

- **是否影响 API、Schema、契约、依赖、生命周期或知识入口**: [是/否及原因]
- **需要同步的 Manifest 或知识资产**: [文件列表；无则说明]
- **审计命令**: `fl kno audit --project <path> --base <ref>`

---

## 🧪 验证与验收规格 (Verification Specs)
<!-- 本阶段采用“人类手动执行 -> 错误局部贴回”模式，防止编译日志撑爆 AI 上下文 -->

1. **编译与单测**:
   * 请在本地终端手动运行：`[输入您的测试命令，例如: ./gradlew test]`
2. **异常处理机制**:
   * 若测试失败，**请勿**将整段编译日志全部丢给编码 Agent。**请仅复制并贴出关键的 Error Stacktrace 或失败原因信息**给编码 Agent 进行针对性修复。

---

## ✅ 交付审查（完成后回写）

- **用户批准的范围与实际修改路径**: [列出并说明是否一致]
- **实际验证命令与结果**: [命令、退出码、not-run 原因]
- **知识审计与同步结果**: [命令与结果]
- **代码验证状态**: `validated | failed | not-run`
- **外部就绪状态**: `ready | pending | not-applicable`
- **交付状态**: `validated | validated-with-follow-up | blocked`
- **外部前置条件、风险和下一步**: [无则明确“无”]
