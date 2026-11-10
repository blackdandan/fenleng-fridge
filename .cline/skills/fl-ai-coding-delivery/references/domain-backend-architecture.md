# Kotlin / Java 后端服务工程架构选型与规范

> 本文件是 Fenlengtechbase 体系中后端服务 (Backend Services) 的核心工程选型与架构规范。

## 1. 工程拓扑选型 (Gradle Multi-Project & Microservices)

后端服务统一选定 **Kotlin** 为核心语言，采用 **Gradle Multi-Project / 模块化单体 (Modular Monolith) 或微服务** 拓扑：

- `settings.gradle.kts` (根工程模块编排)
- `:common-lib`：基础工具、通用 Token 解析、全局异常处理
- `:gateway-service`：API 网关路由与统一鉴权
- `:service-*`：独立业务领域服务 (如 `:user-service`, `:business-service`)

---

## 2. 服务内部 DDD 4 层结构

每个微服务或业务模块内部，必须严格遵守 **DDD (领域驱动设计) + Clean Architecture 4 层规范**：

1. **`interfaces` (接口层)**：REST Controllers、gRPC Handlers、DTO 请求与响应映射。
2. **`application` (应用用例层)**：UseCase 事务编排、应用服务、事件发布。
3. **`domain` (纯粹领域层 - 核心)**：
   - 包含领域实体 (Entities)、值对象 (Value Objects) 及 Repository 接口。
   - **纯洁性铁律**：绝对不依赖任何 Spring、JPA/MyBatis、Redis 或网络库，纯 Kotlin 逻辑。
4. **`infrastructure` (基础设施层)**：
   - 包含数据库 DAO、JPA/MyBatis Mapper 盲适配、Redis 缓存实现及第三方 RPC 客户端。

---

## 3. 模块隔离与数据库读写铁律

- 每一个业务微服务/模块拥有独立的数据库表空间。
- 严禁服务之间直接跨库读写对方的数据库表，服务间交互统一通过网关或 Feign / gRPC / 消息队列通信。
