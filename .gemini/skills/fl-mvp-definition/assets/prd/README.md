# PRD Templates

本目录保存 `fl-mvp-definition` Skill 使用的 MVP 文档和静态 preview 模板。

## 模板清单

- `MVP.md.template`：MVP 权威主文档模板。
- `discovery-log.md.template`：对话澄清和范围取舍记录模板。
- `feature-scope.md.template`：功能范围表模板。
- `user-flow.md.template`：用户流程和页面流转模板。
- `acceptance-criteria.md.template`：产品验收标准模板。
- `data-and-states.md.template`：页面数据、状态和假数据说明模板。
- `audience-and-expectation.md.template`：目标读者、可执行文档风格、面向用户 Preview 期待和完整性 Gate 模板。
- `surface-scope.md.template`：Flutter App、Web、Taro 小程序端型与平台支持范围模板。
- `version-history.md.template`：MVP 本体版本记录、完成状态、变更原因和完成 Gate 模板，生成到 `docs/mvp/version-history.md`。
- `figma-prompts-README.md.template`：Figma Prompt 版本归档索引模板，生成到 `docs/mvp/figma-prompts/README.md`。
- `figma-prompt.md.template`：交付给 Figma 或设计工具的单端版本化视觉生成 Prompt 模板，生成到 `docs/mvp/figma-prompts/FigmaPrompt-{Surface}-V{N}.md`。
- `fl-mvp-definition-summary.md.template`：工作流职责、边界、产物清单和后续建议模板。
- `preview-README.md.template`：静态 preview 说明模板。
- `preview-index.html.template`：静态 preview HTML 入口模板。
- `preview-styles.css.template`：静态 preview 样式模板。
- `preview-app.js.template`：静态 preview 本地交互模板。
- `preview-mock-data.js.template`：静态 preview 假数据模板。

## 使用约束

- `MVP.md` 是唯一权威主文档。
- 其他文档只能细化、索引或记录 `MVP.md` 中已经确认的产品定义。
- PRD 默认面向研发团队和客户/业务方，文档风格为可执行版。
- Preview 默认面向最终用户体验，必须呈现用户能理解的产品价值、主路径、核心 CTA 和关键反馈。
- MVP 本体必须维护 `docs/mvp/version-history.md`，记录当前版本、完成状态、变更摘要和完成 Gate；用户未确认结束时不得标记为 completed。
- Figma Prompt 默认面向设计工具，必须按端拆分并版本化归档到 `docs/mvp/figma-prompts/`，例如 `FigmaPrompt-App-V1.md`、`FigmaPrompt-Web-V1.md`、`FigmaPrompt-MiniProgram-V1.md`；更新时只新增受影响端的新版本。
- preview 必须拆文件生成，不得使用单文件实现。
- preview 必须使用本地假数据，不得发起网络请求。
