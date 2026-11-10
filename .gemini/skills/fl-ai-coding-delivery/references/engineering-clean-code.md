# Clean Code & Token Control Rules (代码质量与 Token 控制规则)

本规则用于约束 Agent 在实现编码时的代码素质，在确保代码整洁的同时，极限压低 Token 消耗。

---

## 1. 编码操作约束

1. **禁止无脑覆写 (No Redundant Rewrite)**：
   * 除非重构整个类，严禁为了修改几行代码而全量重写输出整个文件（特别是大于 100 行的文件）。
   * 必须精准调用局部 Replace 或 Line-patch 工具进行修改。
2. **禁止越权修改 (No Scope Creep)**：
   * 必须坚守 Spec 划定的物理修改范围，严禁修改与本 WP 无关的周围代码。

---

## 2. 注释规范与正反例 (Comments Standards)

为了防止废话注释撑爆上下文，严格执行以下注释红线：

* **❌ 严禁编写的“What/How”型注释**（复述代码语义）：
  ```kotlin
  // 创建 user 实例并设置活跃状态
  val user = User()
  user.setActive(true)
  ```
* **✔️ 必须遵守的“Why”型注释**（仅解释核心复杂逻辑或设计决策背后的原因）：
  ```kotlin
  // 必须在本地先校验安全风控限额，以防止并发请求绕过后续的分布式锁
  if (riskControl.isOverLimit(user, amount)) {
      throw OverLimitException()
  }
  ```

---

## 3. 代码整洁原则 (Clean Code Guidelines)

1. **单一职责**：每个新增/修改的类和方法应只负责单一任务。方法行数原则上不超过 30 行。
2. **禁止残留死代码**：严禁提交未使用的 import 声明、废弃的局部变量以及 Debug 用的临时打印语句。
3. **文件长度硬性限制**：单个源文件长度**不得超过 300 行**。如果预估或实际编写的代码行数超过 300 行，必须从架构设计上对文件进行合理的子模块拆分或重构。
