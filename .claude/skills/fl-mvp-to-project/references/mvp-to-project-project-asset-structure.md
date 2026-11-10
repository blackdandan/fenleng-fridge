# MVP To Project Asset Structure Rule

## 适用场景

当任务需要从已确认 MVP 创建项目资产目录，或将历史项目迁移到标准项目资产结构时，必须遵守本规则。

## 固定顶层结构

标准项目资产目录固定为：

```text
00-context/
01-product/
02-engineering/
03-deployment/
04-operations/
05-knowledge/
06-project/
```

不得默认增加 `design/` 或 `test/` 顶层目录。

设计源默认在 Figma 或外部设计系统中维护，项目中只记录链接或交接说明。

测试目录属于 coding 工程内部，验收标准属于 `01-product/`。

## 目录保留规则

默认使用 `README.md` 作为目录指导文件和 Git 保留文件，不使用 `.gitkeep`。

指导性文件必须简洁，并至少说明：

- 用途
- 放什么
- 不放什么
- 关键文件
- 与其他目录的关系

## 06-project 规则

`06-project/` 只存放真实代码工程、工程脚本和工程内 README。

本 Skill 可以根据技术栈创建工程容器级目录，例如：

```text
06-project/server/
06-project/web/
06-project/android/
```

不得在本 Skill 中创建 `src/`、`components/`、`modules/`、`controllers/` 等 coding 阶段内部目录。

真实代码目录由后续用户与 AI 的 coding 交流依据 `02-engineering/coding-guide.md` 决定。

## 02-engineering 默认文件

`02-engineering/` 默认生成：

```text
README.md
engineering-guide.md
architecture.md
coding-guide.md
```

可按项目需要补充：

```text
data-model.md
api-design.md
integration.md
```

## 迁移规则

`migrate-existing-project` 可以实际迁移文件，但只能在用户确认迁移报告之后执行。

迁移只处理顶层目录、文档类目录和项目资产类文件，不改动 coding 工程内部结构。

每个顶层路径必须得到一个明确动作：

```text
move
merge
keep
ignore
manual-review
```

强映射不得遗漏顶层路径。存在冲突、归属不明或可能覆盖内容时，必须标记为 `manual-review`。

## 交接规则

本 Skill 不生成 `AI-CODING-ENTRY.md`，也不强绑定 `fl-ai-coding-delivery`。

为避免后续编码阶段因缺失基础设施或契约信息而返工，本阶段生成 `00-context/project.yaml` 时应同步引导确认 `day0Infrastructure`（生产三域名、OSS Bucket/RAM Role、三端包名、根 `fenleng.project.yaml` 及同机跨仓联动策略）。完成后，用户自行选择后续是否进入 coding、部署、运营整理或其他流程。
